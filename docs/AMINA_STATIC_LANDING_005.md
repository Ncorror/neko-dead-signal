> Исторический срез указанного этапа. Описания старых ограничений и чисел тестов относятся к нему. Текущее состояние и тестбук — [индекс документации](README.md), исправления аудита — [0.0.15](AUDIT_2026-11-04.md).

# Amina: experiment with unrigged Meshy character in RTS landing (0.0.5)

Date: 2026-11-03. Status: Android physical visual QA required.

## Changes

- Current imported character `client/assets/characters/amina/preview.glb` is an **unrigged Meshy mesh**: no skeleton or animation clips. It is only a temporary visual and **cannot** walk/idle with an animation yet.
- Orbit menu: the model was too small because its source vertex height is only around 0.95 units. We now measure visible mesh AABBs (including transforms), normalize to **2.75 units** inside the preview, bring the orbital camera closer and turn the source about Y by 90°.
- Landing: when **Humans → Amina** is selected, try the existing rigged path first (and keep its original runtime). If no valid animated/rigged model is present, use the static GLB as a **1.90-unit** visual inside the **existing** Combatant node. The placeholder capsule is hidden only after GLB import and successful bounds normalization.
- Selection, navigation, attacks, HP, animation hooks and sentry combat are unchanged. A static character will **slide** while moving. Other officers/Saari keep their existing capsule placeholders.
- A debug-only button **ОСМОТР 3D** focuses/zooms the **RTS camera**, not direct character control. Toggle back via normal zoom controls.

## Files & tests

- `client/scripts/rts_character_fit.gd`: common AABB-based normalization (source mesh dimensions, transform-aware).
- `client/scripts/commander_3d_preview.gd`: menu fit and framing.
- `client/scripts/operation.gd`: new optional static-world character + debug inspect focus.
- `client/tests/test_amina_visual.tscn`: Godot regression checking menu preview, battle model attachment and actual unit movement.

## What to test on phone

1. Open the orbital view and choose Amina. She should be visibly larger, in a frame-filling view, and still turn slowly.
2. Tap “Начать высадку”: Amina should be a real visible character rather than the cyan capsule. Escort stays a capsule.
3. Tap **ОСМОТР 3D** on the debug HUD, check her feet touch the field, her full body is not underground, and the camera doesn't jump outside the map.
4. Give a move order: she moves together with her unchanged underlying RTS unit. She should not animate yet.
5. Check selection rings, “ВСЕ”, “СТОП”, firing at sentry and collecting containers.
6. Select Reina or Saari, land, and make sure no Amina mesh leaks into their units. Return to ship and repeat.

**Do not treat screenshot aesthetics/rotation as validated** by headless Godot. Send screenshots and optional short video + diagnostic ZIP. If model points sideways, flip the test yaw constant without editing the original GLB.

## Source and future asset

The user has already produced a better front-facing full-body A-pose turnaround sheet for humanoid rigging. That *reference image* is separate from this **unrigged** experimental GLB. Once a rigged and animated Amina is imported, the existing `amina_rigged.glb` route takes priority over the static preview. Rig validation and Idle/Walk clip tests remain mandatory.
