# NEKO: DEAD SIGNAL — PRODUCTION: женская модульная аниме-база v1 (Meshy → Godot)

> **Актуальный эталон: v3.** v1 и v2 — только архивы. [Последние утверждённые четыре PNG, инструкции, Drive, SHA-256](PRODUCTION_FEMALE_BASE_V3_APPROVED_2026-11-06.md).

> **АРХИВ / УСТАРЕЛО 2026-11-06:** пользователь утвердил новый более юный (взрослый) аниме-облик **human_female_base_v2**. **Для новой генерации Meshy использовать только [утверждённый production-пакет v2](PRODUCTION_MESHY_FEMALE_BASE_V2_2026-11-06.md) и его [Google Drive](https://drive.google.com/drive/folders/15-CCXvQxuXAZwlsJiABxtSO0Qmsg1tpU).** Файлы v1 перенесены в [архив Drive](https://drive.google.com/drive/folders/1ZTpHx7OWYbRULzbCCi8S6sgrx7gYZoZ1); ссылки ниже на v1 сохранены исключительно как исторические и не являются действующими инструкциями. Ниже — старое ТЗ.

**Дата:** 2026-11-06 · **Статус:** рабочее техническое задание и последовательность производства. **Это не готовая GLB-модель, не реализованный редактор, не результаты теста.**

**Постановка:** первая женская модель для пользовательского MMO-конструктора, в едином аниме-стиле Рэйны, Амины, Миры Кейд и Лиры Восс. **Одежда на исходной модели минимальная и нейтральная: непрозрачный облегающий спортивный топ + спортивные плавки-шорты с высокой посадкой; запасной вариант — цельный непрозрачный спортивный купальник.** Это технический слой под будущие костюмы и броню, а не финальный наряд персонажа. Только **взрослая** героиня, без сексуализированной позы.

Связанные документы: [редактор персонажа](CHARACTER_CREATOR_ANIME_MMO_PLAN_2026-11-06.md), [командиры](../assets/art/commanders-v1/README.md), [канон мира](DEAD_SIGNAL_EARTH_GDD_v0.4.md). Исходные коллажи четырёх героинь: Google Диск → [папка «Игра»](https://drive.google.com/drive/folders/1nbYMKjf3j6d9ThvTnw8Z7l4PObFtjJU2) → `девочки.zip`. Ранее сделанный [лист базовой женской модели](https://drive.google.com/drive/folders/1nbYMKjf3j6d9ThvTnw8Z7l4PObFtjJU2) можно использовать **только как арт-ориентир**, а **не целиком как изображение для Image to 3D**: коллаж содержит портрет, несколько ракурсов и много подписей.

## 0. Важнейшая договорённость по модельному производству

**Meshy генерирует исходную 3D-геометрию, но не гарантирует совпадающий риг, UV, blend shapes или сменные модульные костюмы из нескольких независимых генераций.** Совместимость — отдельная работа по ретопологии/скиннингу/подгонке. Нельзя обещать, что 5 отдельно сгенерированных костюмов сами сядут на тело.

**Принцип:** одна утверждённая базовая модель + один канонический `Skeleton3D` на человеческий женский тип тела. Сменные вещи создаются/подгоняются **под эту конкретную модель**, наследуют её масштаб и скелет. Не регенерировать базу после утверждения, иначе совместимость исчезнет.

**Анатомия/силуэт:** стилизованный аниме-силуэт без чиби и фотореализма, ориентир около 7.5–8 голов высоты (должен визуально сочетаться с уже утверждёнными арт-листами). Две отдельные ноги; руки в A-позе отходят от туловища ~30–45°, кисти не касаются бёдер; пальцы читаемые, не сросшиеся. Нейтральный тон кожи и причёска, без узнаваемых деталей конкретной героини. Бюджет первых моделей **условно** до 20–30 тыс. треугольников после оптимизации — цель профилирования, а не свойство гарантируемого вывода Meshy. Цветная текстура на начальном этапе до 1024–2048 px; затем на Android выбрать по реальным метрикам.

**Структура базы:** `Body` (mesh), `Skeleton3D`, `Training_Top`, `Training_Bottom`, `Hair_Placeholder` (достаточно отдельного простой шапки волос), `Materials`. Если Meshy выдаст всё слитым, понадобится ручная разборка и правка в DCC; не считать её модульной.

## 1. Где именно генерировать

- На телефоне открыть **https://www.meshy.ai/** → `Workspace` → `Image to 3D`.
- Для старта **не** Text-to-3D по длинному описанию и **не** загрузка полного многоэлементного коллажа; сначала готовим **одно чистое изображение персонажа спереди**, потом только при доступной функции добавляем side/back/right как отдельные одинаково оформленные изображения.
- После удачной модели использовать `Auto Rigging`, проверить движения и экспортировать в **GLB**.
- **Статус тарифа:** пользователь **выбрал Meshy Pro** (помесячно, покупка пока не подтверждена). По официальной таблице Pro — **$20/месяц, 1000 кредитов/месяц**, Multi-View и Pose Control (A/T) доступны после активации. Использовать **Meshy 7** для Multi-View (до 3 дополнительных ракурсов); Meshy 6/6 Lite эту опцию не поддерживают. Включать **A-Pose** в интерфейсе генерации; сам промпт/2D-референс также остаётся в A-позе. Multi-View и Smart Topology **нельзя включить одновременно** — при необходимости делать последующую ретопологию отдельным этапом. Официальные источники: https://help.meshy.ai/en/articles/12062933-which-meshy-plan-is-right-for-you-free-vs-pro-vs-premium-vs-ultra , https://help.meshy.ai/en/articles/10255659-how-to-generate-3d-models-with-a-pose-t-pose-or-custom-poses , https://help.meshy.ai/en/articles/12634481-how-to-use-multi-view .

## 2. Первое изображение для генерации — ОДИН персонаж, один ракурс

Подготовить **отдельный полноразмерный портрет в полный рост со строго прямой камерой**: персонаж занимает кадр от макушки до обуви/ступней, равномерный серый фон, мягкий студийный свет без сильных теней, нет рамок/текста/коллажных подписей/оружия/аксессуаров. **Спортивный топ и спортивные плавки-шорты непрозрачные, чёрно-графитовые без логотипов.** Поза A, руки свободны, ноги не соприкасаются. **Проверить, что внешность совпадает с общим художественным языком наших героинь**; это *новая* нейтральная модель, не конкретно Рэйна и не копия её комплекта.

**ПРОМПТ 2D-референса (скопировать в Meshy Text to Image / иной генератор изображений):**

```text
Full-body orthographic FRONT view of ONE original adult female anime sci-fi game character base for an isometric mobile MMORPG. Consistent refined anime face and proportions matching a dark neon cyberpunk sci-fi character cast: expressive eyes, modest natural facial features, around 7.5 to 8 heads tall, athletic but not exaggerated, slim-to-average healthy build, subtle neutral expression. Neutral short straight ash-gray hair tucked behind ears, no hair strands covering face or shoulders. Wearing ONLY a practical opaque matte charcoal sleeveless fitted sports training top and separate opaque high-waisted fitted athletic swim briefs / short training bottoms, with no logos and no armor; outfit is a neutral placeholder for a clothing customization system. Simple barefoot feet, fully visible. Clean symmetrical A-pose: both arms angled outward and downward about 35 degrees, hands and all fingers separate from torso and thighs, legs slightly apart, straight neutral spine, level shoulders, relaxed wrists. Front-facing straight-on camera at chest height, perfectly symmetrical composition, full body head-to-toe with padding around the silhouette. Soft neutral studio lighting, plain light gray background, subtle 3D-friendly anime shading. ONE character only, no second figures, no dramatic pose, no background scene, no props, no text, no UI, no collage, no cropping, no accessories, no floating objects, no long coat, no skirt, no bag, no weapons, no high heels, no exaggerated anatomy.
```

При сомнительном результате до 3D-генерации **исправлять 2D-референс**, а не тратить кредиты на повторный 3D без анализа.

**Под Meshy Pro / Meshy 7:** подготовить ещё 3 ОТДЕЛЬНЫХ изображения того же самого человека, в той же A-позе и одежде: `right_side`, `back`, `left_side`. Внешность, масштаб, освещение, положение рук/ног и задний фон должны совпадать. **Не передавать четыре картинки как один коллаж**. Если картинки не согласованы — сначала исправить референсы; в крайнем случае использовать только фронт и довести 3D вручную.

**ПРОМПТ для дополнительных видов (при необходимости менять только строку `VIEW`):**

```text
VIEW: LEFT PROFILE / RIGHT PROFILE / BACK. Exactly the SAME original adult anime sci-fi female character as the supplied front reference image. Same charcoal opaque sports training top and fitted high-waisted short briefs, same short ash-gray hair, identical proportions, colors and material. Neutral A-pose, shoulders level, arms 35 degrees from torso, separated fingers, legs slightly apart. Orthographic full-body studio turnaround view, plain light-gray background, no crop, same lighting, NO accessories, no text, no panels, no other characters. Preserve identity and outfit exactly; do not redesign.
```

## 3. Первая генерация 3D в Meshy

1. После активации Pro открыть **Meshy 7 → Image to 3D → Multi-View**. В основной слот загрузить **clean front.png**, а в три дополнительные — **right_side.png, back.png, left_side.png** того же человека. Если референсы пока не согласованы — начать с одного фронта, не расходовать кредиты на испорченную мультиракурсную генерацию.
2. Выбрать **Pose Control → A-Pose** (доступно в Pro), проверить статичность и разделение рук и ног на изображениях. Не считать тумблер гарантией готового рига — проверять после генерации.
3. В доступном поле `Prompt` / описания (если интерфейс его показывает) использовать ниже. **Если Image-to-3D не показывает текстовое поле, не искать несуществующую настройку — вводить промпт на этапе генерации референса.**
4. Начать с разумного предварительного качества, сравнить геометрию кистей, глаз, плеч, паха, коленей, стоп. **Не переходить в Auto Rigging, пока не устранены сросшиеся конечности и крупные дефекты.**
5. Доработать `Remesh / Retopology` только при необходимости; **разные режимы topology и Multi-View могут быть несовместимы в одном запуске**.
6. Сохранить **первый успешный рабочий экспорт GLB** под версией v1; отдельно сохранить исходные 2D PNG и запись настроек генерации/лицензии.

**ПРОМПТ ДЛЯ 3D/МАТЕРИАЛА (если в выбранном интерфейсе есть поле):**

```text
One original adult female stylized anime sci-fi game-ready humanoid, neutral A-pose for rigging. Single complete full-body mesh with correctly separated arms, legs, fingers and clean joints, symmetrical anatomy, no merged geometry. Calm anime face, realistic joint placement, 7.5-8 head proportions, short simple ash-gray hair. Tight opaque matte charcoal sports training top and separate opaque short athletic swim briefs; no external costume or accessories. Dark neon sci-fi anime art direction compatible with NEKO: DEAD SIGNAL. Clean solid PBR base colors, restrained surface detail, no exaggerated anatomy, no background props, no weapons, no logos, no cape, no floating objects. Suitable for later humanoid skeleton, skin weights and modular equipment in Godot. Do not add arbitrary separate objects.
```

Важно: текст `game-ready` в промпте **не гарантирует** риг, модульность, хорошие UV, low-poly, shape keys или готовую коммерческую модель.

## 4. Rigging и первый экспорт

- В Meshy: `Auto Rigging` только на чистой модели. Проверить `idle`, `walk`, `run` (сначала достаточно **idle+walk**), нет ли разрыва тела/прокола топа через грудь/бедро, поломанных коленей/локтей, рук внутри корпуса.
- Сохранять отдельные **`human_female_base_v1_source.glb`** (исходная статичная база, если доступна), **`human_female_base_v1_rigged.glb`**, **`human_female_base_v1_idle.glb`** / **`..._walk.glb`** только если такие раздельные экспорты доступны; иначе один экспорт с анимациями, не выдумывать разделение.
- Параллельно сохранить лист проверенных bone names/rest pose и единицы масштаба. В Godot 4 для переноса анимации между разными скелетами **одинаковых названий костей недостаточно**: нужна корректная BoneMap/Rest Pose и при необходимости ретаргет.
- Перед окончательной приемкой проверить условия лицензии конкретной модели и сохранённый источник происхождения.

## 5. Сборка в Godot без разрушения старого RTS

- Отдельная папка новых ресурсов `client/assets/character_creator/human_female/v1/` (не трогать `client/assets/characters/amina/preview.glb`).
- Новая сцена `character_creator.tscn` на базе логики `client/scripts/commander_3d_preview.gd` — уже поддерживает SubViewport, вращение касанием и auto-fit.
- **Границы фичи:** текущая `GameState` хранит выбор из фиксированных офицеров, `world_progress.gd` строго валидирует фиксированные ID. Не подменять старыми индексами новые кастомные UUID, не перезаписывать `user://world/progress-v1.json` без отдельной миграции.
- Для модульности: один основной `Skeleton3D`; волосы как отдельный MeshInstance3D на точке головы либо как skin; костюмы — подготовленные skinned meshes на **том же скелете**; скрывать ненужные полигоны тела под одеждой, чтобы исключить clipping; фиксировать bone bind/скелет и rest pose.
- Простой JSON-профиль с `appearance_version=1`, `body_base_id=human_female_v1`, `hair_id`, `eyes_color`, `skin_id`, `top_id`, `bottom_id`. Это **новое локальное сохранение**, позднее серверное.
- Начальный функциональный тест: одна модель, **две причёски**, два цвета глаз и **одна** сменная куртка/броня. Если сменная одежда не работает на анимированном персонаже, **не расширять каталог**.

## 6. Последующие ассеты после одобрения первой базы

1. **Волосы v1:** минимум 2 причёски (короткое каре и удлинённые волосы), затем длинная как у героинь, хвостики и вариации; менять цвет через материал, не генерировать отдельный GLB на каждый оттенок.
2. **Одежда v1:** нейтральная облегающая база остаётся под `Outfit_Light` и `Outfit_Tactical`. Сменная одежда должна подходить к **той же конкретной базе и ригу**.
3. **Лицо:** 2–3 преднастроенные формы + брови/глаза. **Blend shapes при наличии** подготовить на этапе правки меша; Meshy может их не создать и не нужно обещать, что пользовательские ползунки заработают автоматически.
4. **Классовая форма:** Support/Reina, Healer/Mira, Assault/Amina, Sniper/Lyra — **родственные**, не точные копии сюжетных героинь.
5. **Мужская база:** только после проверки женского модульного пайплайна; взрослый мужской аниме-тип тела, затем разные комплекции/фигура пирата. Оба пола получают все игровые классы, внешность не влияет на боевой баланс.
6. **Пришельцы:** отдельные base/rig при иной анатомии, общая художественная стилистика.

## 7. Файлы, именование и контрольные критерии

Для **одной** модели хранить:
- `references/human_female_base_v1/front.png` и при наличии `left.png`, `back.png`, `right.png`.
- `models/human_female_base_v1/source.glb`, `rigged.glb` (либо один GLB), `LICENSE_SOURCE.md` со ссылкой на работу, планом и условиями лицензии.
- `textures/human_female_base_v1/` и `preview/human_female_base_v1_front.png`; не добавлять автоматически огромные текстуры в runtime.
- По мере завершения — стабильные runtime-ассеты под `client/assets/character_creator/human_female/v1/`.

**Приёмка:** полноразмерный силуэт узнаваемо в стиле четырёх девочек; нет сросшихся рук и ног; закрытая минимальная спортивная одежда; лицевые черты не скопированы с одной героини; корректные `idle+walk` без провалов частей тела; GLB открывается в Godot и смотрится на Android; JSON настройки меняют внешний вид без потери прогресса RTS.

**Платные операции:** выбор Pro пользователем зафиксирован, но **подписка ещё не подтверждена**, поэтому `image_to_3d`, риг и экспорт **не выполнены**. Расход кредитов зависит от модели/режима, смотреть перед запуском в Meshy: https://help.meshy.ai/en/articles/10000507-how-many-credits-does-each-generation-task-cost . Сначала проверяем одной генерацией и исправляем геометрию, а не расходуем весь месяц на десять версий случайной базы.

## 8. Копируемое задание для участника команды

> Сгенерировать ОДНУ оригинальную взрослую женскую аниме-модель для NEKO: DEAD SIGNAL, A-pose, полный рост, чёткий front reference; нейтральные непрозрачные тёмные спортивный топ и плавки-шорты, без брони/оружия/аксессуаров; целевое назначение — модульный редактор персонажа в Godot, а не самостоятельный канонический NPC. Прислать reference PNG + исходный GLB + rigged GLB (если есть), запись об используемой модели Meshy и праве эксплуатации, 4 скриншота ракурсов, короткий `idle` и `walk` тест. Никаких изменений в сохранении и сценах RTS без отдельного этапа проверки.

**Источник технических требований**: Meshy Multi-View https://help.meshy.ai/en/articles/16102789-meshy-multi-view-best-practices-angles-and-images ; Pose https://help.meshy.ai/en/articles/10255659-how-to-generate-3d-models-with-a-pose-t-pose-or-custom-poses ; Auto Rigging https://help.meshy.ai/en/articles/16231707-how-to-create-3d-animation-with-auto-rigging ; Godot glTF https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html ; Godot retarget https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html .


## Фактический выпуск первых 2D-референсов · 2026-11-06

**Выполнено:** создан один исходный 4-ракурсный референс-лист женской взрослой аниме-базы в **непрозрачном спортивном топе и плавках-шортах**; из листа подготовлены четыре отдельных кадра, каждый **960×1850 PNG**, собран ZIP с README/manifest/SHA-256. **Это ещё не GLB и не 3D модель.** Ни запуск Meshy, ни трата кредитов, ни риггинг, ни Godot-импорт не выполнялись.

**Подтверждённая папка Google Drive:** [«Игра»](https://drive.google.com/drive/folders/1nbYMKjf3j6d9ThvTnw8Z7l4PObFtjJU2). Загрузка проверена через повторное чтение Drive метаданных с совпадающим parent ID.

| Вид | Файл на Drive | Дальнейшее действие |
|---|---|---|
| Главный фронт | [01_FRONT.png](https://drive.google.com/file/d/1_0jl_ZtXAmCrMg1VSbDL3vXLV89mnK6x/view?usp=drivesdk) | Основной input для Meshy 7 Image-to-3D |
| Правый профиль | [02_RIGHT.png](https://drive.google.com/file/d/1w6IRjcp9IPjVzf4cu72LrBONJYB7ZZJJ/view?usp=drivesdk) | Дополнительный ракурс |
| Спина | [03_BACK.png](https://drive.google.com/file/d/1PZ5e9z-WYmZfMarA9mqDhujJvy7NRhh1/view?usp=drivesdk) | Дополнительный ракурс |
| Левый профиль | [04_LEFT_mirrored.png](https://drive.google.com/file/d/19TYqqJtiOaX-YXb9rZeDD5feqXJzMPfJ/view?usp=drivesdk) | **Предварительный!** Отражён из второго правостороннего изображения; не считать точным независимо нарисованным ракурсом |
| Мастер-лист | [00_MASTER.png](https://drive.google.com/file/d/13T5oLKk-872zsiHV74XFrwT18vBysQMU/view?usp=drivesdk) | Источник/архив, **НЕ** загружать целиком в Meshy Image-to-3D |
| Архив | [Meshy_4views.zip](https://drive.google.com/file/d/1bp7mUCJg5ty3zcbtBA2upKZDhkHvRkD7/view?usp=drivesdk) | Общий комплект с README, manifest и 4 PNG |

**Ограничения референса:** исходные четыре колонки были созданы единой генерацией; проверка идеальной геометрической согласованности их анатомии не проводилась. Четвёртая колонка имела ошибку (смотрела в ту же сторону, что вторая), поэтому была отражена, о чём явно сообщается в имени и манифесте. Не смешивать зеркальный ракурс с различиями асимметричных причёсок. **Для производственной 3D-модели предпочтительно сначала попробовать Meshy 7 Generate Multi-View из 01_FRONT** и сравнить согласованность автоматически восстановленных боковых видов с нашим комплектом. Официальная рекомендация: https://help.meshy.ai/en/articles/16102789-meshy-multi-view-best-practices-angles-and-images .

**Стадия:** 2D inputs ready → **следующий этап** после фактической активации Meshy Pro: Meshy 7 Image to 3D → Multi-View (или Generate Multi-View) → Pose A → проверить меш и пальцы → Rig → GLB → Godot. Старые сцены RTS и сохранения не изменены.
