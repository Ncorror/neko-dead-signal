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
