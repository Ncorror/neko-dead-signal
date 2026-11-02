# RTS Android 0.0.4 — Fixes and commander portraits

**Date:** 2026-11-02. **Scope:** feedback from the screenshots + 4.6s screen capture, Android landscape.

## Fixed from real-device report
1. **RTS camera**: earlier input multiplied drag pixels by `camera_zoom * 0.018` and could sweep beyond the whole 50m field. Version 0.0.4 uses a reduced zoom-scaled speed `camera_zoom * 0.0014`, discards the threshold-crossing delta, clamps single-event spikes and dynamic pan bounds, keeps smoothing. No joystick or direct hero mode.
2. **Commander selection**: save immediately when choosing a race or officer to `user://commander_selection.cfg`; retain one last selected commander for Humans and Saari. Returning from landing and restarting the game restores the same selection, and the list scrolls to its selected entry. Clicking the current race no longer resets the commander.
3. **Portraits**: four original approved 2D commander dossiers cropped into lightweight JPG menu portraits, with originals preserved. On desktop and Android `.jpg.b64` files are decoded at runtime into ImageTexture. If not installed, holographic placeholder stays functional. Only Humans have approved original portraits; do not invent Saari portraits.

## Why portraits use base64 text assets
The connected GitHub write integration accepts UTF-8 text, not PNG/JPEG bytes. The installable, SHA-indexed asset ZIP contains the *four real original PNG files* and four optimized JPEGs encoded as UTF-8 `.jpg.b64`. The latter are explicitly included with Godot's Android `include_filter`. This is a bootstrap transport format, **not** a long-term art pipeline; once binary uploads are possible, commit ordinary optimized JPG/PNG and simplify loading.

**IMPORTANT:** GitHub doesn't yet contain the newly packaged image payloads. Download `REINA_RTS_PORTRAITS_v004.zip` from the conversation and publish from Termux:

```bash
pkg install -y git gh unzip
unzip -n ~/storage/downloads/REINA_RTS_PORTRAITS_v004.zip -d ~
bash ~/REINA_RTS_PORTRAITS_v004/publish_to_github.sh
```

The script makes a fresh temporary clone, adds only the 4 portraits and 4 art sheets, verifies no preexisting file is overwritten with different bytes, commits and pushes to `main`. It doesn't touch live Vienna services, game data or legacy projects. Until that push is complete, APK exports have holographic placeholders.

## Android manual retest
- In the orbital UI, select **Амина → Рэйна → Мира → Лира**, check each active highlight and portrait changes after assets are present.
- Choose Лира, land, return, verify Лира remains selected. Choose Саари/Оралин, switch back to Humans, verify Лира is restored.
- Close/reopen app, verify the last selected faction/commander survives.
- On landing, draw a short finger motion of ~8px: no pan/attack/move until a true tap. Swipe 100–200px and check the camera no longer teleports across the map or exposes huge grey borders.
- Tap the HUD controls while the camera is moving: no move order from UI.
- Test +/− zoom and map-edge panning, tap to attack enemy, all-unit movement and collection; no regressions.

## What CI proves
The Vienna Runner validates Python source contracts, headless Godot menu/landing regressions, A* navigation, Android export and signing. It **cannot simulate full Android touchscreen timing**, and cannot test portraits in APK until their source files are uploaded. Device recordings remain authoritative.
