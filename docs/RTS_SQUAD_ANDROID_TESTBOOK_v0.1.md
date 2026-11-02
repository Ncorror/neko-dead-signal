# RTS Squad Test — Android alpha checkpoint

2026-11-02 · Android pre-alpha 0.0.3 · First landing

## Implemented

- UI lists human officers **Амина, Рэйна, Мира Кейд, Лира Восс** and Saari officers **Сэйра Нэл, Оралин**.
- A local map with **two placeholder units**, commander and escort, plus obstructing boxes.
- Tap unit to select it; `ОФИЦЕР` and `ЭСКОРТ` select individual units; `ВСЕ` selects both; `СТОП` clears their movement orders. Tap ground to assign per-unit formation destinations.
- `AStarGrid2D` grid computes alternate paths around static boxes (1 metre cell, orthogonal adjacency; 0.75 m obstacle clearance).
- Single-finger drag pans the RTS camera. `+`/`−` zoom. Controls and the battlefield use native touches. Touch-to-mouse emulation stays disabled. No manual hero joystick.
- Every ~3 seconds local log line `RTS_PERF fps=... units=... selected=... orders=...` for tester reporting.
- Optional Amina model import hook: game reads `res://assets/characters/amina/amina_rigged.glb` only when she is selected and resource exists. It requires a valid `AnimationPlayer` with identifiable `Idle` and `Walk` clips. Otherwise it **keeps the working placeholder**.

## IMPORTANT: limitations (not a complete RTS)

- Movement is local, through a flat A* grid; current characters do not physically collide with one another. No obstacle rebuild/dynamic path updates yet.
- UI group selection is via `ВСЕ`, not yet drag-select rectangle.
- One local sentry encounter supports attack orders, line of sight, range, cooldowns and casualties. Production, skills, networking, fog of war and mobile enemy AI are pending.
- Amina's current Meshy GLB is **unrigged**. No real character animations until a rigged GLB is supplied. Game has no paid Meshy assets bundled.
- Headless CI confirms source import, scripted navigation and Android APK signing; it does not prove touch responsiveness or visual quality on your phone.

## Menu regression · 0.0.3

- The title, both fleet buttons and deploy button should be visible immediately in landscape. The title stays on one line.
- Tap the right side below the header. The game should remain open.
- Tap the small exit button in the top right, then cancel. The menu should remain open. Confirming the exit closes the game.

## Android test book

1. Open orbital UI, choose Humans → АМИНА, inspect visible portrait info and tap `НАЧАТЬ ВЫСАДКУ`.
2. Select commander and tap a destination behind a box; verify she walks **around**, not through, it. Repeat from different directions.
3. Select escort and send another movement order; the commander should keep her earlier route.
4. Tap `ВСЕ`, then a destination; two units should head toward distinct nearby cells.
5. During movement tap `СТОП`: selected unit(s) should halt.
6. Pan map with a finger, zoom with `+` and `−`, ensure buttons do not place move orders accidentally.
7. Select both, tap the orange sentry, then stop the escort alone. Verify that only the officer keeps attacking. Select the escort again and send it back into the fight. Both sides should take damage only within range and with a clear line of sight.
8. Collect the three gold crates using either survivor. Each adds 100, including when both arrive together. Destroying the sentry plus collecting all three should show victory and freeze orders.
9. Return to the ship. Verify the debrief and the previously selected officer. Deploy again and verify full health, a live sentry, three crates and zero supplies. Move both into sentry range without an attack order to test defeat. In a fresh run, leave early and verify the withdrawal report.
10. Repeat with Saari. Record device, Android version, FPS (from `RTS_PERF`), UI screenshot and any double taps, missed orders or overlapping controls.

## Meshy → rigged Amina handoff

Asset path: `client/assets/characters/amina/amina_rigged.glb` (not committed). Rig a **single A-pose character** in Meshy, with humanoid skeleton, apply Idle/Walk/Run, export GLB **All Added**; validate clip names and knee/skirt/ponytails. Save original and hash. Upload via separate Git commit before expecting model to appear.

Official engine reference: [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html). Animation plan: [ANIMATION_REQUIREMENTS_RTS.md](ANIMATION_REQUIREMENTS_RTS.md).
