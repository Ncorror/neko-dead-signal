# REINA RTS · Тестовая диагностика v0.0.5

**Актуальная ветка:** `feat/tester-diagnostics-3d-roster`. Только DEBUG-сборка APK. Онлайн-телеметрия отсутствует.

## Какие логи собираем

- **Игровые**: загрузка/возврат, выбор командира, фракция, приказы армии, путь (принят/отклонён), выбор/стоп, попадания и HP, припасы, исход высадки, ошибки загрузки арта.
- **Ввод и камера**: отдельные события tap, окончание свайпа, масштаб и координаты фокуса — не каждый пиксель и не каждый кадр.
- **Производительность**: FPS, число юнитов/приказов каждые 3 секунды.
- **Godot**: встроенный движковый файл `user://logs/godot.log` (предупреждения, ошибки, stdout), включён только в debug.
- **Ограничения**: это журналы *нашего приложения*, не дамп всех чужих процессов Android, не root/kernel-log и не автоматический bugreport OS. Системный logcat собирается только с согласия тестировщика отдельно.

## Кнопка ЛОГИ

В орбитальном меню и на экране операции появляется только в debug APK. При нажатии:

- **КОПИРОВАТЬ**: последние ~90 игровых событий, не больше ~20 000 символов. Можно отправить текстом в Telegram.
- **СОЗДАТЬ ZIP**: создаёт `user://rts-diagnostics/reports/report-0.zip` со списком событий и доступными файлами Godot. Расположение выдаётся в диалоге.
- Нет автоматической отправки, утечки токенов, серверных вызовов или сетевых разрешений ради диагностики.

## Ротация и нагрузка

- JSONL: `events-0.jsonl` + `events-1.jsonl` + `events-2.jsonl`, каждая часть до 384 KiB.
- Буфер: до 32 событий с записью пакетами раз в 2 секунды. При аварийном завершении последние несколько секунд могут быть потеряны; системный файл Godot и logcat помогут.
- Отчёт: `report-0.zip`, `report-1.zip`, `report-2.zip` (старейший удаляется при создании следующего).
- Godot engine log: 3 файла ротации; в ZIP берем до четырёх по максимум 2 MiB каждого. Системные ошибки логируются штатным механизмом Godot.
- На production: `OS.has_feature("debug") == false` выключает сбор и UI; `debug/file_logging/enable_file_logging=false` вместе с feature override `.debug=true` выключает движковое сохранение в релизе. В code review надо следить за появлением новых прямых `print` и высокочастотной сериализации.

## Как получить ZIP из телефона с root/Termux

После нажатия **СОЗДАТЬ ZIP** в игре запусти Termux:

```bash
APP='com.ncorror.reinadeadsignal.rts'
su -c "find /data/user/0/$APP -type f -name 'report-0.zip' 2>/dev/null"
```

Если нашёлся файл, скопируй его (используя путь из вывода):

```bash
APP='com.ncorror.reinadeadsignal.rts'
SRC=$(su -c "find /data/user/0/$APP -type f -name 'report-0.zip' 2>/dev/null" | head -n 1)
[ -n "$SRC" ] || { echo 'ZIP not found; press CREATE ZIP in game'; exit 1; }
DEST="/sdcard/Download/REINA_RTS_$(date +%Y%m%d_%H%M%S).zip"
su -c "cp '$SRC' '$DEST' && chmod 0644 '$DEST'"
echo "$DEST"
```

Если игра сейчас запущена, отдельный узкий срез Android logcat **только этого процесса**:

```bash
APP='com.ncorror.reinadeadsignal.rts'
PID=$(su -c "pidof $APP" | awk '{print $1}')
if [ -n "$PID" ]; then
  su -c "logcat -d --pid=$PID -t 4000 -v threadtime" \
    > "$HOME/storage/downloads/REINA_RTS_app_logcat.txt"
fi
```

Согласуй отправку отчётов: файлы могут содержать локальные пути, имена объектов и отладочные сведения о сессии. Перед выкладыванием в открытый чат проверь содержимое.

**Без root:** кнопка «КОПИРОВАТЬ» уже работает, извлечение приватного ZIP через системное меню «Поделиться» потребует отдельного нативного Android FileProvider/SAF-плагина. Нельзя утверждать, что ZIP напрямую доступен в Downloads без root/плагина.

## RTS меню и 3D

- Добавлены кнопки «◀ ПРЕД.» / «СЛЕД. ▶» для гарантированного доступа ко всем героиням, независимо от touch-scroll.
- Скролл встроенного списка включён с видимым индикатором и `follow_focus`.
- Центральная область поддерживает `SubViewport` с **одной** 3D-моделью выбранной героини, медленным вращением, освещением и optional Idle. Если оригинальный GLB отсутствует, показывается 2D-портрет. Никакой фальшивой 3D-модели не добавлено.
- Пути к GLB: `client/assets/characters/{amina,reina,mira_kade,lyra_voss}/preview.glb`. Для статичного превью риг не обязателен, но для RTS-анимаций по-прежнему нужны скелет/Idle/Walk/Run.

Документация Godot: [Logging](https://docs.godotengine.org/en/stable/tutorials/scripting/logging.html), [ZIPPacker](https://docs.godotengine.org/en/stable/classes/class_zippacker.html), [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html), [SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html).
