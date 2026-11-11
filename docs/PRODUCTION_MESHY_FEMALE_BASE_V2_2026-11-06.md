> **АРХИВ:** female_base_v2 заменена утверждённой v3; не использовать этот пакет как исходник для новой генерации Meshy Pro. [Актуальная female_base_v3](PRODUCTION_FEMALE_BASE_V3_APPROVED_2026-11-06.md).

# NEKO: DEAD SIGNAL — HUMAN FEMALE BASE v2 · актуальный Meshy Pro production-пакет

> **СТАТУС: АРХИВ v2.** Более качественный согласованный образ **v3 утверждён 2026-11-06** и теперь является единственным производственным источником. [Production v3](PRODUCTION_FEMALE_BASE_V3_APPROVED_2026-11-06.md) и [Drive v3](https://drive.google.com/drive/folders/1EKHGcaXvoEKTyNs97xUw9mUvk395MOfd). Этот документ оставить для истории, не генерировать по ссылкам v2. [Решение по Meshy vs Tripo](AI_3D_MESHY_VS_TRIPO_DECISION_2026-11-06.md).

**Дата: 2026-11-06. Статус: УТВЕРЖДЁННЫЙ ВИЗУАЛЬНЫЙ КАНОН, 2D READY, GLB НЕ СОЗДАН.**
Версия v2 полностью заменяет v1 для всех новых производственных работ. v1 сохранена в отдельном архиве; не удалять без решения. Это нейтральная база для пользовательских MMO-аватаров, а не отдельная сюжетная героиня.

## Утверждённый облик v2

- Оригинальная **молодая взрослая** аниме-героиня (18+) с более мягким и милым лицом, чем v1; крупные фиолетовые глаза, короткое серебристо-сиреневое каре и розовые X-образные заколки.
- Стройное естественное спортивное телосложение, без chibi, гипертрофированной анатомии, фотореализма или сексуализированной позы. Общий стиль четырёх действующих героинь: выразительное anime-лицо, сдержанные sci-fi-детали, тёмно-неоновая гамма, кото-символика.
- Нейтральная техническая одежда **непрозрачные графитовые спортивный топ и короткие плавки-шорты**, розовая окантовка, небольшие кото-значки. Это временная база для дальнейшей экипировки; оружия, брони, юбки, плаща и аксессуаров нет.
- **A-pose**, ступни босые, студийный нейтральный фон. Костюмы и броня должны появляться **позднее** как отдельные модульные элементы на одном согласованном скелете.

## Где лежит весь новый комплект

**Google Drive → Игра → [REINA_Female_Base_v2_Meshy_Pro](https://drive.google.com/drive/folders/15-CCXvQxuXAZwlsJiABxtSO0Qmsg1tpU)**

| Файл | Назначение |
|---|---|
| [01_front.png](https://drive.google.com/file/d/1FvtcFJ9fosPT5PLUyND5cNx2OQWmCqxP/view) | **Основной вход в Meshy** |
| [02_right.png](https://drive.google.com/file/d/1zPIe8aIB_pYbMILAd3_gcN8GgYbZ7zkS/view) | Правый профиль |
| [03_back.png](https://drive.google.com/file/d/1m3TbKUw5XIPsYPJDKb72iLAP3hFFyGFi/view) | Вид со спины |
| [04_left_mirrored.png](https://drive.google.com/file/d/1UuXprOUXl2JaeJ8HyhWEOHJgQFI42cdi/view) | **Левый профиль — ЗЕРКАЛЬНЫЙ, предварительный** |
| [00_turnaround_master.png](https://drive.google.com/file/d/1xbkCdLo6QN7Ib2SO7fS556Y1CNyWYOiU/view) | Оригинальный общий лист, **НЕ загружать как один вход Meshy** |
| [REINA_Female_Base_V2_Meshy_Refs.zip](https://drive.google.com/file/d/1Eae53YsJodJgEkkgBJ6YNscY5EO_0Xz5/view) | ZIP с кадрами, README и манифестом |
| [contact_sheet.jpg](https://drive.google.com/file/d/1wqjbBa1xnkNMrHEQLRhLzb8dcClc-o2j/view) | Сводка для визуальной проверки |

**Проверено:** в папке v2 девять файлов. Шесть прежних v1-файлов перенесены, а не удалены: [Игра / _Архив_Female_Base_v1_2026-11-06](https://drive.google.com/drive/folders/1ZTpHx7OWYbRULzbCCi8S6sgrx7gYZoZ1).

**Разрешение:** мастер-лист 1774 × 887 пикселей. Четыре панели обрезаны по фигурам и увеличены до 1024 × 2048 каждая, без искусственного дорисовывания деталей. Увеличение разрешения не улучшает настоящую детализацию исходника.

**ОГРАНИЧЕНИЕ 3D-КАЧЕСТВА:** генератор нарисовал оба профиля направленными вправо, поэтому левый профиль отражён. Он может неправильно передавать расположение заколки, асимметрию волос и геометрию плеч. Предпочтительно использовать функцию Meshy Pro **Generate Multi-View из фронтального PNG** и проверить боковые виды заново. Независимая геометрическая согласованность четырёх 2D-видов не доказана.

## Рабочий запуск в Meshy Pro

1. После фактической активации Pro скачать ZIP, извлечь PNG; открыть **Meshy 7 → Image to 3D**.
2. В качестве основного референса загрузить **01_front.png**. Сначала получить согласованные виды через **Generate Multi-View**, если функция доступна; сравнить с 02/03/04. Не добавлять мастер-коллаж одной картинкой.
3. В настройках **Pose Control → A Pose** (при наличии), затем запустить **одну** генерацию. Проверить лицо, пропорции, пальцы, волосы, плечи, локти, колени, стопы, одежду и спину при вращении на 360°.
4. Только после приёмки меша скачать **GLB** и запустить Auto Rigging / idle и walk. Проверить скиннинг без провалов и разрывов. Сохранить исходники и условия лицензии.
5. В Godot 4.x импортировать GLB в **новую** папку assets/character_creator/human_female/v2/, проверить превью и анимации на Android. Не менять работающий preview.glb Амины и файлы старого RTS-сохранения.
6. После этого под один канонический Skeleton3D создавать модульные волосы, скины, костюмы и броню. **Meshy не обеспечивает автоматически** общую топологию, blend shapes или совпадение скелетов при отдельных генерациях.

**Промпт** (только при наличии поля для текста в выбранном режиме):

~~~text
ONE original ADULT young woman (18+) in a refined anime science-fiction style compatible with NEKO: DEAD SIGNAL. Preserve exactly the attached visual reference: youthful but adult gentle anime face, large violet eyes, short silver-lilac bob hairstyle, small magenta X hair clip, light skin, slender naturally athletic proportions. Neutral clean A-pose, separate arms and hands, five distinct fingers on each hand, legs slightly apart, full body. Opaque matte graphite sporty fitted crop training top and matching short athletic swim-shorts, restrained magenta seams and subtle small cat insignia. No armor, no weapon, no boots, no coat, no props, no background objects, no exaggerated anatomy, no changes to hair or clothing. Consistent appearance from front, profile and back, suitable for subsequent humanoid rigging and modular equipment, stable clean game-friendly mesh and anime shading.
~~~

Если текстового поля в Meshy нет, просто загружать PNG. Промпт сам по себе не создаёт правильный скелет, полноценную модульность и blend shapes.

## Границы завершённой работы

- **Сделано:** v2 утверждена пользователем; 4 PNG; master; ZIP; README, manifest; папка Drive; старые файлы архивированы; визуальный QA четырёх картинок.
- **Не сделано:** реальный GLB, генерация/списание кредитов Meshy, исправленный независимый левый профиль, риг, анимации и проверка Godot.
- **Решение:** во всех активных планах v2 — единственная актуальная женская база; v1 — только архив и источник истории.

См. [архитектуру персонажей](CHARACTER_CREATOR_ANIME_MMO_PLAN_2026-11-06.md), [устаревший план v1](PRODUCTION_MESHY_FEMALE_BASE_V1_2026-11-06.md), [канон MMORPG](DEAD_SIGNAL_EARTH_GDD_v0.4.md).


## Первый результат Meshy 7.1 · скриншоты пользователя от 2026-11-06 (визуальная проверка)

**Источник:** три скриншота из Chrome / Meshy Workspace: front / side / back. Пользователь показал **сформированную цветную 3D-модель** в правом списке истории, выделенную зелёной рамкой. **GLB и риг не получены, качество в Godot не тестировалось.**

**Визуальная оценка:** близкий v2 anime-образ, короткое серебристое каре, розовые X-заколки, глаза, чёрный спортивный комплект с кото-знаком; в целом A-pose. На доступных скриншотах нет очевидного крупного отрыва конечностей, но требуется отдельно проверить пальцы/суставы/внутренние поверхности/одежду с увеличением и в анимации. Точная идентичность с 2D-референсом не измерена.

**Критическая проблема оптимизации:** Meshy отображает **470 732 треугольника и 260 890 вершин**, `Triangle` topology, `Meshy 7.1 Flagship` и 2K-текстуру; это **исходник высокой плотности**, не годный как финальный тиражируемый MMO-аватар под Android. Начальный целевой **QA-бюджет** для одной игровой героини: **10–20 тыс. треугольников** на максимальном близком LOD, затем **3–5 тыс.** при типичной игровой дистанции, и ещё легче для дальнего LOD — **предварительные инженерные цели, не измеренные пределы устройства**. Если в сцене много юнитов, нужно рассмотреть ещё более низкий бюджет. Официальная справка Meshy для mobile hero рекомендует консервативно 1–3 тыс. треугольников; фактический баланс установить профилированием в Godot/Android: https://help.meshy.ai/en/articles/15723950-how-to-make-meshy-models-game-ready .

**Следующее действие БЕЗ новой генерации:** сохранить текущую модель в **GLB** как high-poly master (цвет и текстуры внутри GLB), затем применить к копии **Remesh → Quad** и уменьшить число полигонов (не перезаписывать мастер). Meshy сохраняет оригинал и создаёт отдельную retopo-модель. На новой версии проверить силуэт, лицо и плечи; затем Auto Rigging (humanoid) и idle/walk; сохранить GLB с анимациями. Официально: https://help.meshy.ai/en/articles/9992029-how-to-download-a-quad-mesh-model ; https://help.meshy.ai/en/articles/15724161-how-to-export-meshy-models-with-colors-and-textures ; https://help.meshy.ai/en/articles/16231707-how-to-create-3d-animation-with-auto-rigging .

**Проверка лицензии и тарифа:** на скриншоте видно `CC BY 4.0`, короны Pro на Multi-View и Pose Control, а также предложение «Улучшить». Это **не подтверждает активность Pro**: проверить аккаунт и права коммерческого использования до включения модели в релиз. Не менять эту лицензию в архивных метаданных. При коммерческом использовании CC BY 4.0 обеспечить требуемую атрибуцию, если она применима.

**Статус после осмотра:** первая 3D-генерация на сайте существует визуально; исходный GLB ещё не загружен в Drive/GitHub; нет доказанного рига и Android-совместимости. Не запускать повторную генерацию, пока не проверены экспорт и remesh существующего кандидата.
