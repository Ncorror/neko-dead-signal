# Проверка исправлений Лиры · 2026-11-10

## Обновление: покадровая лаборатория

Код/APK: `38d5bebf821f413fa9fe68cb7ec60c6259071582`.
Локальные Lyra rig и Python contracts: PASS. Проверены пауза/продолжение,
seek, шаг назад/вперёд, ограничение концом клипа, повторное проигрывание,
замедление, переключение крепления и его сброс. UI проверен headless при
1024×600 и 2048×945 с учётом координат растянутого viewport.

[Android CI #42866679505](https://github.com/Ncorror/neko-dead-signal/actions/runs/42866679505)
и Repository structure #42866679375: SUCCESS.

**Последний APK:** [neko-dead-signal-debug-174](https://github.com/Ncorror/neko-dead-signal/actions/runs/42866679505/artifacts/13785929947).
SHA256: `40d1d2cf29e6eeab498fb3514356105f058cca623350598b9f380e1afdc0e9e9`.
Локально: `/tmp/opencode/lyra-lab-apk/NEKO_DEAD_SIGNAL-0.0.32-debug.apk`.

На телефоне: Лира → АНИМАЦИИ → Standing_Reload → 0,25× → ОРУЖИЕ: КИСТЬ.
Повернуть модель, остановиться на проблемном контакте, записать название
клипа и время; кнопками ± КАДР проверить соседние положения. Затем СТОЙКА:
оружие должно вернуться на спину. Аналогично проверить Walking, Running и
Dead. Физический тест, качество хватов и деформаций пока не подтверждены.

## Обновление: направление стрельбы и смена цели

Код/APK: `9a8b16612920b48f9c09f8268220497f5adc0dbf` (включает `9b0be90`).
Локальные тесты Lyra rig, world combat, world battle, RTS auto fire и Python
contracts прошли. Регрессии проверяют поворот к цели сзади, переключение цели,
приоритет движения, ответный огонь, смерть и смену агрессора внутри одного
тика. Разрешение выстрела привязано к проверенной цели; новая цель требует
повторной проверки направления.

[Android CI #42863117672](https://github.com/Ncorror/neko-dead-signal/actions/runs/42863117672)
и Repository structure #42863117733: SUCCESS.

**Последний APK:** [neko-dead-signal-debug-173](https://github.com/Ncorror/neko-dead-signal/actions/runs/42863117672/artifacts/13786317400).
SHA256: `767058ac7149935b3578d042a1efce3706f9b78337cfc6be23a5f523e3d046eb`.
Локально:
`/tmp/opencode/lyra-facing-apk/neko-dead-signal-debug-173/NEKO_DEAD_SIGNAL-0.0.32-debug.apk`.

На устройстве: в RTS/PvE выбрать цель сбоку/за спиной, переключить цель во
время поворота, отдать приказ движения. Проверить плавность разворота и
отсутствие выстрела до поворота к новой цели. Это поворот корпуса, не готовая
винтовочная прицельная анимация: оружейные клипы и двухручный хват остаются
открытыми задачами. Физический прогон не проведён.

## Обновление: смерть в RTS

Код/APK: `73c6e7e98dec2d42c56b2b383ff338263951fc49`.
Локальные `test_lyra_voss_rig`, `test_operation_result` и 21 Python contract:
PASS. Добавлены проверки исключения погибшей Лиры из приказов, выделения и
снайперского обзора, удержания последнего кадра, повторного события смерти и
сохранения крепления винтовки.

[Android CI #42859710307](https://github.com/Ncorror/neko-dead-signal/actions/runs/42859710307)
и Repository structure #42859709952: SUCCESS.

**Актуальный APK:** [neko-dead-signal-debug-171](https://github.com/Ncorror/neko-dead-signal/actions/runs/42859710307/artifacts/13785415395).
SHA256: `b718d489e9bd2ec494e4f2997cf5cfb806fa3fb5007991c3ec7b6840dc80965b`.
Локально:
`/tmp/opencode/lyra-rts-death-apk/neko-dead-signal-debug-171/NEKO_DEAD_SIGNAL-0.0.32-debug.apk`.

На телефоне дополнительно проверить гибель Лиры в RTS при живом эскорте:
падение целиком, отсутствие выделения и обзора от погибшей, сохранение позы
после завершения клипа. Проверить уход на корабль во время падения. Физический
прогон и художественное качество пока не подтверждены.

## Предыдущая сборка

Код/APK: `cf4a665b6045df5b681f4a173d917469ac937f25`, ветка `agent/neko32-gpt`.

- Локальные Python contracts: 21 тест, PASS; server unittest: PASS.
- Godot 4.7.2, реальный импорт двух SHA256-проверенных GLB: PASS.
- `test_lyra_voss_rig.tscn`: PASS, без SCRIPT ERROR/ERROR. Проверены загрузка
  во всех пяти сценах, переходы движения, отсутствие archery-подмены,
  полная длительность смерти, блокировка движения/атаки при смерти,
  возрождение и изоляция изменяемых анимаций между экземплярами.
- [Полный Android CI #42857786414](https://github.com/Ncorror/neko-dead-signal/actions/runs/42857786414): SUCCESS.
  Включает весь существующий набор Godot-регрессий, ARM64 export и apksigner verify.
- [Repository structure #42857786490](https://github.com/Ncorror/neko-dead-signal/actions/runs/42857786490): SUCCESS.

## APK для телефона

[Артефакт neko-dead-signal-debug-170](https://github.com/Ncorror/neko-dead-signal/actions/runs/42857786414/artifacts/13782519738)
содержит `NEKO_DEAD_SIGNAL-0.0.32-debug.apk`.

SHA256:
`c86b872de85b8b5c50da78f11f03409908795325175b51714b09187fa8b38c33`.

Локально: `/tmp/opencode/lyra-apk/NEKO_DEAD_SIGNAL-0.0.32-debug.apk`.
Артефакт CI хранится 14 дней. Диагностика: `neko-dead-signal-ci-logs-170`.

## Физическая проверка этой сборки

1. Выбрать Лиру: меню и лаборатория, затем RTS, WorldZone, PvE, планета 128×128.
   Записать видео с близким обзором модели, оружия, ног и плеч.
2. Ходьба → бег → стоп → новая цель/поворот; отметить рывки, скольжение,
   пересечения и неверную высоту над поверхностью.
3. PvE: стрельба остаётся без винтовочного клипа; убедиться, что нет жеста
   лучника. Смерть должна завершиться до окна возрождения, после возрождения
   движение должно работать. Проверить новую цель и выход/повторный вход.

**Физического прогона не было. Визуальное качество и Android-производительность
не подтверждены. Это промежуточная исправленная сборка, не Gold Standard.**
Открытые задачи и задания на ассеты: [LYRA_GOLD_STANDARD.md](LYRA_GOLD_STANDARD.md).
