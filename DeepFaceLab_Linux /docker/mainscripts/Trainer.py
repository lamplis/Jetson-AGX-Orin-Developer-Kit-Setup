#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Trainer.py – DeepFaceLab
Version 
- Jetson / preview asynchrone
- « async preview » + correctifs Linux X11
"""

﻿import os, sys, traceback, queue, threading, time, itertools, ctypes, ctypes.util
from pathlib import Path

import numpy as np
import cv2

from core import imagelib, pathex
from core.interact import interact as io
import models

# ───────────────────────────────────────────────────────────────────────────────
# Helpers – give threads a recognizable name for `ps`, `top -H`, htop, etc.
# ───────────────────────────────────────────────────────────────────────────────
libc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("c"))  # prctl is in libc

def _rename_current_thread(new_name: bytes):
    """
    Change the name of the *kernel* thread (shown by top/htop).
    """
    PR_SET_NAME = 15  # prctl option to set thread name
    libc.prctl(PR_SET_NAME, ctypes.c_char_p(new_name), 0, 0, 0)

# Rename the main thread immediately
threading.current_thread().name = "DFL‑Main"
_rename_current_thread(b"DFL-Main")

# ───────────────────────────────────────────────────────────────────────────────
# Trainer thread
# ───────────────────────────────────────────────────────────────────────────────
def trainer_thread(
    s2c, c2s, ready_evt,
    *,
    model_class_name,
    saved_models_path,
    training_data_src_path,
    training_data_dst_path,
    pretraining_data_path=None,
    pretrained_model_path=None,
    no_preview=False,
    force_model_name=None,
    force_gpu_idxs=None,
    cpu_only=False,
    silent_start=False,
    execute_programs=None,
    debug=False,
    **kwargs,
):
    """
    Actual training loop, executed in a secondary thread so the main
    thread can drive the GTK / OpenCV preview window asynchronously.
    """
    # Lower this thread’s CPU priority so GUI stays responsive
    os.nice(15)

    # Give a kernel‑level name
    threading.current_thread().name = "DFL‑Train"
    _rename_current_thread(b"DFL-Train")

    # Default list in case caller passed None
    execute_programs = execute_programs or []

    try:
        start_time = time.time()
        save_interval_min = 25
        min_iters_before_save = 1  # avoid saving empty models

        # Ensure all required directories exist
        for p in (training_data_src_path,
                  training_data_dst_path,
                  saved_models_path):
            p.mkdir(parents=True, exist_ok=True)

        # ---------------------------------------------------------------------
        # Initialise model
        # ---------------------------------------------------------------------
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
        last_save_time = time.time()
        saved_after_iter = model.get_iter()

        # Prepare execute‑program list → [period, code, last_time]
        exec_programs = [[x[0], x[1], time.time()] for x in execute_programs]

        # ---------------------------------------------------------------------
        # Helper callbacks
        # ---------------------------------------------------------------------
        def save_model():
            if reached_goal or model.get_iter() < min_iters_before_save:
                return
            io.log_info("Saving …", end="\r")
            model.save()
            nonlocal saved_after_iter
            saved_after_iter = model.get_iter()

        def backup_model():
            if not reached_goal:
                model.create_backup()

        def send_preview():
            """
            Push current previews + loss history to the GUI thread.
            """
            if no_preview:
                return

            if debug:
                previews = [("debug (one iter)", model.debug_one_iter())]
                payload = {"op": "show", "previews": previews}
            else:
                payload = {
                    "op": "show",
                    "previews": model.get_previews(),
                    "iter": model.get_iter(),
                    "loss_history": model.get_loss_history().copy(),
                }
            c2s.put(payload)
            ready_evt.set()  # Unblock main thread on first preview

        # ---------------------------------------------------------------------
        # User message before we start
        # ---------------------------------------------------------------------
        if model.get_target_iter():
            msg = ("Model already trained to target; preview available."
                   if reached_goal else
                   f"Starting. Target iteration: {model.get_target_iter()}. "
                   "Press Enter to stop & save.")
        else:
            msg = "Starting. Press Enter to stop & save."

        io.log_info(msg)

        # ---------------------------------------------------------------------
        # Main train loop
        # ---------------------------------------------------------------------
        for loop_idx in itertools.count():
            # Execute any scheduled python snippets (rarely used feature)
            now = time.time()
            for entry in exec_programs:
                period, code_snippet, last_run = entry
                should_run = (
                    (period > 0 and now - start_time >= period) or
                    (period < 0 and now - last_run >= -period)
                )
                if should_run:
                    try:
                        exec(code_snippet)
                    except Exception as exc:
                        io.log_info(f"[exec] error: {exc}")
                    entry[2] = now  # update last_run (for periodic tasks)

            # -------------------------------------
            # Training step
            # -------------------------------------
            if not reached_goal:
                if model.get_iter() == 0:
                    io.log_info("\nFirst iteration …\n")

                iter_num, iter_time = model.train_one_iter()
                losses = model.get_loss_history()[-1]
                timestamp = time.strftime("[%H:%M:%S]")
                time_str = (f"{iter_time:0.4f}s"
                            if iter_time >= 10 else f"{int(iter_time*1000):04d}ms")
                line = f"{timestamp}[#{iter_num:06d}][{time_str}]"
                line += "".join(f"[{lv:0.4f}]" for lv in losses)
                io.log_info(line, end="\r")
                sys.stdout.flush()

                # Save automatically on first iter so early crash keeps weights
                if iter_num == 1:
                    save_model()

                if model.get_target_iter() and model.is_reached_iter_goal():
                    io.log_info("\nReached target iteration.")
                    save_model()
                    reached_goal = True
                    io.log_info("You can now use preview only.")

            # -------------------------------------
            # Periodic save and preview
            # -------------------------------------
            if time.time() - last_save_time >= save_interval_min * 60:
                last_save_time = time.time()
                save_model()
                send_preview()

            if loop_idx == 0:
                # Send initial preview (unblocks GUI thread)
                if reached_goal:
                    model.pass_one_iter()  # generate valid preview frames
                send_preview()

            # Poll commands from GUI/main thread
            while not s2c.empty():
                cmd = s2c.get()
                op = cmd.get("op")
                if op == "save":
                    save_model()
                elif op == "backup":
                    backup_model()
                elif op == "preview":
                    if reached_goal:
                        model.pass_one_iter()
                    send_preview()
                elif op == "close":
                    save_model()
                    break  # exit train loop

            else:
                continue  # no break → continue training loop
            break         # got "close" → break outer loop

        model.finalize()

    except Exception as exc:
        io.log_info(f"Trainer thread crashed: {exc}")
        traceback.print_exc()

    finally:
        c2s.put({"op": "close"})


# ───────────────────────────────────────────────────────────────────────────────
# Main entry point (spawns trainer + handles GUI)
# ───────────────────────────────────────────────────────────────────────────────
def main(**kwargs):
    io.log_info("Running trainer with async preview …\n")

    # Convert str paths → Path objects (caller may pass None)
    for k in [
        "saved_models_path",
        "training_data_src_path",
        "training_data_dst_path",
        "pretraining_data_path",
        "pretrained_model_path",
    ]:
        if kwargs.get(k):
            kwargs[k] = Path(kwargs[k])

    no_preview = kwargs.get("no_preview", False)

    # Queues for bi‑directional comms
    s2c = queue.Queue()  # signals → trainer
    c2s = queue.Queue()  # signals → GUI/main

    ready_evt = threading.Event()

    # Spawn training thread
    t = threading.Thread(
        target=trainer_thread,
        args=(s2c, c2s, ready_evt),
        kwargs=kwargs,
        name="DFL‑Train",
        daemon=True,
    )
    t.start()

    # Wait until first preview (or trainer exits)
    ready_evt.wait(timeout=60)

    # ---------- Headless mode ----------
    if no_preview:
        while True:
            if not c2s.empty() and c2s.get().get("op") == "close":
                break
            try:
                io.process_messages(0.1)
            except KeyboardInterrupt:
                s2c.put({"op": "close"})
        return

    # ---------- GUI mode ----------
    wnd_name = "Training preview"
    io.named_window(wnd_name)
    io.capture_keys(wnd_name)

    previews = None
    loss_history = None
    selected_idx = 0
    show_last_history = 500  # starting history window
    waiting_preview = False

    while True:
        # Handle messages from trainer
        while not c2s.empty():
            msg = c2s.get()
            op = msg.get("op")
            if op == "show":
                waiting_preview = False
                previews = msg.get("previews")
                loss_history = msg.get("loss_history")
                iter_num = msg.get("iter", 0)

                # Resize previews uniformly
                if previews:
                    h_max = max(p[1].shape[0] for p in previews)
                    w_max = max(p[1].shape[1] for p in previews)
                    if h_max > 800:
                        scale = 800 / h_max
                        h_max = 800
                        w_max = int(w_max * scale)
                    normalized = []
                    for name, img in previews:
                        if img.shape[:2] != (h_max, w_max):
                            img = cv2.resize(img, (w_max, h_max))
                        normalized.append((name, img))
                    previews = normalized
                selected_idx %= len(previews or [1])  # safeguard

            elif op == "close":
                io.destroy_all_windows()
                return

        # Draw preview pane if we have images
        if previews:
            name, img = previews[selected_idx]
            h, w, c = img.shape

            # header
            header_lines = [
                "[s] save   [b] backup   [Enter] exit",
                "[p] update   [Space] next preview   [l] toggle history zoom",
                f'Preview: "{name}"  ({selected_idx+1}/{len(previews)})',
            ]
            head_h = 15 * len(header_lines)
            header = np.ones((head_h, w, c), dtype=np.float32) * 0.1
            for i, line in enumerate(header_lines):
                y0, y1 = i * 15, (i + 1) * 15
                header[y0:y1] += imagelib.get_text_image(
                    (15, w, c), line, color=[0.8] * c
                )

            canvas = header
            if loss_history is not None:
                history_slice = (
                    loss_history if show_last_history == 0
                    else loss_history[-show_last_history:]
                )
                lh_img = models.ModelBase.get_loss_history_preview(
                    history_slice, iter_num, w, c
                )
                canvas = np.concatenate([canvas, lh_img], axis=0)

            canvas = np.concatenate([canvas, img], axis=0)
            io.show_image(wnd_name, (canvas.clip(0, 1) * 255).astype("uint8"))

        # Poll keyboard
        key_events = io.get_key_events(wnd_name)
        if key_events:
            key, *_ = key_events[-1]
            if key in (ord("\n"), ord("\r")):        # Enter
                s2c.put({"op": "close"})
            elif key == ord("s"):                    # save
                s2c.put({"op": "save"})
            elif key == ord("b"):                    # backup
                s2c.put({"op": "backup"})
            elif key == ord("p") and not waiting_preview:
                waiting_preview = True
                s2c.put({"op": "preview"})
            elif key == ord("l"):                    # cycle history window
                show_last_history = {
                    500: 5000,
                    5000: 10000,
                    10000: 50000,
                    50000: 100000,
                    100000: 0,
                    0: 500,
                }[show_last_history]
            elif key == ord(" "):                    # space → next preview
                selected_idx = (selected_idx + 1) % len(previews)
        try:
            io.process_messages(0.05)
        except KeyboardInterrupt:
            s2c.put({"op": "close"})
