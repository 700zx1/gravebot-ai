# Usage Guide for GraveBot AI Bridge

This document describes how the AI integration improves GraveBot play in Science & Industry and how to steer its behavior by editing the local configuration file (`gravebot_ai_config.json`).

## 1. How AI Improves GraveBot

1. **Complete Battlefield Awareness**  
   Each tick, the plugin sends a JSON snapshot containing:
   - Map name and time remaining
   - For each bot: `role` (DEFEND/ATTACK), `subrole` (e.g. `ROLE_SUB_ATT_GET_SCI`), health, armor, and position  
   The AI sees the full game state in real time, enabling smarter decisions than static waypoint scripts.

2. **Enforced Tactical Constraints**  
   In `gravebot_ai_config.json`, define minimum counts:
   ```json
   "role_constraints": { "ROLE_DEFEND": 2, "ROLE_ATTACK": 3 },
   "subrole_constraints": { "ROLE_SUB_ATT_GET_RSRC": 2, "ROLE_SUB_ATT_GET_SCI": 1 }
   ```
   The AI will never violate these core strategy objectives.

3. **Dynamic Role‑Aware Orders**  
   With each bot’s `role` and `subrole`, the AI can:
   - Reroute low‑health attackers to defense using `pause`/`resume` commands
   - Switch a fetcher to a return task after pickup
   - Issue precise `path` or `goal` commands for map control

4. **Map‑Specific Strategy**  
   Because the AI prompt includes map name and time left, you can seed it with per‑map objectives (e.g. “On Reactor, rush SCI then defend core”) and the LLM will generalize appropriately.

5. **Immediate Threat Response**  
   If an enemy appears in the JSON state, the AI can issue `attack <bot> <playerId>` instantly, keeping bots reactive.

6. **Named Subgroups**  
   Define groups in config:
   ```json
   "subgroups": {
     "AlphaTeam": { "type": "subrole_prefix", "value": "ROLE_SUB_ATT" },
     "Defenders": { "type": "role_equals",   "value": "ROLE_DEFEND" }
   }
   ```
   The AI can reference “AlphaTeam” or “Defenders” in its reasoning (e.g. “Tell AlphaTeam to hold the lab entrance”).

7. **In‑Game Chat & TTS Feedback**  
   Bot chatter and AI announcements appear in server chat (and can be spoken via TTS if enabled), keeping human players informed of bot tactics.

---

## 2. Guiding the AI via Configuration

All behavior hints live in the JSON config file. Edit `gravebot_ai_config.json` and restart the server and Python backend to apply changes.

### 2.1 Adding a High‑Level Mission

Include a `mission` field to prime the system prompt:
```json
{
  "mission": "Secure the SCI lab in the first 2 minutes, then defend resources until match end."
}
```
The backend will prepend:
```python
SYSTEM_PROMPT = f"Mission: {config.get('mission', '')}\n" + BASE_PERSONALITY_PROMPT
```

### 2.2 Tuning AI Creativity

Set the temperature:
```json
{ "temperature": 0.5 }
```
- Lower (0.1–0.4): more deterministic, conservative plays  
- Higher (0.6–0.9): more creative, risk‑taking strategies

### 2.3 Defining New Subgroups

Create named collections:
```json
{
  "subgroups": {
    "Guardians": { "type": "role_equals", "value": "ROLE_DEFEND" },
    "HarvestCrew": { "type": "subrole_prefix", "value": "ROLE_SUB_ATT_GET" }
  }
}
```
The AI will list these groups in its prompt and can reference them directly.

### 2.4 Enforcing Additional Constraints

Add any new minima:
```json
{ "subrole_constraints": { "ROLE_SUB_ATT_RTRN_SCI": 1 } }
```
Ensures at least one bot always returns SCI samples to the lab.

---

By editing this config, you control the AI’s system prompt and guiding principles—no code changes required.
