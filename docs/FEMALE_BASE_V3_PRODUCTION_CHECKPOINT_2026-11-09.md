# NEKO: DEAD SIGNAL — Female Base v3 · единый журнал производства

**Дата:** 2026-11-09. **Ветка:** `feature/female-base-v3-production`. **Актуальная задача:** отдельная игровая женская модель (Android MMO-RTS), скелет и анимации.

## Подтверждённые исходники

- Четыре эталонных изображения Female Base v3: [Drive — Approved V3](https://drive.google.com/drive/folders/1EKHGcaXvoEKTyNs97xUw9mUvk395MOfd) и [канон](PRODUCTION_FEMALE_BASE_V3_APPROVED_2026-11-06.md).
- **Оригинальный Meshy Pro GLB в A-позе**: `Meshy_AI_Neon_Catgirl_Athlete_1109091814_texture.glb`, [Drive / Игра / Модели](https://drive.google.com/file/d/1bbRnI-hDvyg7K_-R6sCZA4jvRby5rFUO/view). SHA-256 `47695f29591dd8562d5defbd3b454b2eb2bbd10e186fae9672e8ff65b782064c`. 34,775,728 байт, 319,307 вершин, 566,986 треугольников, 3 текстуры, skin=0, animations=0.
- Эта Female Base — **редактируемый игровой аватар игрока**, а не одна из четырёх именованных офицеров. Канон персонажей и текущие RTS-механики не затрагиваются.

## Признанная ошибка и выполненная очистка

- Попытка опустить руки прямой деформацией геометрии (`female_base_v3_editor_relaxed.glb`) **забракована реальным тестом на Android**: ломаются руки/плечи, голова и ноги обрезаются в просмотре. Старые локальные структурные «PASS» не подтверждали качество на телефоне.
- **Удалены из Drive:** дефектный `female_base_v3_editor_relaxed.glb` и использовавший его тестовый `NEKO_DEAD_SIGNAL-0.0.28-FemaleBaseV3-debug.apk`. После удаления в папке «Модели» оставлен только оригинальный Pro GLB.
- **Откат в рабочей ветке:** убраны скрипт прямой деформации, тестовый editor/inventory, зависимые тесты и скрипт загрузки плохого GLB. `client/scripts/main.gd` и Android CI workflow восстановлены к исходникам до эксперимента. Проверенный read-only `tools/avatar/inspect_glb.py` сохранён.
- **`main` не менялась в рамках этой работы**, исходные Meshy/PNG не изменены и не удалены. Экспериментальные APK больше не являются релизами.

## Текущая цель — игровая версия, отдельно от master

**Утверждённое направление 2026-11-09:** создать оптимизированную игровую копию исходной А-позы; теперь **игровой скелет и анимации нужны**, в отличие от завершённого и забракованного эксперимента статического редактора.

1. В существующей Meshy Pro генерации создать **отдельную игровую версию** через **Remesh → Fixed → 10K** как первый мобильный LOD. Не повторять Image-to-3D и не применять никакую позную трансформацию к исходному high-poly master. Если 10K действительно теряет лицо/волосы/заколки, сравнить результат с 30K, сохранив оригинал.
2. **Animate → Rig → Humanoid**. Исходная A-поза для риггинга подходит; выставить маркеры плеч/локтей/кистей/бедра/колен/щиколоток на соответствующих суставах. Убедиться, что обе руки сгибаются и вращаются вместе с плечами без растяжений.
3. Первые подтверждаемые движения на одном rig: **Idle**, **Walk**, **Run**; затем **Attack**, **Hit Reaction**, **Death**. Выбирать пресеты из библиотеки Meshy, а не платный Text-to-Motion, если нужное движение уже существует. Клипы должны принадлежать **одному и тому же скелету**.
4. Экспортировать из Meshy в **GLB с текстурами**, **Animation: All Added** и согласованным skeleton template. Название для игровой поставки: `female_base_v3_game_rig_animations.glb` в той же Drive папке «Игра → Модели».
5. После появления игрового GLB выполнить: `python3 tools/avatar/inspect_glb.py female_base_v3_game_rig_animations.glb`, затем `python3 tools/avatar/validate_game_glb.py female_base_v3_game_rig_animations.glb --min-clips 3`. Это **структурные проверки**, не подтверждение визуального качества.
6. Только затем подключать **новую игровую модель** в Godot, настраивать `AnimationPlayer/AnimationTree`, переходы idle/walk/run/attack и тестировать на телефоне. Для боёвки движения подчиняются командам RTS. LOD и FPS проверять на устройстве, не устанавливать искусственных ограничений заранее.

## Статус и следующий шаг

| Часть | Статус |
| --- | --- |
| Визуальный канон и исходный Pro GLB | **Есть, сохранены** |
| Неудачная статическая поза и APK | **Забракованы, удалены с Drive** |
| Изоляция неудачной интеграции в GitHub | **Выполняется в рабочей ветке** |
| Игровая remesh-модель | **Ещё не экспортирована** |
| Rig + анимации из Meshy | **Ещё не выполнены** |
| Android тест игровой анимации | **Не проводился** |

**Следующее практическое действие:** открыть исходный `Meshy_AI_Neon_Catgirl_Athlete_1109091814_texture` в аккаунте Meshy Pro и выполнить **Remesh → Fixed → 10K**. После получения игровой сетки — **Animate → Rig (Humanoid)**. Новые генерации персонажа не нужны.

Официальные руководства: [Remesh](https://docs.meshy.ai/en/webapp/guides/3d-model/remesh), [Rigging](https://docs.meshy.ai/en/webapp/guides/3d-model/rigging), [Animations](https://docs.meshy.ai/en/webapp/guides/animate).


## 2026-11-09 — Hardware-visible Meshy 10K/30K/100K rigging defect

**User-tested on Meshy Pro on Android, 2026-11-09:** after 10K Remesh + Humanoid rig, backside shorts/pelvis deform and a limb may appear mutilated during animations; same issue reproduced at **30K and 100K**, including other topology/mesh experiments. Idle-like motion also appears smeared from behind. **Do not recommend any more polygon-count iterations as a fix.**

**New independent read-only evidence:** the original untouched `Meshy_AI_Neon_Catgirl_Athlete_1109091814_texture.glb` was rendered from the back using vtkGLTFImporter, and its unanimated A-pose backside appears intact: symmetrical outfit, hips/legs, no comparable stretching. This does not prove whether post-Remesh or auto-skin weights introduced the damage, because exported *remeshed but unrigged* and *rigged* versions are not yet compared in the local runtime. The **likely** issue is rigging/weights at hips, pelvis and shorts, not a lack of triangles; also check UV/mesh after Remesh to distinguish sources precisely.

**Action agreed:** stop creating new Remesh variants. Save/download **one** representative failing *rigged* model GLB with existing animations (prefer 30K if available) into the existing Drive folder `Игра / Модели`; do not alter the original Pro master. After receiving it, examine actual skin joints/weight indices and inspect mesh/UV, then repair bindings with Blender/DCC and validate visually from back in multiple motion frames. If model cannot be repaired without source post-Remesh model, obtain that same-generation unrigged GLB as needed, not another generation. Avoid claiming automatic weight repair is guaranteed. No Godot gameplay changes, APK, or spending more Meshy credits yet.


## 2026-11-10 — Lyra Voss 20-clips Godot Android CI PASS

**Identity correction (explicit user decision):** this 30K skinned character is **Лира Восс**, the human sniper/scout **officer index 3**, **NOT Амина** (officer index 0). Do not silently relabel it or replace existing Amina assets. Separate prior static Female Base v3 master remains on Drive.

**Actual source input**
- Drive: [`Meshy_AI_Anime_Female_30k_20261110_animated_mixamo_All_animation (1).glb`](https://drive.google.com/file/d/1pGFfupTnkiciqnsIxJcA5-leoDHFqT9N/view), 40,074,004 bytes.
- Binary SHA-256: `2cdfae99b4dda6c69b608cdb3d46875d9003a7208e89e5683a2021592f9bf14e`.
- GLB v2, 1 skinned mesh, 31,007 triangles, 1 skin with **66 bones**, 2 embedded textures, **20 distinct animation clips**.
- Exported clips: `Running`, `Walking`, `Archery_Aim_with_Lateral_Scan`, `Archery_Shot_2`, `Bar_Hang_Idle`, `Charged_Spell_Cast_1`, `Dead`, `Fall_Dead_from_Abdominal_Injury`, `Hit_in_Back_While_Running`, `Kneeling_Reload`, `Roll_Dodge_1`, `Roll_Dodge_3`, `Roll_Dodge_4`, `Shot_and_Fall_Forward`, `Slow_Walk_Reload`, `Standing_Reload`, `Sword_Parry_Backward_3`, `air_squat`, `falling_down`, `walking_2`.

**Implementation**
- Code commits: `0fe6f259` (pinned downloader, Lyra motion catalog), `22905326` (menu 3D preview, RTS `LyraRig` under the original `Combatant`, 20-clip animation lab, Godot regressions and Android CI).
- Importing from Drive is reproducible and SHA-256 pinned via `scripts/install_lyra_voss.py`; the large GLB is not committed as a Git blob. This preserves repository size and does not alter the Drive source.
- Menu slot 3 displays Lyra with real skinned 3D. `ЛИРА / АНИМАЦИИ` opens `res://scenes/lyra_animation_lab.tscn`, presents all 20 clip names and manual clip playback + orbit touch. In RTS, an animated `LyraRig` accompanies the selected Lyra `Combatant` and responds to movement/stop. Other officers and their previews are unchanged.
- `Running` and `Walking` are verified **in-place** from hips animation track endpoint displacement; only these are assigned to ordinary RTS locomotion. Several other clips have 1–4.5m translation and are **not** assigned as automatic RTS movement.
- There is **no standalone Idle**. Current interim ready/idle presentation samples and pauses an existing `Walking` frame; no fake generated `Idle` clip is claimed.
- No existing fire damage, sniper range, fog visibility, auto-fire or weapon logic was changed. Lyra's intended sniper range 16→18 and actual sniper rifle/shot animations remain separate incomplete gameplay work. `Archery_Shot_2` is NOT a verified rifle animation.

**Verification**
- [GitHub Android Debug CI run 42735246350](https://github.com/Ncorror/neko-dead-signal/actions/runs/42735246350): **success**, including Python contract tests, server RTS regressions, actual GLB download/inventory and Godot import, real Lyra rig smoke, Lyra animation lab navigation/playback, existing Amina visual test, remaining RTS tests, Android ARM64 signed APK export.
- Android build ZIP artifact: `neko-dead-signal-debug-117`. Extracted **APK** (not archive) size **66,964,441 bytes**, SHA-256 **`ccade7c2a1f672a89c0745302409772581dbf6fbdd71e10e96aa423e6685cf96`**. Independent ZIP integrity check: PASS. Packaged imported `rigged.glb-....scn` and Lyra animation lab scene/scripts found.
- APK uploaded to Drive and metadata verified: [`NEKO_DEAD_SIGNAL-0.0.28-LyraVoss-20Anims-debug.apk`](https://drive.google.com/file/d/1el4CVTNG18bg08sdkrE1Q7eDPBJNuxcr/view), stored in `Игра / Модели`.
- Repository structure CI on implementation commit: **PASS**.
- **Not yet verified:** actual user Android visual quality (pelvis/shorts skinning, feet, facial details, weapon alignment, frame rate), and all 20 animations individually visually reviewed; the automated Godot test loads 20 and exercises representative motion/playback. Existing reports of severe skinning defects in older Meshy variants must remain open until actual mobile inspection of this newer GLB.

**Last successful functional commit:** `229053265e9fd00d0881ba512ed32e74b523e94c`. **Production branch:** `feature/female-base-v3-production`, PR #39 (draft, not merged). **Next concrete step:** on-device acceptance of 3D menu Lyra, movement and all 20 manual clip previews; collect screenshot/log only if defects. Keep `main` and all gameplay save formats unchanged. 


## 2026-11-10 — Visual defect regression: Lyra ready stance and missing world models

**On-device screenshots from user:** menu shows Lyra frozen in the middle of a walk cycle (wide stride and raised foot); `surface_sector` 128x128 shows a cyan capsule labeled Lyra, despite the approved GLB being installed; RTS shows real Lyra plus adjacent green capsule. RTS green capsule verified in code as the **separate EscortUnit**, not a duplicate hero. Other screenshot: RTS heading still said REINA.

**Root causes, fixed without changing GLB or user saves:**
- `lyra_voss_animations.gd` sampled `Walking` at t=0.25 as fake neutral; actual glTF bone audit showed a ~0.6m moving stride. New `hold_ready_pose` combines standing lower-body frame from `Standing_Reload` t=0 with relaxed shoulders/arms from `Walking` t=0, preserving all 20 imported source tracks.
- Godot GLTF importer sanitizes `mixamorig:` names; normalized bone-index fallback now searches actual Skeleton3D names by suffix.
- `surface_sector.gd` and `world_zone.gd` previously mounted 3D only for human officer **Amina index 0**. Added shared `LYRA.mount(parent, 1.9)` for **Lyra index 3**; motion hooks use existing route state and `Walking`/stop; both zones suppress only their own old hero capsule. This also applies to `world_sector.gd` through its inherited `world_zone.gd` base implementation.
- RTS keeps the green **EscortUnit** capsule as its legitimate second troop, now explicitly labeled `ЭСКОРТ · ЗАГЛУШКА` so it is not mistaken for Lyra. Hero capsule itself is tested hidden. RTS title and orbital menu footer were updated to NEKO naming.
- No sniper skill values, combat result conditions, enemy AI, navigation, profile storage, or other officers were changed.

**Verification sequence:** 
- Code commits `3c827fbb` (rig/stance/all scene fixes), `0ef06a73` (new real Godot tests for neutral stance, skeletal foot separation, WorldZone, Surface128, RTS capsule visibility and route animations), `202811df` (imported Godot bone-name matching).
- The initial expanded Godot test failed with `LYRA_RIG_TEST_FAIL Missing rig foot bones`: root cause confirmed as imported Skeleton3D bone naming; corrected rather than bypassed.
- [GitHub Actions run **42795094370**](https://github.com/Ncorror/neko-dead-signal/actions/runs/42795094370) **SUCCESS**. Exact 40MB original GLB downloaded+SHA verified; Godot imported without errors; expanded Lyra 3D cross-scene test and all existing RTS/world/128x128 tests PASS; Android ARM64 APK exported, signed, uploaded as GitHub Actions artifact `neko-dead-signal-debug-120`.
- APK `NEKO_DEAD_SIGNAL-0.0.28-LyraVoss-VisualFix-debug.apk`, 66,972,633 bytes, SHA256 `b6a6d339bdf84f1e32f363d445e0a847d232631fede8e369f7f4b1c2dcd78a97`. APK ZIP integrity: PASS. File delivered in ChatGPT conversation. **The optional attempt to copy that APK into Drive failed twice due to Files connector `container_session_expired`; do NOT claim this version is on Drive.** The prior 0.0.28 Lyra APK on Drive is the older buggy variant.
- The Model GLB on Drive is unchanged; no Meshy credits used.

**Known limits / acceptance:** New pose verified mechanically (feet placement), not visually on user's Android. The user must check face/arms/fabric deformation and post-pose shift with screenshots. Asset remains without a real `Idle`, sniper rifle model and proper rifle firing animation. Fixes stay on existing draft PR #39; main intentionally unchanged. 


## 2026-11-10 — user visual QA follow-up and standalone Lyra rifle

**New original user-supplied asset:** `Игра / Модели / Оружие / Meshy_AI_futuristic_sniper_rif_1110094339_texture.glb` ([Drive](https://drive.google.com/file/d/1Zna4PSUJka1NuxdghxuW1DI4C3fx4G1n/view)), SHA-256 `fa324f0e3fdd5fc9e3447146c0322bd8b5422098275ddf1fe51202897bede47e`, 8,373,476 bytes, one 9,922-triangle rigid textured mesh, no skeleton or animation; longest dimension 1.90 m. No regenerated weapon or wasted Meshy credits.

**User screenshots 2026-11-10 (APK 0.0.28):** bad mid-stride standing pose; on the 128×128 surface the avatar was still a capsule; on RTS a separate GREEN capsule appeared beside Lyra. In reviewed code the green capsule belongs to **EscortUnit**, not the rigged hero (now explicitly labeled `ЭСКОРТ · ЗАГЛУШКА`); previous screenshot represented an APK lacking the later surface model wiring. Do not delete the companion unit as a cosmetic fix.

**Corrections:** Replace mid-walk or multi-clip pose blending with the verified symmetric skeleton **rest pose** (`Skeleton3D.reset_bone_poses()`), validated from GLB source foot positions (left and right toes at approximately identical Z and Y). The rifle installs separately as a **back-mounted** `BoneAttachment3D` under Lyra's `Spine2`, available in the orbital preview, RTS and 128×128 / world scenes. This is a visual weapon only; because source clips contain no rifle fire pose it is NOT yet modeled as right-hand sniper firing and does not change gameplay damage or hit decisions. Add actual GLB import, weapon mount and stronger pose tests in CI.

**Next acceptance:** real Android screenshot of front/back menu and surface, plus all 20 clips under Animation Lab. Validate skinning (hips/shorts), weapon orientation, clipping and scale before merging PR.


### 2026-11-10 — Lyra rifle visual-fix Android delivery verified

- **Successful code commit:** `1d8447cf0c6a6f037e476cbf9a0ab687ab5fc33b` on existing draft PR #39; main was not modified.
- **CI source:** [Neko Dead Signal Android Debug run 42796543368](https://github.com/Ncorror/neko-dead-signal/actions/runs/42796543368): **PASS (52 successful steps)** including SHA-pinned downloads of 20-clip Lyra GLB + new user-made 8.37MB rifle GLB, Godot import, detailed rig/weapon/neutral-feet tests, existing 128×128 and world zone validations, RTS regressions, Android export and signing.
- **Packaged signed APK:** `NEKO_DEAD_SIGNAL-0.0.28-Lyra-Rifle-Fix.apk`, 74,772,175 bytes, SHA-256 `0412e40576b2cfc3131e63a9e76c34c714f3ffb75f93aa4b3ca2fde14c0dfd1e`; ZIP integrity PASS. APK contents explicitly include imported rifle mesh/textures, Lyra rig, both planet scenes and the animation lab.
- **Drive delivery verified:** [new Android APK](https://drive.google.com/file/d/1GZbnQ4NZ8maHMVdEaIlM8gxWOxD8J162/view) is stored in `Игра / Модели`, Google file ID `1GZbnQ4NZ8maHMVdEaIlM8gxWOxD8J162` with expected size; this does **not** replace older retained APKs.
- **Remaining visual validation required:** actual device screenshots before promising that rigging/skin mesh looks correct, rifle is oriented acceptably or that every animation is safe. The rifle is currently stowed on the back; no pretend rifle-in-hands firing pose or extra damage mechanics implemented.
- **Next step:** user tests the above exact APK on Android; inspect Lyra front/back, feet and hips/shorts, gun stow on orbital screen + planet + RTS, before PR merge or gameplay weapon-fire implementation.


## 2026-11-10 — повторный документальный и бинарный аудит после Lyra Rifle Fix

**Область:** код `client/scripts/lyra_voss_animations.gd`, `commander_3d_preview.gd`, `lyra_voss_animation_lab.gd`, `rts_character_fit.gd`, `operation.gd`, `rts_auto_fire.gd`, `surface_sector.gd`, `world_zone.gd`, `world_sector.gd`, `main.gd`, `combatant.gd`; `client/tests/test_lyra_voss_rig.gd`, `test_menu_layout.gd`; Android CI, approved GLB binaries and export APK. Read-only audit of code/assets; no gameplay features silently changed.

**Verified:** `1d8447cf` Android run [42796543368](https://github.com/Ncorror/neko-dead-signal/actions/runs/42796543368) PASS, 52 steps, exact approved SHA-pinned GLBs, signed 74,772,175-byte APK with ZIP integrity PASS. After this functional commit, journal-only commit `fdd60234` passed Repository structure CI. Original GLBs and player save formats unchanged; manual on-device visual approval of the NEW rifle build is still pending.

**Original GLB inventory, independently parsed from local raw files:** Lyra = 31,007 triangles, 49,156 vertices, 66-joint humanoid skeleton, 20 named clips, two 4096×4096 RGB textures, 40,074,004 bytes; rifle = 9,922 triangles, no rig, two 2048×2048 RGB textures, 8,373,476 bytes. Four influences per rigged vertex, all weight sums ~1.00 and all skin-joint indices valid. **This does not certify quality of individual skin weights or visual deformation.** Central hips/shorts vertex region is mainly weighted to both upper legs; strain must be inspected with actual motion.

### Priority P0 — gameplay/visual correctness

1. **No authored neutral Idle:** `hold_ready_pose()` stops `AnimationPlayer` and calls `Skeleton3D.reset_bone_poses()`. This eliminates the mid-stride foot offset but leaves the source A/rest pose (not a finished relaxed/sniper idle). Implement a true skeletal Idle/Combat Idle and smooth transitions, preserving original rig and 20 clips.
2. **Rifle is only back-mounted:** `attach_weapon()` uses `BoneAttachment3D` under `Spine2` with fixed scale 0.54 / rotation Z 68° and offset. It has no hand-grip IK, left-hand support, reload/aim/fire synchronization, muzzle marker or visibility changes from stowed to equipped. Existing `Archery_Shot_2` is a bow motion, not approved sniper fire. Check attachment clipping in front/back/side, then implement real rifle modes with dedicated suitable motions.
3. **Sniper class mechanics absent from RTS:** `LandingCombatant` defaults to `weapon_range=5.0`, `damage=12`, `reload_time=0.85`. `operation.gd` does not set Lyra-specific values; source canonical design v0.3 requires 16 base / active prepared-position 18, 5 active skills and one passive, proper aiming and LOS. `rts_auto_fire.try_fire` is called after movement and can fire while a unit is moving, conflicting with approved stationary sniper precision. Implement class profile and tests independently of visuals; keep other officers unchanged.
4. **Branch not mergeable into main yet:** GitHub PR #39 reported `mergeable=false`, `mergeable_state=dirty`; feature branch is 21 commits ahead and 2 behind main and changes shared RTS/UI/workflow files. Resolve divergence on existing branch, re-run CI, do not overwrite main or merge before Android visual acceptance.

### Priority P1 — mobile QA and UX

5. **Animation laboratory root motion:** Raw `mixamorig:Hips` tracks show `Roll_Dodge_1` translates ~4.52m, `Roll_Dodge_3` ~2.0m, `Roll_Dodge_4` ~3.12m, `Hit_in_Back_While_Running` ~3.36m, `Slow_Walk_Reload` ~3.05m, `walking_2` ~1.12m. `play_preview()` only plays clips and the camera stays fixed; model may leave the preview frame / slide or jump between clips. Reset and recenter preview or extract root motion from the visual character for playback; do not use these tracks directly for RTS navigation.
6. **Visual testing blind spots:** current Godot test verifies skeleton/clip counts, foot separation, model and gun node existence, scene wiring and game stats; it does not assert gun orientation/clipping, contact with hands, shorts deformation, actual pixel framing, animation completion/transition, material correctness or Android FPS. Add targeted screenshot/golden or camera-projection tests; perform physical device QA.
7. **Camera and UI:** `commander_3d_preview._frame_model()` computes bounds before dynamically attaching the rifle; consequently it does not frame the added weapon. `main.gd` puts four launch buttons in a right panel with minimum width 338 and `Button.clip_text` enabled; inspect Lyra lab label clipping on 1024×600 and user 2048×945 screen. RTS default zoom 22 leaves the hero small; check tactile zoom range versus scene composition. Keep touch scroll and existing controls.
8. **Mobile asset budget:** 31k+9.9k triangles for hero+gun, two 4K + two 2K textures. Measure Android GPU memory/frametime and skinning cost; create 2K/1K mobile import variants only after verifying quality (do not degrade master assets or overwrite Drive originals).
9. **PvE access and identity:** `main.gd::_enter_sector()` allows only human officer index 0 (Amina); `world_sector.gd` and `world_combat.gd` implement Amina-specific skills/names. The user can explore 128×128 as Lyra, but cannot play the current mob/boss PvE mission as Lyra. Adding class-aware PvE must come with Lyra's own abilities and character-specific save tests, not just an unlocked menu button.
10. **Build identification and distribution:** `client/project.godot` and `export_presets.cfg` still report version 0.0.28/code 28 across several substantially different test APKs. Bump the next test version/build code and expose Git commit/build run in diagnostics so screenshots/logs can identify precisely which variant is installed.

**Separate long-term project milestone, not a regression of Lyra rig:** the client still reports a *local session* and Android manifest export disables Internet; actual MMO match server and online authoritative gameplay remain unimplemented. This does not block present local visual QA but must not be misrepresented as a functioning MMO.

**Next practical implementation order:** (a) true neutral/sniper Idle + stable lab preview, (b) weapon fit/hand grip and synchronized rifle actions, (c) Lyra sniper RTS class profile and rules (no shooting on move), (d) multi-scene screenshots + device FPS/perf, (e) PvE class entry, build version and merge-conflict reconciliation. Do not regenerate the avatar or spend Meshy credits without a demonstrated asset defect.


## 2026-11-10 — Lyra sniper correction pass 0.0.30

**Functional head:** `dcd4564cd182550e39185342401461b4359d1abf` after a real merge with current `main` (`f08dd0f8`). Branch comparison is now **ahead, behind=0**. GitHub PR #39 raw status after the reconciliation: **mergeable=true, mergeable_state=clean**, still intentionally **draft** and not merged.

**Implemented corrections**
- Animation Lab now cancels horizontal Mixamo hips/root travel while previewing translated clips and recenters the model when returning to neutral. Imported source animation data is not rewritten.
- Orbital commander preview recomputes bounds after attaching Lyra's rifle so the camera accounts for the equipment.
- Lyra RTS base sniper range is now **16.0**. Approved Prepared Position extension to **18** remains a future active skill; it is not granted for free.
- Lyra contributes a **16.0** long-range scout sight source while ordinary escort/unit sight behavior remains unchanged.
- Lyra automatic fire is suppressed while a movement route is active; ordinary units retain their existing fire-on-the-move behavior. Once stationary, Lyra auto-fire works normally.
- Repository test contract no longer hard-codes patch 0.0.29; it verifies consistent `0.0.N` project/export/workflow metadata and build code.
- Android workflow now watches `scripts/**`, because those tests are executed by that workflow.
- Synced the feature branch with current 0.0.29 `main` and bumped this tester build to **0.0.30 / code 30** to make it distinguishable from earlier 0.0.28/0.0.29 APKs.

**Verification**
- First enhanced run exposed and rejected a real Godot parser bug in `lyra_voss_animation_lab.gd`; fixed at `a89d487a` rather than weakening the regression.
- Pre-merge full run [42803599548](https://github.com/Ncorror/neko-dead-signal/actions/runs/42803599548): **PASS 52/52**.
- Final post-merge/version full run [42804486477](https://github.com/Ncorror/neko-dead-signal/actions/runs/42804486477) at `dcd4564cd`: **PASS 52/52**, including the strengthened Lyra rig/lab/multi-scene test and the sniper-specific auto-fire test.
- Repository structure CI for the same head: **PASS**.
- Tester APK extracted from artifact `neko-dead-signal-debug-133`: `NEKO_DEAD_SIGNAL-0.0.30-Lyra-Sniper-Fix.apk`, **74,776,271 bytes**, SHA-256 `5dac4bf1e466d9fe8d679c0cd8b03e16f2772a638f8b9bdbe075b0ca88f6fdbe`; APK ZIP integrity **PASS**. Package contents include imported `rigged.glb`, `sniper_rifle.glb`, their textures, Lyra scripts and Animation Lab scene.
- Drive delivery verified: [NEKO_DEAD_SIGNAL-0.0.30-Lyra-Sniper-Fix.apk](https://drive.google.com/file/d/1bguNOmr1d2_Jfo-GELSLV5mA-W8XwvND/view), Google file ID `1bguNOmr1d2_Jfo-GELSLV5mA-W8XwvND`, expected size **74,776,271 bytes**.

**Still intentionally open — requires visual/gameplay work, not a green-check claim**
- Current neutral state is a symmetric skeleton **rest pose**, not an authored breathing/combat Idle. It fixes the previous mid-stride freeze but still needs user visual acceptance before we author further bone posture.
- Rifle is stowed on the back only. No approved two-hand rifle grip, sniper aim, recoil, muzzle anchor or rifle-specific reload/fire animation exists yet. Do not substitute bow clips.
- Prepared Position (16→18), aimed shot and the rest of Lyra's approved 5+1 class skills are not implemented in this correction pass.
- Existing mob/boss PvE slice remains Amina-specific; Lyra-specific PvE requires her own skill profile rather than simply unlocking Amina's UI.
- Real Android screenshots/FPS remain required for hips/shorts skinning, rifle clipping/orientation, animation appearance and mobile texture budget. Do not merge PR #39 until this device acceptance.


## 2026-11-10 — device regression 0.0.30 → corrected 0.0.31

**User device evidence from 0.0.30:** Lyra stopped in imported A-pose / arms spread; rifle appeared detached/floating around shoulder/back; user could not find the earlier mobs+boss PvE location from the 128×128 exploration flow; prototype shot visual still read as a beam. These are accepted regressions, not tester error.

**Root causes found**
- Replacing the bad mid-stride freeze with pure skeleton rest created the visible A-pose. A later procedural arm rotation attempt also failed the strengthened Godot test (`Relaxed pose still looks like imported A-pose`) and was rejected by CI.
- Rifle transform had been authored directly in Spine2 local axes. Mixamo Spine2 has a rotated local basis, so apparently reasonable XYZ offsets did not correspond to model-space back placement. Meshy rifle source pivot also needed geometric centering.
- Rust Road PvE still existed, but access/profile/UI was Amina-centric in several places and was not visible from the 128×128 surface route in the installed tester build.
- Beam-looking prototype used elongated geometry; replaced with a compact moving projectile point in RTS and world PvE.

**0.0.31 corrections**
- Natural standing state samples `Walking` at **0.017 s** (verified from the raw GLB: hands are down/near torso) and resets hips + both complete leg chains to rest, keeping feet level while removing the A-pose upper-body silhouette. No fake `Idle` clip is added and the original 20 animations are untouched.
- Rifle carrier is centered from measured weapon geometry, desired stowed transform authored in skeleton/model coordinates, then converted through `Spine2.get_bone_global_rest().affine_inverse()`. Stowed centre target: approximately `(0.06, 0.96, -0.22)`, visible length ≈0.95 m.
- 128×128 top HUD now has explicit **«МОБЫ И БОСС»** entry for Amina/Lyra, checkpointing before transfer to `world_sector.tscn`.
- Rust Road uses Lyra profile: real Lyra rig, weapon range 16, mobs/boss visible, Amina-only skill buttons hidden rather than leaked onto Lyra.
- Shot rendering in both RTS and PvE is a compact moving 0.10 m projectile, not a full-length line/beam.
- Test version bumped to **0.0.31 / code 31**.

**Verification**
- Several intermediate runs were intentionally red and blocked: one caught the still-A-pose procedural fix; one caught a typed `find_skeleton(AnimationPlayer)` mismatch after weapon refactor; structural contract caught obsolete pose assumptions. Each cause was fixed rather than bypassed.
- Final functional head: `91969dbd78d4e9b328fff574cbb32055735bc5c6`.
- Final Android run [42808634722](https://github.com/Ncorror/neko-dead-signal/actions/runs/42808634722): **PASS 52/52**, including imported GLBs, natural-ready arm-spread/feet tests, rifle placement bounds, surface PvE entry, Lyra Rust Road profile with 9 actors including boss, existing RTS and world regressions, Android export/signing.
- APK: `NEKO_DEAD_SIGNAL-0.0.31-Lyra-Combat-Fix.apk`, 74,776,271 bytes, SHA-256 `f4e7637255e3b2469d61b0611d887345d833977e830546cdfbeb6bf26370efa3`, ZIP integrity PASS.
- Drive: [0.0.31 tester APK](https://drive.google.com/file/d/1akbUTFcH8ilWdNoGWvqrrFn8-kn3bLVv/view), file ID `1akbUTFcH8ilWdNoGWvqrrFn8-kn3bLVv`.

**Still requires actual Android visual acceptance:** exact attractiveness of the sampled neutral stance, rifle clipping/orientation from front/back/side, skinning around shorts/hips during all animations, projectile readability at real FPS. Do not merge PR #39 until those screenshots are checked.


## 2026-11-10 — device regression correction 0.0.31

User device screenshots of 0.0.30 exposed four visual/gameplay regressions that automated structural checks had not proven: imported A-pose used as idle, rifle visibly displaced around the shoulder/back, Rust Road mobs/boss not reachable while Lyra was selected (including from Sector 01 128×128), and the temporary shot effect rendering as a continuous laser-like box.

**Corrected in functional head `91969dbd78d4e9b328fff574cbb32055735bc5c6`:**
- Standing pose now samples the verified `Walking` clip at 0.017 s for a naturally lowered upper body, pauses it, and resets Hips plus both complete leg chains to rest. Test rejects excessive hand spread so raw A-pose cannot silently return.
- Rifle is mounted through Spine2 using an authored skeleton-space transform; its GLB geometry is additionally re-centered inside a carrier so an arbitrary Meshy source pivot cannot move the visible gun. Test verifies stowed position against the back.
- Rust Road PvE is available to Lyra from the ship/world flow and directly from Sector 01 128×128. Lyra's world PvE profile uses range 16; Amina's five skill buttons are hidden rather than falsely assigned to Lyra.
- Continuous beam boxes were replaced in both RTS and world PvE with short moving projectile dots. Damage remains simulation-driven; visual projectile does not change hit timing.
- Build bumped to **0.0.31 / code 31**.

**Verification:** Android workflow run [42808634722](https://github.com/Ncorror/neko-dead-signal/actions/runs/42808634722) passed **52/52** at `91969dbd`; PR #39 remains clean/mergeable and draft. Tester APK `NEKO_DEAD_SIGNAL-0.0.31-Lyra-Fixes.apk` is **74,776,271 bytes**, SHA-256 `f4e7637255e3b2469d61b0611d887345d833977e830546cdfbeb6bf26370efa3`, ZIP integrity PASS. Drive: https://drive.google.com/file/d/1wha0a9GgRwmZqu-Yplb_vGzFMmPmabsy/view

**Still open for device acceptance:** exact visual quality of the sampled standing pose, rifle clipping from front/back/side, projectile readability at RTS zoom, and hips/shorts deformation while walking/running. Do not merge PR #39 until these are visually accepted on Android.
