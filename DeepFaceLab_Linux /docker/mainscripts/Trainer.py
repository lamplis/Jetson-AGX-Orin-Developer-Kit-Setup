#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Trainer.py – DeepFaceLab
Version 
- Jetson / preview asynchrone
- « async preview » + correctifs Linux X11
"""

import os
import sys
import time
import queue
import threading
import traceback
import itertools
import ctypes
import ctypes.util
from pathlib import Path

import cv2
import numpy as np

from core import imagelib, pathex
from core.interact import interact as io
import models

# -----------------------------------------------------------------------------
# Helpers to give pthreads a human‑readable name (handy in `top -H`, `ps -T` …)
# -----------------------------------------------------------------------------
libc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("c"))
PR_SET_NAME = 15

def _rename_current_thread(new_name: bytes):
    """Linux‑only: change the name visible in ps/top for the current thread."""
    try:
        libc.prctl(PR_SET_NAME, ctypes.c_char_p(new_name), 0, 0, 0)
    except Exception:
        pass  # Non‑Linux / older libc – silently ignore

# Give a name to the main interpreter thread
threading.current_thread().name = "DFL-Main"
_rename_current_thread(b"DFL-Main")

# -----------------------------------------------------------------------------
# Trainer thread – performs the heavy training loop
# -----------------------------------------------------------------------------

def trainer_thread(
    s2c: queue.Queue,
    c2s: queue.Queue,
    ready_evt: threading.Event,
    *,
    model_class_name=None,
    saved_models_path: Path | None = None,
    training_data_src_path: Path | None = None,
    training_data_dst_path: Path | None = None,
    pretraining_data_path: Path | None = None,
    pretrained_model_path: Path | None = None,
    no_preview=False,
    force_model_name=None,
    force_gpu_idxs=None,
    cpu_only=None,
    silent_start=False,
    execute_programs=None,
    debug=False,
    **kwargs,
):
    """Background thread running the train loop and sending previews to the GUI."""

    # Lower the niceness so that GUI keeps priority
    try:
        os.nice(15)
    except PermissionError:
        pass

    # ----- initialise paths -----
    start_time = time.time()
    save_interval_min = 25

    for p in (training_data_src_path, training_data_dst_path, saved_models_path):
        if p is not None and not p.exists():
            p.mkdir(parents=True, exist_ok=True)

    # ----- load / create model -----
    model = models.import_model(model_class_name)(
        is_training=True,
        saved_models_path=saved_models_path,
        training_data_src_path=training_data_src_path,
        training_data_dst_path=training_data_dst_path,
        pretraining_data_path=pretraining_data_path,
        pretrained_model_path=pretrained_model_path,
        no_preview=no_preview,
        force_model_name=force_model_name,
        force_gpu_idxs=force_gpu_idxs,
        cpu_only=cpu_only,
        silent_start=silent_start,
        debug=debug,
    )

    reached_goal = model.is_reached_iter_goal()
    shared = {"after_save": False}
    last_save_time = time.time()
    save_iter = model.get_iter()

    # ---------------- internal helpers ----------------
    def _model_save():
        # Never save if we have not completed at least 1 iteration
        if model.get_iter() < 1:
            return
        if not debug and not reached_goal:
            io.log_info("Saving …", end="\r")
            model.save()
            shared["after_save"] = True

    def _model_backup():
        if model.get_iter() < 1:
            return
        if not debug and not reached_goal:
            model.create_backup()

    def _send_preview():
        if no_preview:
            return
        if debug:
            previews = [("debug – press update", model.debug_one_iter())]
            payload = {"op": "show", "previews": previews}
        else:
            previews = model.get_previews()
            payload = {
                "op": "show",
                "previews": previews,
                "iter": model.get_iter(),
                "loss_history": model.get_loss_history().copy(),
            }
        c2s.put(payload)
        ready_evt.set()

    # ---------------- initial log ----------------
    if model.get_target_iter():
        if reached_goal:
            io.log_info("Model already trained to target iteration – preview available.")
        else:
            io.log_info(
                f"Starting. Target iteration: {model.get_target_iter()}. "
                "Press [Enter] to stop & save."
            )
    else:
        io.log_info("Starting. Press [Enter] to stop & save.")

    execute_programs = execute_programs or []
    execute_programs = [[x[0], x[1], time.time()] for x in execute_programs]

    # ---------------- main training loop ----------------
    iteration_counter = itertools.count()
    try:
        for _ in iteration_counter:
            current_time = time.time()

            # --- optional user programs ---
            for entry in execute_programs:
                delay, code_snippet, last_run = entry
                should_run = False
                if delay > 0 and (current_time - start_time) >= delay:
                    entry[0] = 0  # run once
                    should_run = True
                elif delay < 0 and (current_time - last_run) >= -delay:
                    entry[2] = current_time
                    should_run = True
                if should_run:
                    try:
                        exec(code_snippet, globals(), locals())
                    except Exception as err:
                        io.log_warn(f"Unable to exec user code: {err}")

            # --- training step (skip when goal reached) ---
            if not reached_goal:
                if model.get_iter() == 0:
                    io.log_info("\nFirst iteration – if it fails, reduce model dimensions.\n")
                it, it_time = model.train_one_iter()

                # build line like [#000123][0123ms][losses …]
                tstr = time.strftime("[%H:%M:%S]")
                hdr = f"{tstr}[#{it:06d}][{it_time*1000:04.0f}ms]" if it_time < 10 else f"{tstr}[#{it:06d}][{it_time:0.4f}s]"
                losses = model.get_loss_history()[-1]
                line = hdr + "".join(f"[{v:.4f}]" for v in losses)
                io.log_info(line, end="\r", flush=True)

                if shared["after_save"]:
                    shared["after_save"] = False
                    avg_loss = np.mean(model.get_loss_history()[save_iter:it], axis=0)
                    io.log_info(hdr + "".join(f"[{v:.4f}]" for v in avg_loss))
                    save_iter = it

                # auto‑save first iter
                if it == 1:
                    _model_save()

                if model.get_target_iter() and model.is_reached_iter_goal():
                    io.log_info("Reached target iteration.")
                    _model_save()
                    reached_goal = True
                    io.log_info("You can now use preview only mode.")

            # --- periodic save ---
            while current_time - last_save_time >= save_interval_min * 60:
                last_save_time += save_interval_min * 60
                if not reached_goal:
                    _model_save()
                    _send_preview()

            # --- first preview after load ---
            if _ == 0:
                if reached_goal:
                    model.pass_one_iter()
                _send_preview()

            # --- small sleep in debug ---
            if debug:
                time.sleep(0.005)

            # --- handle commands from GUI ---
            while not s2c.empty():
                msg = s2c.get()
                op = msg.get("op")
                if op == "save":
                    _model_save()
                elif op == "backup":
                    _model_backup()
                elif op == "preview":
                    if reached_goal:
                        model.pass_one_iter()
                    _send_preview()
                elif op == "close":
                    _model_save()
                    raise KeyboardInterrupt  # leave main loop

    except KeyboardInterrupt:
        pass
    finally:
        try:
            model.finalize()
        finally:
            c2s.put({"op": "close"})

# -----------------------------------------------------------------------------
# Entry point ‑‑ manages the small GUI loop in the main thread
# -----------------------------------------------------------------------------

def main(**kwargs):
    io.log_info("Running trainer with async preview…\n")

    # Convert str → Path for path‑like kwargs
    for k in list(kwargs.keys()):
        if k.endswith("_path") and isinstance(kwargs[k], str):
            kwargs[k] = Path(kwargs[k]) if kwargs[k] else None

    no_preview = kwargs.get("no_preview", False)

    s2c = queue.Queue()  # GUI → trainer
    c2s = queue.Queue()  # trainer → GUI
    ready_evt = threading.Event()

    t = threading.Thread(
        target=trainer_thread,
        name="DFL-Train",
        kwargs=dict(kwargs, s2c=s2c, c2s=c2s, ready_evt=ready_evt),
        daemon=True,
    )
    t.start()

    # Wait until first preview or until trainer finalises
    ready_evt.wait()

    # --------- if preview completely disabled ---------
    if kwargs.get("no_preview"):
        try:
            while t.is_alive():
                time.sleep(0.1)
        except KeyboardInterrupt:
            s2c.put({"op": "close"})
        return

    # --------- create HighGUI window ---------
    wnd_name = "Training preview"
    try:
        io.named_window(wnd_name)
        cv2.startWindowThread()  # non‑blocking GUI loop (required for GTK)
    except cv2.error as exc:
        io.log_warn(f"Cannot create preview window ({exc}). Continuing headless…")
        kwargs["no_preview"] = True
        return main(**kwargs)  # restart in headless mode

    # Capture keys in the window only
    io.capture_keys(wnd_name)

    # Name current GUI thread for diagnostics
    threading.current_thread().name = "DFL-GUI"
    _rename_current_thread(b"DFL-GUI")

    previews = []
    loss_history = None
    selected = 0
    update = False
    waiting_preview = False
    show_last_history = 500
    current_iter = 0

    try:
        while True:
            # ---- receive data from trainer ----
            while not c2s.empty():
                msg = c2s.get()
                if msg["op"] == "show":
                    waiting_preview = False
                    previews = msg.get("previews", previews)
                    loss_history = msg.get("loss_history", loss_history)
                    current_iter = msg.get("iter", current_iter)
                    selected %= len(previews) if previews else 1
                    update = True
                elif msg["op"] == "close":
                    raise KeyboardInterrupt

            # ---- refresh preview image ----
            if update and previews:
                update = False
                name, rgb = previews[selected]
                h, w, c = rgb.shape

                # normalise size
                if h > 800:
                    scale = 800 / h
                    w = int(w * scale)
                    h = 800
                    rgb = cv2.resize(rgb, (w, h))

                # header lines
                header_txt = [
                    "[s] save  [b] backup  [Enter] quit",
                    "[p] update  [Space] next  [l] history range",
                    f'Preview "{name}" ({selected+1}/{len(previews)})',
                ]
                header_img = np.ones((len(header_txt)*15, w, c), dtype=np.float32) * 0.1
                for i, line in enumerate(header_txt):
                    header_img[i*15:(i+1)*15] += imagelib.get_text_image((15, w, c), line, color=[0.8]*c)

                # loss history plot
                footer = []
                if loss_history is not None and len(loss_history):
                    hist = loss_history[-show_last_history:] if show_last_history else loss_history
                    footer_img = models.ModelBase.get_loss_history_preview(hist, current_iter, w, c)
                    footer.append(footer_img)

                final = np.vstack([header_img] + footer + [rgb])
                io.show_image(wnd_name, (final*255).astype(np.uint8))

            # ---- handle key events ----
            key_events = io.get_key_events(wnd_name)
            if key_events:
                key, *_ = key_events[-1]
                if key in (ord("\n"), ord("\r")):
                    s2c.put({"op": "close"})
                elif key == ord("s"):
                    s2c.put({"op": "save"})
                elif key == ord("b"):
                    s2c.put({"op": "backup"})
                elif key == ord("p"):
                    if not waiting_preview:
                        waiting_preview = True
                        s2c.put({"op": "preview"})
                elif key == ord("l"):
                    show_last_history = {500:5000, 5000:10000, 10000:50000, 50000:0, 0:500}[show_last_history]
                    update = True
                elif key == ord(" ") and previews:
                    selected = (selected + 1) % len(previews)
                    update = True

            io.process_messages(0.03)
    except KeyboardInterrupt:
        pass
    finally:
        s2c.put({"op": "close"})
        io.destroy_all_windows()
