# NEKO: DEAD SIGNAL RTS — решение по движку и Meshy

> **Исследование 2026-11-01, некоторые оценки устарели.** Для выбранной pure RTS-концепции и текущего бюджета героев использовать [GDD v0.2](DEAD_SIGNAL_EARTH_GDD_v0.4.md), [матрицу анимаций](ANIMATION_REQUIREMENTS_RTS.md) и [актуальный 3D-пайплайн](MESHY_PIPELINE.md).

**Дата исследования:** 2026-11-01  
**Статус:** техническая рекомендация для нового приватного репозитория; тесты игрового ассета на Android ещё не проведены.

## Решение

- **Клиент / игровая сцена:** Godot 4.x, зафиксированная проверенная версия редактора и шаблонов в CI.
- **Скрипты первой версии:** GDScript; замеренные узкие места в перспективе переносить в C++/GDExtension, только после профилирования.
- **3D:** настоящие низкополигональные 3D-объекты, изометрическая/свободная камера (2.5D подача).
- **Рендерер:** сначала Compatibility (соответствует заготовке проекта), отдельно измерить Mobile/Vulkan на целевых телефонах; Forward+ не целевой для Android.
- **Сервер первой сетевой версии:** Godot dedicated/headless как тестовый матч-сервер, серверная проверка результатов. Метасервер и БД отделяются по мере появления постоянного мира. Не выводить вместимость сервера из номинальных характеристик VPS.
- **Модели/анимации:** Meshy → Remesh/UV/PBR → Rig → Animate → export **GLB** → Godot; хранить экспорт и метаданные права/версии.
- **Старый проект:** не изменять без согласования.

## Сравнение

| Движок | Сильные стороны | Ограничения в нашей ситуации |
|---|---|---|
| Godot 4.x | Android-редактор, Linux CLI/CI, glTF/GLB, headless-сервер, MIT | Большие RTS-поля, движение групп, анимация толпы — оптимизировать вручную |
| Unity 6 | Большая экосистема RTS/3D, Jobs/Burst/ECS и развитый профайлер | Редактор официально не работает на Android; x64 Linux редактор рекомендовано 8 ГБ RAM; новый тяжёлый пайплайн |
| Unreal Engine 5 | Продвинутый 3D и большой инструментарий | ПК/рабочая станция, высокие системные требования, чрезмерная цена сложности для небольшой мобильной команды |
| Defold | Лёгкая кроссплатформенная разработка, Lua, бесплатный | Редактор Windows/Linux/macOS, нет Android-редактора; меньшая практическая выгода при существующем Godot |

## Процесс создания героя в Meshy

1. Подготовить оригинальный дизайн героини/героя. Сначала один эталонный персонаж каждой расы; рисунки других игр не использовать как копируемый оригинал.
2. Сгенерировать **полнофигурную T-pose или A-pose** с хорошо отделёнными руками; проверить пропорции, ладони, обувь и оружие отдельно.
3. Через **Remesh** снизить плотность модели; ориентир для первого теста 3–5 тыс. треугольников для рядового бойца, 5–10 тыс. для крупноплановой героини (только предварительный бюджет, проверять по измерениям). Для статических пропсов ~0.5–2 тыс. треугольников как отправная точка.
4. Проверить UV и PBR-текстуры. Стартовать с 512–1024 px для массового реквизита/юнитов и до 2K только для героев, когда реально требуется.
5. Rig как Humanoid, использовать устойчивый шаблон костей, предпочтительно совместимый с Mixamo; вручную проверить положение суставов.
6. В Animate добавить Idle, Walk, Run и боевую анимацию, а затем дополнительные движения. Библиотека Meshy — более 600 пресетов, есть Text to Motion (может расходовать кредиты).
7. Download > **GLB** > Animation **All Added** (а не Current). Убедиться, что анимации и скелет присутствуют в файле.
8. Импортировать GLB в Godot, проверить скелет, материалы, положение корня и каждый клип. При необходимости настроить `SkeletonProfileHumanoid`, BoneMap и ретаргетинг.
9. Создать в Godot AnimationTree / AnimationPlayer (State Machine): idle ↔ walk ↔ run ↔ attack ↔ death. Не рассчитывать, что Meshy автоматически наладит переходы и взаимодействие с игровой логикой.
10. Технику (танки, гусеницы, башни, дроны, шарниры, отдача орудий) анимировать игровым кодом/узлами Godot; авто-анимацию Meshy считать вспомогательной, не обязательной.

**Одежда и кастомизация:** отдельно определяем базовый скелет на каждую типовую фигуру; сменные части одежды и экипировки подключаем как совместимые меши/attachments. Не регенерировать и не перериггивать с нуля каждое платье, иначе анимации разойдутся.

## Технические риски

- Meshy часто выдаёт избыточную геометрию: проверять треугольники, число материалов, размеры текстур и число костей, LOD.
- Для сотен персонажей невозможно рассчитывать только на отдельный `AnimationTree` и `NavigationAgent` для каждого без измерений. Понадобятся общие оптимизированные системы движения, обновление пути с интервалом, анимационные LOD и инстансинг для подходящих объектов.
- На 2 vCPU / 4 GB запускать 1 тестовую серверную сессию с замером CPU/RAM, а не обещать вместимость MMO без бенчмарков.
- Сервер — источник истины для видимости тумана войны, передвижения, попаданий, контейнеров, производства и наград. Клиент не отправляет «я нашёл 1000 ресурсов».
- Meshy Free: коммерческое использование возможно по CC BY 4.0 с атрибуцией; платные приватные генерации имеют иные права. Сохранять сведения о тарифе на момент создания каждого ассета и правомерности исходных изображений.

## Первый верифицируемый тест

**Цель:** убедиться, что Meshy → GLB → Godot → Android реально работает на нашем железе.

1. Создать оригинальную девушку-командира в Meshy в T-pose, ремеш ~5K, 4 клипа.
2. Сделать GLB с `All Added`, сохранить метаданные генерации и права.
3. Через Runner выполнить импорт проекта Godot без GUI и проверить логи.
4. Открыть 3D-сцену с одной героиней, затем с 20/50/100 упрощёнными юнитами (с изменяемым количеством).
5. Запустить Android APK; снять FPS, frame time p95/p99, потребление памяти, стабильность и температуру/троттлинг, проверить 4 клипа.
6. Сравнить Compatibility и Mobile/Vulkan на целевых телефонах, фиксируя модель устройства/версию драйвера.
7. Только после теста зафиксировать бюджеты ассетов и наращивать контент.

## Источники (официальные)

- Godot Android editor: https://docs.godotengine.org/en/4.7/tutorials/editor/using_the_android_editor.html
- Godot available 3D formats: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- Godot rendering backends: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot MultiMesh performance: https://docs.godotengine.org/en/4.6/tutorials/performance/using_multimesh.html
- Godot navigation optimization: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_optimizing_performance.html
- Godot dedicated servers: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
- Godot multiplayer security: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Godot animation retarget: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Godot MIT license: https://godotengine.org/license/
- Meshy game assets: https://docs.meshy.ai/en/webapp/guides/use-cases/game-assets
- Meshy remesh: https://docs.meshy.ai/en/webapp/guides/3d-model/remesh
- Meshy rigging: https://docs.meshy.ai/en/webapp/guides/3d-model/rigging
- Meshy animate: https://docs.meshy.ai/en/webapp/guides/animate
- Meshy licensing: https://help.meshy.ai/en/articles/10137554-what-is-the-ownership-of-the-generated-models
- Unity system requirements: https://docs.unity.com/en-us/engine/6000.0/manual/get-started/install-and-upgrade/getting-started-installing-unity/system-requirements
- Unity Personal eligibility: https://unity.com/products
- Unreal licensing: https://www.unrealengine.com/license
- Unreal system requirements: https://www.unrealengine.com/download