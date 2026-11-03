> Исторический срез указанного этапа. Описания старых ограничений и чисел тестов относятся к нему. Текущее состояние и тестбук — [индекс документации](README.md), исправления аудита — [0.0.15](AUDIT_2026-11-04.md).

# RTS Android 0.0.4 — Fixes and commander portraits

**Date:** 2026-11-02. **Scope:** feedback from the screenshots + 4.6s screen capture, Android landscape.

## Fixed from real-device report
1. **RTS camera**: earlier input multiplied drag pixels by `camera_zoom * 0.018` and could sweep beyond the whole 50m field. Version 0.0.4 uses a reduced zoom-scaled speed `camera_zoom * 0.0014`, discards the threshold-crossing delta, clamps single-event spikes and dynamic pan bounds, keeps smoothing. No joystick or direct hero mode.
2. **Commander selection**: save immediately when choosing a race or officer to `user://commander_selection.cfg`; retain one last selected commander for Humans and Saari. Returning from landing and restarting the game restores the same selection, and the list scrolls to its selected entry. Clicking the current race no longer resets the commander.
3. **Portraits**: four original approved 2D commander dossiers cropped into lightweight JPG menu portraits, with originals preserved. On desktop and Android `.jpg.b64` files are decoded at runtime into ImageTexture. If not installed, holographic placeholder stays functional. Only Humans have approved original portraits; do not invent Saari portraits.

## Why portraits use base64 text assets
The connected GitHub write integration accepts UTF-8 text, not PNG/JPEG bytes. The installable, SHA-indexed asset ZIP contains the *four real original PNG files* and four optimized JPEGs encoded as UTF-8 `.jpg.b64`. The latter are explicitly included with Godot's Android `include_filter`. This is a bootstrap transport format, **not** a long-term art pipeline; once binary uploads are possible, commit ordinary optimized JPG/PNG and simplify loading.

**UPLOAD COMPLETED — 2026-11-02:** All four original commander PNG dossiers and all four optimized `.jpg.b64` portraits have been pushed to `main` by Termux in commit `871601bc2a0e7c886e7a3719f1792c7770dc3c28`. The upload script printed `PORTRAITS_PUBLISHED_TO_MAIN`. GitHub file existence was separately verified.

**Vienna rebuild:** [Android Debug #28](https://github.com/Ncorror/reina-dead-signal-rts/actions/runs/41522996901) — **CI SUCCESS**, artifact `reina-rts-debug-28`, signed ARM64 APK. This run includes the art push and passed menu, landing and export checks. Real Android visual QA remains outstanding.

## Android manual retest
- In the orbital UI, select **Амина → Рэйна → Мира → Лира**, check each active highlight and portrait changes after assets are present.
- Choose Лира, land, return, verify Лира remains selected. Choose Саари/Оралин, switch back to Humans, verify Лира is restored.
- Close/reopen app, verify the last selected faction/commander survives.
- On landing, draw a short finger motion of ~8px: no pan/attack/move until a true tap. Swipe 100–200px and check the camera no longer teleports across the map or exposes huge grey borders.
- Tap the HUD controls while the camera is moving: no move order from UI.
- Test +/− zoom and map-edge panning, tap to attack enemy, all-unit movement and collection; no regressions.

## What CI proves
The Vienna Runner validates Python source contracts, headless Godot menu/landing regressions, A* navigation, Android export and signing. It **cannot simulate full Android touchscreen timing**, and cannot prove portraits render correctly on a physical device even after the source files are uploaded. Device recordings remain authoritative.
