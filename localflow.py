#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["mlx-whisper", "sounddevice", "numpy", "pynput"]
# ///
"""Local push-to-talk dictation. Hold Right Control, speak, release: text is pasted at the cursor."""
import os, queue, subprocess, sys, threading, time

import mlx_whisper
import numpy as np
import sounddevice as sd
from pynput import keyboard

MODEL = os.environ.get("LOCALFLOW_MODEL", "mlx-community/whisper-large-v3-turbo")
HOTKEY = getattr(keyboard.Key, os.environ.get("LOCALFLOW_KEY", "ctrl_r"))
LANG = os.environ.get("LOCALFLOW_LANG")  # None = auto-detect
RATE = 16000
MIN_SECONDS = 0.3

kb = keyboard.Controller()
chunks, recording, jobs = [], threading.Event(), queue.Queue()


def sound(name):
    subprocess.Popen(["afplay", f"/System/Library/Sounds/{name}.aiff"])


def on_audio(data, frames, t, status):
    if recording.is_set():
        chunks.append(data.copy())


def paste(text):
    old = subprocess.run(["pbpaste"], capture_output=True).stdout
    subprocess.run(["pbcopy"], input=text.encode())
    with kb.pressed(keyboard.Key.cmd):
        kb.tap("v")
    time.sleep(0.3)  # let the target app read the clipboard before restoring it
    subprocess.run(["pbcopy"], input=old)


def transcribe(audio):
    out = mlx_whisper.transcribe(audio, path_or_hf_repo=MODEL, language=LANG,
                                 condition_on_previous_text=False)
    return out["text"].strip()


def worker():
    while True:
        audio = jobs.get()
        t0 = time.time()
        text = transcribe(audio)
        print(f"[{time.time() - t0:.1f}s] {text!r}", flush=True)
        if text:
            paste(text + " ")


def on_press(key):
    if key == HOTKEY and not recording.is_set():
        chunks.clear()
        recording.set()
        sound("Tink")


def on_release(key):
    if key == HOTKEY and recording.is_set():
        recording.clear()
        sound("Tink")
        if chunks:
            audio = np.concatenate(chunks).flatten()
            if len(audio) >= RATE * MIN_SECONDS:
                jobs.put(audio)


def main():
    print(f"loading {MODEL} ...", flush=True)
    transcribe(np.zeros(RATE, dtype=np.float32))  # download + warm up
    threading.Thread(target=worker, daemon=True).start()
    with sd.InputStream(samplerate=RATE, channels=1, dtype="float32", callback=on_audio):
        print(f"ready. hold {HOTKEY.name} to dictate, ctrl+c to quit.", flush=True)
        with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
            listener.join()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
