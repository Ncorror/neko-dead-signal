# NEKO: DEAD SIGNAL · полный аудит нейминга и путей · 0.0.29 · 2026-11-09

## База и цель

Репозиторий: `Ncorror/neko-dead-signal`, ветка `main` на старте аудита `36616f8cf631b37b7447bf77c4abbcc8ee9ba3ad`. Работа вынесена в `chore/neko-paths-and-branding-audit-029` и не удаляет рабочие механики. Цель: убрать старый продуктовый бренд из действующего Android-клиента, исправить адреса GitHub, сделать проверки маркировки обязательными; отделить исторические идентификаторы от действующей инфраструктуры.

## Код и текущая версия

- Godot `application/config/name` и Android label: **NEKO: DEAD SIGNAL**, package `com.ncorror.neko.deadsignal`. Версия клиента `0.0.29`, versionCode `29`; старый APK 0.0.28 отличается версией.
- Исправлены пропущенные названия в `client/scripts/operation.gd`, `client/scripts/rts_diagnostics_ui.gd`, нижнем подвале `client/scripts/main.gd` и `assets/art/commanders-v1/ASSETS.json`.
- `client/tests/test_menu_layout.gd` теперь **обязательно** обнаруживает новый заголовок, а не пропускает его при отсутствии старого. Прочие имена `reina` в идентификаторах персонажей, портретов и ресурсах не трогать: **Рэйна — героиня**.
- Исправлены CI artifact version 0.0.29, test contracts и GitHub source URLs в `ops/vienna/deploy-one-shot-termux.sh`, `ops/vienna/install-runner.sh`. Новая staging-папка `/tmp/neko-dead-signal-switch-*` совместима с проверкой legacy prefix.
- `server/control_api.py`: заявлен новый идентификатор `neko-dead-signal` и порт `NEKO_DEAD_SIGNAL_PORT` с fallback к `REINA_RTS_PORT`. Это **изменение исходников**, а не автоматическое обновление запущенного health сервиса. Реальный MMO-server по-прежнему отсутствует.
- Исправлены живые ссылки Termux, команды извлечения диагностики для нового Android package ID, актуальные шапки GDD, арта и документации; прежние версии явно отмечены как архив.

## Совместимость и ограничения переименования

1. **Старое приложение** `com.ncorror.reinadeadsignal.rts` хранит отдельные данные. Не удалять его и не пытаться автоматически перенести `user://` без отдельного проверенного миграционного сценария.
2. **Действующий VPS**: учётные записи `reina-rts-ci` / `reina-rts-svc`, systemd `reina-rts-bootstrap.service`, runner `reina-rts-vienna-01`, метка `reina-rts-ci`, директории `/opt/reina-rts`, старое имя debug-keystore и CI workflow-файл `.github/workflows/vienna-rts-android.yml` остались для совместимости. Нельзя удалять/создавать их заново ради косметики. Системную миграцию проводить отдельно после бэкапа и проверки sudo/runner/job/подписи.
3. **Исторические доказательства**: screenshot filenames, старые build artifacts, архивный `docs/DEVICE_TEST_RTS_008.html`, оригинальные zip/sha256, `ops/vienna/purge-legacy-game.sh` и ссылки на старый *другой* удалённый проект остаются точными документальными следами. Скрипт purge — необратимый и не должен запускаться при ребрендинге.
4. **Сервер**: обновление файлов репозитория не является деплоем на `shy-ivory`; живой сервис прежнего имени не трогали.
5. **Meshy Pro** подтверждена пользователем, но экспорт/риг/LOD/анимации не считаются готовыми. Вся новая генерация идёт от **female_base_v3**, не устаревших v1/v2.

## Критерии завершения

- `Repository structure`: Python-контракт версии/названий, shell syntax и ссылки.
- `Neko Dead Signal Android Debug`: Godot, сцены, тесты, экспорт ARM64, подпись нового APK; проверить конкретный run для итогового SHA, а не старый успех 0.0.28.
- После успешного CI — PR в main, затем отдельная установка 0.0.29 на Android и проверка меню, старого приложения, сохранений, ZIP-отчёта и RTS/PvE.
- Любые реальные миграции VPS, ключа подписи и прежнего Android пакета — отдельные действия с предохранителями.