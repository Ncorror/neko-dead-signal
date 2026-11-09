# NEKO: DEAD SIGNAL — Female Base v3 · Avatar Production Checkpoint

Updated: 2026-11-09. Production branch: `feature/female-base-v3-production`.
**Mission:** Build a modular, customisable human female MMO avatar with shared skeleton/animations for Android. Not a standalone fixed heroine. The four named officers remain independent NPC/preset identities.

## Confirmed starting point

- **Approved:** Female Base v3, four original 1024×1536 PNG views in Google Drive; do not regenerate or resubmit them. See [approved art + hashes](PRODUCTION_FEMALE_BASE_V3_APPROVED_2026-11-06.md).
- **Existing Meshy candidate:** `reina_master_model` / `glb_reina-master-model_3a4ac71c` (Meshy Agent, created before Pro subscription). Viewer reported **552196 triangles and 306073 vertices**; not yet independently checked on exported GLB.
- **Meshy Pro:** Active as of 2026-11-09; no re-shopping and no new concept generation.
- **Previously reviewed:** face differs from v3 around nose/lips/chin, hair interior and fingers need scrutiny; AI regeneration risks altering identity. Do not run it as a blind fix.
- **Meshy Agent claimed welded/one-piece model.** This has **not** been verified from geometry. A GLB with one mesh may still contain multiple disconnected geometric islands; a connected mesh requires actual topology editing before modularisation.
- **Existing game:** Godot 4.7.2 Android client 0.0.28. `commander_3d_preview.gd` contains a SubViewport-based interactive 3D viewer, but existing Amina preview GLB is static. Character Creator is currently a plan only: [architecture](CHARACTER_CREATOR_ANIME_MMO_PLAN_2026-11-06.md).
- **Do not touch:** `user://commander_selection.cfg` and `user://world/progress-v1.json` without a migration; no change to RTS gameplay or Android package for this work.

## Checkpoints and gate criteria

### Gate 0 — Preserve and inspect Master (next)

1. In Meshy Pro, open **existing** `reina_master_model`; choose **Download → GLB** with existing textures. Do not apply Remesh, Retexture, Rig or Animate to the sole original.
2. Archive the original under a versioned name such as `female_base_v3_master_original.glb` and record SHA-256. Keep it private in Drive or another backed-up source of truth. Do not commit huge raw high-poly files to game/client.
3. Run read-only inventory: `python3 tools/avatar/inspect_glb.py female_base_v3_master_original.glb > female_base_v3_master_audit.json`. The script lists mesh definitions, skin, animation, morph targets, material and image counts. It does **not** prove whether parts can be disconnected, face quality, rig deformation, UV integrity, visual similarity or Android performance.
4. Assess the GLB visually and geometrically: front/side/back, eyes, lips, nose, chin, hand joints, A-pose, foot placement, texture maps and connected components. Compare to approved v3 views.
5. **Gate 0 PASS:** intact GLB + recorded checksum + inventory + explicit list of fixable defects; otherwise stop rather than spending more credits.

### Gate 1 — Build modular editable base

- Preserve source Master. Create separate working copy.
- Produce clean female body topology suitable for animation and blend shapes; if the source cannot be edited safely, treat it as a visual reference and reconstruct proper base topology instead.
- Separate **base body**, **hair modules**, **clothing/armor**, **shoes** and **accessories** as editable/attachable assets. Do not assume Meshy Auto-Rig produces modular meshes or facial morph targets.
- Make face preset variations and tested blend shapes for facial proportions; keep face identity consistent with the NEKO anime art direction. Use material parameters for eye/hair/skin colours.
- **First vertical-slice variants (targets, not imposed limits):** 3 face presets, 4 hairstyles, 4 eye colours, 3 skin tones, 2 body variants, 1 modular starter outfit. No need to produce all variants before first skeleton verification.
- Each apparel piece must use compatible coordinate scale, attachment layout, skeleton and/or skin weights. Hidden body geometry under opaque outfits should not protrude.
- Keep a separate light game version with LODs; current planning reference for hero LOD0 12–15k triangles, LOD1 5–7k, LOD2 1.5–3k; benchmark on Android before treating them as hard caps.
- **Gate 1 PASS:** actual colour/material/morph or component switch changes the 3D avatar without breaking identity or meshes; not merely duplicated complete models.

### Gate 2 — Shared humanoid skeleton

- Meshy requires Remesh before rigging a source over 300k faces; do so on a **working game mesh**, not the 552k Master.
- Aim for one consistent skeleton specification for this female human avatar family, with identical bone naming/hierarchy/rest pose for compatible outfits and clips. Meshy Humanoid Rig may be used for the first proof, but review its weights in shoulders, elbows, hips, knees, hands and feet.
- Keep original unrigged modular source, rigged copy and exported animation library separately. Real blend shapes / custom face rigs require a DCC workflow outside Meshy if needed.
- **Gate 2 PASS:** model deforms correctly on both the default and an edited avatar configuration.

### Gate 3 — Motion library (only after Gate 2)

- Start on the actual final shared rig: `Idle` (action_id 0), `Walking_Woman` (1) or an in-place walk, `Run_02` (14) or in-place run.
- Preview them in Meshy and export **GLB with All Added animations**. Animation library presets can be added without generation credits; Text to Motion consumes credits (see current Meshy docs).
- Keep game movement authoritative. No unintentional root-motion translation. Later: `Attack` (4), `Hit_Reaction` (178), `Dead` (8); then weapon/class-specific actions.
- Validate transitions, arm/leg intersections, boots/outfits/long hairstyles, and both variants of body morphs.
- **Gate 3 PASS:** exported clips are present and can play on changed 3D avatar in Godot; no false claims based on web-preview only.

### Gate 4 — Godot editor and Android

- Develop new `character_creator.tscn` and `character_creator.gd`; reuse fit/rotation patterns from existing commander preview rather than replacing it.
- Create `avatar_assembler.gd` for modular hair/gear and shape-key/material values; `character_appearance.gd` for validated, versioned choices; `character_profile_store.gd` for separate `user://characters/profiles-v1.json`.
- Save asset IDs / choices / morphology values only, **not** copied mesh or file paths from external inputs. Existing RTS save files and local sectors remain unchanged.
- Android acceptance: change face/hair/eyes/outfit, spin/zoom the 3D preview, play idle/walk/run, save/reload, verify same person without regressions. Measure frametime and memory on device.
- Multiplayer synchronisation happens later after server-side identities and authoritative validation exist.

## Meshy workflow and cautions

- Official processing sequence for an already final asset: Remesh → UV → texture (only if needed) → Rig → Animate. **Our modular editor changes this order before rigging:** first inspect and create the clean *editable* game mesh, then use post-processing and rig.
- Meshy cannot make its Humanoid Rig into a facial expression rig by itself. Morphs/material variations and production geometry require external DCC/editing.
- The initial Meshy candidate was created on the Free plan. Original licensing/attribution status must be retained and checked before release; Pro bought later does not retroactively change the earlier generation's rights.
- Avoid anonymous new Meshy prompts or repeat generation while Gate 0 is unfinished; monitor credits at each paid operation.

References: [Meshy rigging](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging), [Remesh](https://docs.meshy.ai/en/webapp/guides/3d-model/remesh), [Animations](https://docs.meshy.ai/en/webapp/guides/animate), [Godot GLB import](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html), [approved animation matrix](ANIMATION_REQUIREMENTS_RTS.md).

## Production log (single live checkpoint)

| Checkpoint | Status | Evidence | Next action |
|---|---|---|---|
| Art v3 | **Approved** | Drive 4 PNG, ZIP, SHA manifest | Preserve |
| Meshy Master | **Viewer exists** | Previously inspected Meshy Agent model, metrics from viewer only | Export original GLB |
| Exported Master | **Not verified** | No original GLB received / analysed | Audit mesh + materials + topology |
| Modular game base | **Not started** | No morph-ready / separate modules yet | Start after Master inspection |
| Common Rig | **Not started** | No base exported with validated skin | After topology approval |
| Idle/Walk/Run | **Not started** | No validated clips in Godot | After rig |
| Character Creator | **Designed, not built** | Existing design document | Implement on isolated branch once source geometry is known |

**Last verified point (2026-11-09):** approved source art exists, existing Master recorded in prior Meshy screenshots, Meshy Pro confirmed, game preview mechanism verified in code. This branch adds a non-destructive GLB metadata inspector. The actual GLB export and model/animation validation have NOT occurred.
