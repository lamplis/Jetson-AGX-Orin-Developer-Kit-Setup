#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Trainer.py – DeepFaceLab
Version 
- Jetson / preview asynchrone
- « async preview » + correctifs Linux X11
"""

import os, sys, time, queue, threading, traceback, itertools
from pathlib import Path

import numpy            as np
import cv2

from core   import imagelib, pathex
from core.interact import interact as io
import models

# --------------------------------------------------------------------------- #
#  -----------  outils pour nommer les threads côté Linux (prctl)  ---------  #
# --------------------------------------------------------------------------- #
def _linux_thread_rename(byte_name: bytes):
    """
    Renomme le thread courant côté noyau (visible dans htop / top -H).
    Ignoré automatiquement sous Windows ou si la libc n’est pas dispo.
    """
    if os.name != "posix":
        return
    try:
        import ctypes, ctypes.util
        libc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("c"))
        PR_SET_NAME = 15
        libc.prctl(PR_SET_NAME, ctypes.c_char_p(byte_name), 0, 0, 0)
    except Exception:
        pass  # on ne bloque jamais l’appli pour ça


# --------------------------------------------------------------------------- #
#                        THREAD D’ENTRAÎNEMENT PRINCIPAL                      #
# --------------------------------------------------------------------------- #
def trainerThread(
        s2c, c2s, ready_evt,
        *,
        model_class_name,              # ← tous les kwargs passés par main()
        saved_models_path,
        training_data_src_path,
        training_data_dst_path,
        pretraining_data_path=None,
        pretrained_model_path=None,
        no_preview=False,
        force_model_name=None,
        force_gpu_idxs=None,
        cpu_only=None,
        silent_start=False,
        execute_programs=None,
        debug=False,
        **kwargs
):
    threading.current_thread().name = "DFL-Train"
    _linux_thread_rename(b"DFL-Train")
    os.nice(15)                       # priorité la plus basse

    # ------------------------------------------------------------------- #
    #                    INITIALISATION CHEMINS / MODÈLE                  #
    # ------------------------------------------------------------------- #
    start_time          = time.time()
    save_interval_min   = 25
    execute_programs    = execute_programs or []

    for p in (saved_models_path,
              training_data_src_path,
              training_data_dst_path):
        Path(p).mkdir(parents=True, exist_ok=True)

    model = models.import_model(model_class_name)(
            is_training              = True,
            saved_models_path        = saved_models_path,
            training_data_src_path   = training_data_src_path,
            training_data_dst_path   = training_data_dst_path,
            pretraining_data_path    = pretraining_data_path,
            pretrained_model_path    = pretrained_model_path,
            no_preview               = no_preview,
            force_model_name         = force_model_name,
            force_gpu_idxs           = force_gpu_idxs,
            cpu_only                 = cpu_only,
            silent_start             = silent_start,
            debug                    = debug)

    is_reached_goal = model.is_reached_iter_goal()

    # ------------------------------------------------------------------- #
    #                         FONCTIONS UTILITAIRES                       #
    # ------------------------------------------------------------------- #
    shared_state = {'after_save': False}
    save_iter    = model.get_iter()

    def model_save():
        """Sauvegarde seulement si on a déjà fait ≥ 1 itération."""
        if model.get_iter() >= 1 and not is_reached_goal:
            io.log_info("Saving…", end='\r')
            model.save()
            shared_state['after_save'] = True

    def model_backup():
        if model.get_iter() >= 1 and not is_reached_goal:
            model.create_backup()

    def send_preview():
        """Envoi (éventuel) du preview vers le thread GUI."""
        if no_preview:
            return
        try:
            previews      = model.get_previews()
            loss_history  = model.get_loss_history().copy()
            c2s.put({'op': 'show',
                     'previews': previews,
                     'iter': model.get_iter(),
                     'loss_history': loss_history})
        except Exception:
            pass
        finally:
            ready_evt.set()

    # ------------------------------------------------------------------- #
    #                        BOUCLE D’ENTRAÎNEMENT                        #
    # ------------------------------------------------------------------- #
    if model.get_target_iter():
        io.log_info(f'Starting. Target iteration: {model.get_target_iter()}. '
                    'Press "Enter" to stop training and save model.')
    else:
        io.log_info('Starting. Press "Enter" to stop training and save model.')

    last_save_time = time.time()

    # normalise execute_programs = [[+/-secs, "code", last_exec]]
    exec_list = [[cfg[0], cfg[1], start_time] for cfg in execute_programs]

    for loop_idx in itertools.count():
        # --------- exécution programmée ---------------------------------
        cur_time = time.time()
        for item in exec_list:
            delay, code, last_exec = item
            doit = False
            if delay > 0 and cur_time - start_time >= delay:
                item[0] = 0
                doit = True
            elif delay < 0 and cur_time - last_exec >= -delay:
                item[2] = cur_time
                doit = True
            if doit:
                try:
                    exec(code, globals(), locals())
                except Exception as err:
                    io.log_info(f"Error executing custom code: {err}")

        # --------- entraînement -----------------------------------------
        if not is_reached_goal:
            if model.get_iter() == 0:
                io.log_info("\nTrying first iteration…\n")

            iter_idx, iter_time = model.train_one_iter()
            loss_history        = model.get_loss_history()
            tstamp              = time.strftime("[%H:%M:%S]")
            time_str = (f"{iter_time:0.4f}s" if iter_time >= 10
                        else f"{int(iter_time*1000):04d}ms")
            log_line = f"{tstamp}[#{iter_idx:06d}][{time_str}]"

            if shared_state['after_save']:
                shared_state['after_save'] = False
                mean_loss = np.mean(loss_history[save_iter:iter_idx], axis=0)
            else:
                mean_loss = loss_history[-1]

            log_line += ''.join(f"[{v:.4f}]" for v in mean_loss)
            io.log_info(log_line, end='\r' if not shared_state['after_save'] else '\n')
            save_iter = iter_idx

            # première itération : on force une sauvegarde
            if iter_idx == 1:
                model_save()

            # objectif atteint ?
            if model.get_target_iter() and model.is_reached_iter_goal():
                io.log_info('Reached target iteration.')
                model_save()
                is_reached_goal = True
                io.log_info('You can use preview now.')

        # --------- sauvegarde périodique --------------------------------
        if (time.time() - last_save_time) >= save_interval_min * 60 and not is_reached_goal:
            last_save_time += save_interval_min * 60
            model_save()
            send_preview()

        # --------- premier preview --------------------------------------
        if loop_idx == 0:
            send_preview()

        # --------- messages depuis la GUI -------------------------------
        while not s2c.empty():
            msg = s2c.get()
            if msg['op'] == 'save':
                model_save()
            elif msg['op'] == 'backup':
                model_backup()
            elif msg['op'] == 'preview':
                if is_reached_goal:
                    model.pass_one_iter()
                send_preview()
            elif msg['op'] == 'close':
                model_save()
                loop_idx = -1
                break

        if loop_idx == -1:
            break

        if debug:
            time.sleep(0.005)

    model.finalize()
    c2s.put({'op': 'close'})


# --------------------------------------------------------------------------- #
#                                   MAIN                                      #
# --------------------------------------------------------------------------- #
def main(**kwargs):
    io.log_info("Running trainer.\r\n")

    # Path‑ify les arguments qui représentent des chemins
    for k in list(kwargs.keys()):
        if k.endswith('_path') or k.endswith('_dir'):
            if kwargs[k] is not None:
                kwargs[k] = Path(kwargs[k])

    no_preview = kwargs.get('no_preview', False)

    # ------------- queues de communication entre threads --------------------
    s2c_q = queue.Queue()
    c2s_q = queue.Queue()
    ready = threading.Event()

    t = threading.Thread(target=trainerThread,
                         args=(s2c_q, c2s_q, ready),
                         kwargs=kwargs,
                         daemon=True)
    t.start()
    ready.wait()           # l’entraîneur a signalé « prêt »

    # ------------------------------------------------------------------- #
    #                   BOUCLE GUI (dans le thread principal)              #
    # ------------------------------------------------------------------- #
    threading.current_thread().name = "DFL-GUI"
    _linux_thread_rename(b"DFL-GUI")

    if no_preview:
        # mode non interactif : on gère juste Ctrl‑C
        try:
            while t.is_alive():
                io.process_messages(0.1)
        except KeyboardInterrupt:
            s2c_q.put({'op': 'close'})
        return

    # ---------- création de la fenêtre (avec protection d’erreur) ----------
    wnd_name = "Training preview"
    try:
        io.log_info(f'>>> trying to create window: {wnd_name}')
        io.named_window(wnd_name)
        io.capture_keys(wnd_name)
        io.log_info('>>> window OK')
    except Exception as err:
        io.log_info(f'Window creation failed: {err}\n⇒ continuing without preview.')
        kwargs['no_preview'] = True
        return main(**kwargs)          # relance sans preview

    previews               = None
    loss_history           = None
    selected_preview       = 0
    update_preview         = False
    is_waiting_preview     = False
    show_last_history_iters_count = 500
    cur_iter               = 0

    while True:
        # --------- messages du thread entraînement ----------------------
        while not c2s_q.empty():
            msg = c2s_q.get()
            if msg['op'] == 'show':
                is_waiting_preview = False
                previews     = msg.get('previews')
                loss_history = msg.get('loss_history')
                cur_iter     = msg.get('iter', 0)
                selected_preview %= len(previews)
                update_preview = True
            elif msg['op'] == 'close':
                io.log_info("Trainer thread finished.")
                io.destroy_all_windows()
                return

        # --------- affichage -------------------------------------------
        if update_preview and previews:
            update_preview = False
            name, img = previews[selected_preview]
            h, w, c   = img.shape

            # entête
            header_txt = [
                '[s] save   [b] backup   [Enter] quit',
                '[p] new preview   [space] next   [l] range',
                f'Preview: "{name}"  ({selected_preview+1}/{len(previews)})   iter={cur_iter}'
            ]
            head_h   = 15 * len(header_txt)
            header   = np.full((head_h, w, c), 0.1, np.float32)
            for i, line in enumerate(header_txt):
                y0 = i*15
                header[y0:y0+15, :, :] += imagelib.get_text_image((15, w, c), line,
                                                                  color=[0.8]*c)

            # loss history
            if loss_history is not None:
                hist = (loss_history
                        if show_last_history_iters_count == 0
                        else loss_history[-show_last_history_iters_count:])
                lh_img = models.ModelBase.get_loss_history_preview(hist, cur_iter, w, c)
                vis = np.concatenate([header, lh_img, img], axis=0)
            else:
                vis = np.concatenate([header, img], axis=0)

            io.show_image(wnd_name, (vis*255).astype(np.uint8))

        # --------- gestion des touches ---------------------------------
        keys = io.get_key_events(wnd_name)
        if keys:
            key, *_ = keys[-1]
            if key in (ord('\n'), ord('\r')):
                s2c_q.put({'op': 'close'})
            elif key == ord('s'):
                s2c_q.put({'op': 'save'})
            elif key == ord('b'):
                s2c_q.put({'op': 'backup'})
            elif key == ord('p') and not is_waiting_preview:
                is_waiting_preview = True
                s2c_q.put({'op': 'preview'})
            elif key == ord('l'):
                ranges = [0, 500, 5000, 10000, 50000, 100000]
                idx    = ranges.index(show_last_history_iters_count)
                show_last_history_iters_count = ranges[(idx+1) % len(ranges)]
                update_preview = True
            elif key == ord(' '):
                selected_preview = (selected_preview + 1) % len(previews)
                update_preview = True

        try:
            io.process_messages(0.1)
        except KeyboardInterrupt:
            s2c_q.put({'op': 'close'})
