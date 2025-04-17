#!/usr/bin/env python3
"""
gravebot_ai.py — AI backend loading constraints/subgroups from config file.
"""

import os
import socket
import threading
import logging
import json
import time
import random

import numpy as np
import simpleaudio as sa
import openai
from TTS.api import TTS

# Load configuration
with open("gravebot_ai_config.json") as f:
    cfg = json.load(f)

HOST   = cfg.get("host", "127.0.0.1")
PORT   = cfg.get("port", 5000)
TICK   = cfg.get("tick_rate", 0.1)
IDLE_INTERVAL = cfg.get("idle_interval", 30)

ROLE_CONSTRAINTS = cfg.get("role_constraints", {})
SUBROLE_CONSTRAINTS = cfg.get("subrole_constraints", {})
SUBGROUP_SPECS = cfg.get("subgroups", {})

# Build subgroup functions
def build_subgroups(state):
    subs = {}
    for name, spec in SUBGROUP_SPECS.items():
        if spec["type"] == "subrole_prefix":
            subs[name] = [b["id"] for b in state["bots"] if b["subrole"].startswith(spec["value"])]
        elif spec["type"] == "role_equals":
            subs[name] = [b["id"] for b in state["bots"] if b["role"] == spec["value"]]
    return subs

# LLM & TTS setup
openai.api_key = os.getenv("OPENAI_API_KEY")
MODEL = "gpt-4o-mini"
TEMPERATURE = 0.7
tts_model = TTS(model_name="tts_models/en/vctk/vits", progress_bar=False, gpu=False)

last_command_time = time.time()
last_command_lock = threading.Lock()

def tts_play(text: str):
    waveform = tts_model.tts(text=text)
    sr = tts_model.synthesizer.output_sample_rate
    pcm = (waveform * 32767).astype(np.int16)
    sa.play_buffer(pcm.tobytes(), 1, 2, sr)

def decide_command(state, commands):
    sys_msg = (
        f"Constraints: roles={ROLE_CONSTRAINTS}, subroles={SUBROLE_CONSTRAINTS}. "
        f"Subgroups: {list(SUBGROUP_SPECS.keys())}."
    )
    bot_lines = [f"Bot#{b['id']}(role={b['role']},sub={b['subrole']},hp={b['health']})" for b in state["bots"]]
    user_msg = " | ".join(bot_lines) + f" | Time left: {state.get('time_left',0)}"
    resp = openai.ChatCompletion.create(
        model=MODEL,
        messages=[{"role":"system","content":sys_msg},{"role":"user","content":user_msg}],
        temperature=TEMPERATURE,
        max_tokens=16
    )
    cmd = resp.choices[0].message.content.strip()
    return cmd if cmd in commands else "help"

def handle_client(conn, addr):
    global last_command_time
    data = conn.recv(4096).decode(errors="ignore")
    if not data.startswith("COMMAND_LIST;"):
        conn.close(); return
    cmds = data.strip().split(";")[1:]
    try:
        while True:
            raw = conn.recv(8192)
            if not raw: break
            state = json.loads(raw.decode(errors="ignore"))
            cmd = decide_command(state, cmds)
            conn.sendall(cmd.encode())
            tts_play(f"Executing {cmd}")
            with last_command_lock:
                last_command_time = time.time()
            time.sleep(0.05)
    finally:
        conn.close()

def idle_loop():
    while True:
        time.sleep(IDLE_INTERVAL)
        with last_command_lock:
            if time.time() - last_command_time >= IDLE_INTERVAL:
                resp = openai.ChatCompletion.create(
                    model=MODEL,
                    messages=[{"role":"system","content":"Generate a brief idle line."}],
                    temperature=TEMPERATURE,
                    max_tokens=8
                )
                phrase = resp.choices[0].message.content.strip()
                tts_play(phrase)
                with last_command_lock:
                    last_command_time = time.time()

def main():
    logging.basicConfig(level=logging.INFO)
    threading.Thread(target=idle_loop, daemon=True).start()
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.bind((HOST, PORT)); srv.listen(1)
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()

if __name__ == "__main__":
    main()
