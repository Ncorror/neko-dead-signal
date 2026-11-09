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

**2026-11-09 CI:** `scripts/test_avatar_glb_inspect.py` (valid synthetic GLB + rejected corrupt file) passed in `Repository structure` on commit `db5dcb59893825f87a89d7af3e841a810730e221` (two successful runs). This verifies the utility on synthetic fixtures only; the real Meshy Master is still untested.


## 2026-11-09 — Decision: static pose for Character Creator and Inventory, no gameplay rig yet

**New evidence from the user's Meshy Pro UI screenshots:** a newly generated high-detail Female Base v3 is visible in Meshy Viewer, natural-looking A-pose; selected generation settings shown: Ultra 2K geometry, Multi-view, Meshy 7 textures 4K, A-pose, Image Enhancement off, Private license. The new generated GLB has NOT been downloaded or evaluated by us. Do not conflate the earlier Free-plan `reina_master_model` and this newly generated Pro-plan asset until asset IDs and original exports are verified.

**User decision:** current scope is **only static, high-quality Character Creator / Inventory presentation**. Do **not** add persistent skeletal rig, idle/walk/run, or gameplay LOD as part of this current step; those are deferred and remain future goals. The previously documented Gates 2–4 for game motion are therefore **deferred**, not mandatory next actions.

**Direct response from Meshy Agent, pasted by user:** Meshy cannot manually repose the *existing* GLB without regeneration, and cannot bake the modified pose into a separately exported **static skeleton-free** GLB. Agent suggested a Blender DCC workflow with a temporary armature, posing, applying deformation, and export without skeleton; it stated it did not run any tool or spend credits. Treat these as Agent's product claims, not independent proof of its ability to preserve every vertex/texture exactly.

**Chosen safe route:**

1. Preserve original **new paid-plan** Meshy GLB (with textures), record original asset ID, file hash, and backup (prefer existing Drive `Игра`). Do not spend more Meshy credits to rerender the character just to lower the arms.
2. On **a copy** of the GLB, inventory vertices/primitives/materials, check if separate components or connected mesh exist. Use `tools/avatar/inspect_glb.py` for the structural report; real mesh analysis and look inspection still required.
3. Use Blender as a **temporary authoring tool** on server or GitHub runner (no user PC required); deform arms/hands/shoulders with a temporary helper armature + weights if needed or proportional mesh editing. Temporary rig is **NOT** part of the final GLB. High-poly auto skinning may fail, especially if the model is welded; this is not a one-click guaranteed conversion.
4. Apply/bake deformation to a duplicate static mesh; remove helper skeleton and animations from exported GLB. Verify in Godot: skins=0, animations=0, original look maintained, relaxed standing posture, correct material/UV mapping and no joint artifacts. Result naming: `female_base_v3_editor_relaxed.glb`. Use for both creator and inventory initially, rather than making unnecessary separate complete meshes.
5. All optional rigging, blinking, procedural poses and gameplay animation work waits for explicit renewed scope; static GLB can rotate/zoom as a scene node but cannot perform skeleton-based gestures/idle.

**Quality caveat:** neither Blender nor any GLB exporter guarantees identical byte streams or geometry after a deliberate pose change. UV/texture identifiers may remain, but vertex positions necessarily change and export/import may retriangulate or adjust normals. Verify source-versus-output rather than advertise "100% lossless".

**Next action:** user uploads **the newly generated Pro-model's original GLB** (not screenshots or old Free Master) to existing Drive game folder or this chat. Then run read-only audit; only after a geometry decision make the first static relaxed pose copy. No source asset overwrite.


## 2026-11-09 — COMPLETE: Pro Female Base v3 original audited; editor relaxed GLB produced

This new result **supersedes the earlier "original GLB not received" / "Blender required" / "next: export the old pre-Pro master" statuses above**.

- **Original new Pro asset:** `Meshy_AI_Neon_Catgirl_Athlete_1109091814_texture.glb` at [Drive / Игра / Модели](https://drive.google.com/file/d/1bbRnI-hDvyg7K_-R6sCZA4jvRby5rFUO/view). Original SHA-256: `47695f29591dd8562d5defbd3b454b2eb2bbd10e186fae9672e8ff65b782064c`. Kept unchanged.
- **Source inspection completed on actual original:** 34,775,728 bytes; GLB 2.0, 319,307 vertices, 566,986 triangles, 1 mesh / 1 primitive, 1 material, 3 embedded JPEG images; skins=0, animations=0. VTK viewer preview rendered successfully.
- **Static relaxed editor model created and added to the same Drive folder:** [`female_base_v3_editor_relaxed.glb`](https://drive.google.com/file/d/1ALs9BIDp9QgkVh-XoSCgZ8ne0fPYjYBA/view). Output SHA-256: `7cc75e795daea65520520d0547762a6c0e6e18e3432be5a1ded753d999983b6a` (local generated copy); 34,775,728 bytes, 319,307 vertices, 566,986 triangles.
- **Method:** geometry-local, smoothly weighted symmetric arm repositioning (22° nominal from the approved A-pose), **not Meshy regeneration and no Blender/temporary rig required**. Reproducible script: `tools/avatar/pose_female_base_v3_static.py` (Python 3 + NumPy); use only with this approved base model, output to a different path.
- **Local geometry checks PASS:** original and output have identical index accessor; all three embedded JPEG byte-hashes match; UV buffers and materials unchanged; zero inverted face normals in an original-vs-output all-triangle comparison (0 / 566,986); skins=0; animations=0.
- **Visual review:** output rendered from front, side, 3/4 and back with VTK offscreen; arms are near the sides, visible texture and face appearance retained, no black elbow tears in the accepted output. This is a local render check, **not a Godot / Android deployment test**.
- **No gameplay changes**; original 3D and all approved source art untouched; no Meshy credits spent.
- **Verified delivery:** Drive reported upload success and metadata readback returned 34,775,728 bytes in the intended `Модели` folder.
- **NEXT:** integrate this static GLB (not rig/animations) into the character-creator/inventory 3D preview and validate on actual Android device. Character creator scene not yet implemented; preserve the existing RTS save formats and gameplay systems.


## 2026-11-09 — Godot player avatar integration (branch implementation)

- Runtime files authored for this branch: `client/scenes/character_creator.tscn`, `client/scripts/character_creator.gd`, `client/scripts/avatar_static_preview.gd`, `client/scripts/character_profile_store.gd`.
- Main orbital menu gains `МОЙ ПЕРСОНАЖ` entry. It does not alter the existing commander roster, 3D commander preview or operation paths.
- Screen has functional **editor/inventory** views around ONE shared static Female Base v3 GLB, orbit by touch/mouse, two-finger/wheel zoom and reset view. Editor can save and reload the local player's name and immutable static base ID in a **new** `user://characters/profiles-v1.json`.
- **Asset source of truth remains Drive, not high-poly Git blobs.** The Android CI installs the SHA-256-pinned 34.8 MB relaxed GLB before Godot import using `scripts/install_female_base_v3.py` (idempotent, never overwrites a different existing file). Thus the packaged APK includes the asset; source checkouts install it explicitly.
- Godot test `client/tests/test_character_creator.tscn` is wired to Android CI to check real imported mesh, both tabs, standalone profile roundtrip, old save formats and navigation. Actual CI result must be checked separately; this paragraph documents intended test, not proof of a PASS.
- **No persistent rig, gameplay animation, Meshy regeneration, or generic equipment swapping** in this step: only a fixed static base model exists.
- **NEXT:** CI import/smoke + Android APK tester verification, then expandable appearance and inventory components when actual modular assets exist.


## 2026-11-09 — Android ARM64 APK built and uploaded — CI PASS

**Verified commit (code):** `4b222d5fe6ca2c9dcdaa63abbfa78cb23a9f7ad9` (includes smoke-test lifetime correction). **Godot Android workflow:** [run 42610511901](https://github.com/Ncorror/neko-dead-signal/actions/runs/42610511901), **conclusion success**.

- Pinned Drive model download: PASS. Godot import: PASS. `client/tests/test_character_creator.tscn`: PASS, checks actual relaxed static GLB, editor/inventory tabs, separate local profile save/load and back navigation. Existing RTS tests also PASS.
- Signed Android ARM64 debug APK: CI export and `apksigner verify` PASS. GitHub artifact: `neko-dead-signal-debug-116` (run 42610511901); debug APK version remains 0.0.28. APK size: 86,437,243 bytes; SHA-256 `26a703b87976a289cac2418019a209d7e96539b4974a32d916798136fd98ca64`.
- **Independent extracted APK inspection:** ZIP structure valid; packaged assets include `.godot/imported/editor_relaxed.glb-....scn`, three `editor_relaxed_N.jpg` texture imports, `scenes/character_creator.tscn.remap`, `scripts/character_creator.gdc`, `scripts/avatar_static_preview.gdc`, and `scripts/character_profile_store.gdc`. This proves packaging, not on-device graphics quality.
- **Still to verify on user Android:** open `МОЙ ПЕРСОНАЖ`, inspect body material and four angles, touch orbit and pinch zoom, editor ↔ inventory switch, name save/reload and Android Back. Screenshots/logs if defects observed. No other work is blocked.
- **Merge status:** PR #39 remains draft for an actual device visual acceptance. `main`, current RTS saves, and source GLB remain unchanged.
