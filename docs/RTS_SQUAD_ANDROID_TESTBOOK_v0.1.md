# RTS Squad Test — Android alpha checkpoint

2026-11-02 — `feat/rts-squads-grid-pathfinding`

## Implemented

- UI lists human officers **Амина, Рэйна, Мира Кейд, Лира Восс** and Saari officers **Сэйра Нэл, Оралин**.
- A local map with **two placeholder units**, commander and escort, plus obstructing boxes.
- Tap unit to select it; `ОФИЦЕР` and `ОТРЯД` select individual units; `ВСЕ` selects both; `СТОП` clears their movement orders. Tap ground to assign per-unit formation destinations.
- `AStarGrid2D` grid computes alternate paths around static boxes (1 metre cell, orthogonal adjacency; 0.75 m obstacle clearance).
- Single-finger drag pans the RTS camera. `+`/`−` zoom. Duplicate Android mouse-emulated touches disabled. No manual hero joystick.
- Every ~3 seconds local log line `RTS_PERF fps=... units=... selected=... orders=...` for tester reporting.
- Optional Amina model import hook: game reads `res://assets/characters/amina/amina_rigged.glb` only when she is selected and resource exists. It requires a valid `AnimationPlayer` with identifiable `Idle` and `Walk` clips. Otherwise it **keeps the working placeholder**.

## IMPORTANT: limitations (not a complete RTS)

- Movement is local, through a flat A* grid; current characters do not physically collide with one another. No obstacle rebuild/dynamic path updates yet.
- UI group selection is via `ВСЕ`, not yet drag-select rectangle.
- No production, fighting/attack commands, skills, networking, fog of war, authoritative server or advanced unit AI.
- Amina's current Meshy GLB is **unrigged**. No real character animations until a rigged GLB is supplied. Game has no paid Meshy assets bundled.
- Headless CI confirms source import, scripted navigation and Android APK signing; it does not prove touch responsiveness or visual quality on your phone.

## Android test book

1. Open orbital UI, choose Humans → АМИНА, inspect visible portrait info and tap `НАЧАТЬ ВЫСАДКУ`.
2. Select commander and tap a destination behind a box; verify she walks **around**, not through, it. Repeat from different directions.
3. Select escort and send another movement order; the commander should keep her earlier route.
4. Tap `ВСЕ`, then a destination; two units should head toward distinct nearby cells.
5. During movement tap `СТОП`: selected unit(s) should halt.
6. Pan map with a finger, zoom with `+` and `−`, ensure buttons do not place move orders accidentally.
7. Return `НА КОРАБЛЬ` and choose Saari; repeat to catch selection/reset bugs.
8. Record device, Android version, FPS (from `RTS_PERF` logs), UI screenshot and any bug. **Do not test on a production account: no actual network game exists.**

## Meshy → rigged Amina handoff

Asset path: `client/assets/characters/amina/amina_rigged.glb` (not committed). Rig a **single A-pose character** in Meshy, with humanoid skeleton, apply Idle/Walk/Run, export GLB **All Added**; validate clip names and knee/skirt/ponytails. Save original and hash. Upload via separate Git commit before expecting model to appear.

Official engine reference: [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html). Animation plan: [ANIMATION_REQUIREMENTS_RTS.md](ANIMATION_REQUIREMENTS_RTS.md).
