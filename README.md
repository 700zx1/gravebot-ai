# GraveBot AI Bridge with Bot Chat TTS Interception

This build adds interception of in-game bot chatter, forwarding bot chat to the TTS engine.

## Files

- `gravebot_ai_config.json` — Configuration for host, port, tick rate, constraints, subgroups
- `gravebot_ai.sma`             — AMX Mod X plugin with SayText2 hook for bot chat TTS
- `gravebot_ai.py`              — Python AI backend (with TTS on chat)
- `Makefile`                    — Compile the AMXX plugin

## Installation

1. Compile the AMXX plugin:
   ```bash
   cd /path/to/gravebot_ai_botchat_tts_build
   make AMXMODX_INCLUDE=/path/to/amxmodx/scripting
   mv gravebot_ai.amxx addons/amxmodx/plugins/
   ```
2. Place `gravebot_ai_config.json` alongside the plugin.
3. Run the Python backend:
   ```bash
   pip install openai numpy simpleaudio TTS
   python3 gravebot_ai.py
   ```
4. Load Metamod-P 1.21p37 and AMX Mod X 1.9.0‑git on your server.

Now bot chatter in-game will also be spoken via TTS by your AI backend.
