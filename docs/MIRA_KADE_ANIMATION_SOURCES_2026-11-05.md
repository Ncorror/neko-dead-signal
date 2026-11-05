# Мира Кейд: аудит анимаций Meshy и бесплатных альтернатив · 2026-11-05

**Актуализация 2026-11-06:** из набора Миры исключены «Сервисный инструмент» (ремонт) и «Аварийная стабилизация». Анимации для этих способностей больше не планируются; другие медицинские/боевые клипы и внешний вид сохраняются. [Актуальный набор](MIRA_KADE_HEALER_MASS_HEAL_DESIGN_v0.1.md).

**Статус:** изучены публичные каталоги/документация и лицензии на 2026-11-05. **Никакие клипы не скачаны, не ретаргетированы и не применены к модели Миры; 3D-тесты/Android не выполнялись.** Этот документ дополняет [дизайн хила, дрона и оружия Миры](MIRA_KADE_HEALER_MASS_HEAL_DESIGN_v0.1.md). У команды нет ПК и платного бюджета, приоритет Android/браузер, GitHub CI/VPS.

## 1. Итоговый выбор

- **Основная база бесплатных движений:** [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library) (**CC0**, стандартный бесплатный пакет, Godot-friendly, в карточке 120+ для семейства библиотеки; платные Pro и Source отличаются наполнением), [Mixamo](https://www.mixamo.com/) (по [Adobe FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html): бесплатно, можно использовать в коммерческих видеоиграх, нужен Adobe ID), [Rokoko 11 free gun motions](https://www.rokoko.com/resources/rokoko-mocap-11-free-gun-animations) (FBX, Mixamo skeleton, 30 FPS, официально разрешено для коммерческих игр).
- **Meshy** удобно для уже подготовленного собственного humanoid рига и предварительного выбора клипов по ID, но **не считать всю библиотеку бесплатной**: на [официальной странице](https://www.meshy.ai/animation-library) указано **631** действий, из них **22 бесплатны**, остальные требуют Pro; **коммерческие права на анимированные экспорты — в Pro+**, бесплатный вывод личный/оценочный. Отдельная система API/план может иметь свои кредиты. Перед релизом убедиться в происхождении и правах на каждый файл.
- **Новая браузерная альтернатива:** [KinemIQ](https://kinemiq.app/) и [список 460 бесплатных клипов](https://kinemiq.itch.io/free-game-animations), сайт указывает 175 CC0 + 285 CC BY (требуются атрибуции), экспорт GLB/FBX/BVH, video-to-animation в браузере на телефоне. **Text-to-motion KinemIQ заявлен только для desktop Chrome/Edge и локальной GPU**, на нашем Android его не обещать. Проект пока **публичная beta**; качество/совместимость с нашей моделью не проверено.
- [Rokoko 263 free clips](https://www.rokoko.com/resources/download-263-rokoko-motion-capture-assets) и [free magic-themed motions](https://www.rokoko.com/resources/rokoko-mocap-free-magic-themed-animations) пригодятся для жестов запуска медицинского устройства/нанополя; FBX/Mixamo skeleton. Получение бесплатных пакетов может потребовать форму/почту, фактическая загрузка не проверялась.
- **DeepMotion Animate 3D** ([тарифы](https://www.deepmotion.com/pricing-animate3d)) имеет бесплатные кредиты и GLB/FBX/BVH, но права на коммерческое использование free-тарифа из найденного отображения не удалось однозначно подтвердить; **не ставить на него коммерческий pipeline без проверки лицензии**.

## 2. Meshy — подтверждённые ID из официального справочника

Источник [Meshy Animation Library Reference](https://docs.meshy.ai/en/api/animation-library). ID — **кандидаты** для телесных движений, не проверенные жесты на конкретной модели, ракурсе и с оружием Миры.

| Роль для Миры | Meshy ID / Name | Что проверить |
|---|---|---|
| Idle | `0 Idle` | естественная стойка с медицинским комплектом и пистолетом |
| Walk / Run | `1 Walking_Woman`, `14 Run_02` | in-place движение, отсутствие скольжения ног |
| Пистолет/выстрел | `236 Draw_and_Shoot_Left`, `232 Cowboy_Quick_Draw_Shooting` | хват одной рукой, ориентация кисти, анимация не должна быть ковбойским театром |
| Перезарядка | `170 Standing_Reload` | перезарядка соответствует нашему импульсному пистолету |
| Встать на колено/подняться | `365 Kneel_on_One_Knee_and_Stand` | часть процедуры боевого воскрешения / лечения лежачей цели |
| Медицинский осмотр / взаимодействие | `281 Female_Bend_Over_Pick_Up_Inspect`, `284 Collect_Object` | только нейтральная поза, не готовая лечебная анимация; **навык ремонта Миры отменён** |
| Запуск медицинского импульса | `125 Charged_Spell_Cast` | взять **жест**, а не магический VFX; нанотехника отрисована в Godot |
| Воздействие/гибель | `178 Hit_Reaction`, `8 Dead` | позы и переходы |
| Контекстные жесты | `29 Call_Gesture`, `50 Phone_Call_Gesture` | запуск дрона, интерфейс управления, отработка рукой |

**Не обещать наличие специальных точных Meshy клипов для «боевого воскрешения», «нанохила по области» и «возврата персонального дрона».** По проверенному каталогу подходящие базовые движения есть, но специальной завершённой последовательности не подтверждено.

**Meshy Text to Motion:** [официальный API](https://docs.meshy.ai/en/api/text-to-motion) генерирует клип из текста; указаны `swift` = 3 кредита, `prime` = 10 кредитов за задание. Это не подтверждает бесплатное коммерческое использование. Не расходовать кредиты, пока не импортирован и не проверен один базовый клип на целевом риге.

## 3. Матрица наших уникальных действий

| Действие | Берём из библиотеки | Доработка своей сценой Godot |
|---|---|---|
| Idle/Walk/Run/Hit/Death | Meshy/Quaternius/Mixamo | `AnimationTree`, blend, root motion off для управления навигацией |
| Один выстрел пистолета | Meshy 236/232 или Rokoko gun pack | держатель оружия по кости, muzzle VFX, звук, hit timing от геймлогики |
| «Электроимпульс» | короткий жест удара/выстрела | дуга, радиус, замедление/урон server authoritative |
| Адресное лечение и self-heal | короткий жест рукою/терминалом | инъектор, маркер цели, луч/частицы, heal numbers |
| «Нанополе» — массовый хил | жест разведения рук/активации | круговой VFX и подтверждённый на сервере набор исцелённых |
| Воскрешение **в бою** `Dead/Revivable` | kneel (365), hand interaction, stand/get-up для цели | процедура/канал, дрон/инъектор, анимация подъёма, серверное подтверждение, прерывание |
| Ремонт техно-оборудования | 281, 284 / другие body gestures | держатель инструмента и weld/scan VFX, не смешивать с лечением |
| Дрон в МЕД | **не humanoid mocap** | отдельный простой `hover/follow/heal` AnimationPlayer, лечение до союзника |
| Дрон в БОЙ | **не humanoid mocap** | `return_to_mira/guard/defensive_fire`, модель постоянно возле Миры, два триггера: Мира атакует и атакуют Миру; дальность **пистолет Миры +2**, он не имеет HP и ломается только после поражения Миры |

## 4. Рекомендуемый бесплатный маршрут, без ПК

1. **Не трогаем оригинальные изображения Миры** в Google Drive и текущую RTS. Берём её модель в нужной нейтральной A-pose после появления rigged GLB (пока такой финальный клип не подтверждён).
2. Получить **бесплатную стандартную Quaternius** с `root motion disabled`; просмотреть локально на телефоне или в Godot Android Editor. Предметы/оружие не вшивать в скелетные клипы.
3. Проверить авториг Mixamo/Meshy **на одной модели**, затем выбрать **одно целевое соглашение о humanoid-костях**. Не смешивать неизвестные костные схемы в APK.
4. При необходимости использовать свободные `Mixamo` движения и `Rokoko 11 gun` для пистолета; конвертировать/ретаргетировать FBX на единую схему и GLB на доступном CI/VPS или в поддерживаемом Android-редакторе, если выполнимо.
5. Для лечения/воскрешения взять нейтральные жесты и собрать **свои** VFX и анимационную последовательность в Godot (а не платно генерировать «волшебное исцеление»).
6. При нехватке — тестировать **KinemIQ video-to-motion** с коротким записанным на телефон движением (не обещать качество). **Text-to-motion KinemIQ требует ПК/GPU**, пока не используем; Meshy Text to Motion платный API/лицензию проверять отдельно.
7. Ретаргетинг в Godot через `SkeletonProfileHumanoid`, `BoneMap`, Bone Rest: [официальное руководство](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html). `GLB/glTF` — предпочтительный импорт: [официальная справка](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html). Проверять стопы/кисти и прицел.
8. Функции хила/урона/воскрешения/дрона не зависят от того, есть ли анимация и проигралась ли она целиком. Итог вычисляет **сервер**, а не точка keyframe.
9. Проверить 3D производительность на Android: число костей, ограничения draw calls, пропорции текстур, число VFX на осаде, удары при 30 FPS, прерывания анимации.
10. **Не включать** ни один чужой ассет в публичную APK без сверки конкретной лицензии. Для CC BY хранить кредитный manifest рядом с ассетами, для Meshy free-tier не заявлять коммерческие права.

## 5. Документальные источники

- Meshy library/pricing: https://www.meshy.ai/animation-library
- Meshy IDs: https://docs.meshy.ai/en/api/animation-library
- Meshy Text to Motion: https://docs.meshy.ai/en/api/text-to-motion
- Mixamo commercial FAQ: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html
- Quaternius CC0, Standard vs paid tiers: https://quaternius.itch.io/universal-animation-library
- Rokoko 11 gun: https://www.rokoko.com/resources/rokoko-mocap-11-free-gun-animations
- Rokoko 263 free: https://www.rokoko.com/resources/download-263-rokoko-motion-capture-assets
- KinemIQ browser & phone/desktop restrictions: https://kinemiq.app/
- KinemIQ 460 licenses: https://kinemiq.itch.io/free-game-animations
- Godot retargeting: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html

**Текущий результат:** подтверждено наличие источников и кандидатных анимаций/ID; загрузки, сборки и тесты движений на нашей Мире ещё не проводились.
