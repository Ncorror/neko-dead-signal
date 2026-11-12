# Vienna operations

Текущий репозиторий: `Ncorror/neko-dead-signal`.

## Текущее назначение VPS

Игровые GitHub Actions больше **не используют self-hosted runner на Vienna/VPS**.

Android/Godot CI выполняется на GitHub-hosted runner через:

`.github/workflows/vienna-rts-android.yml`

VPS остаётся только для:
- AI-разработки и вспомогательных инструментов;
- локального bootstrap health service на `127.0.0.1:18777`;
- ручной диагностики хоста при необходимости.

Self-hosted runner `reina-rts-vienna-01` и пользователь `reina-rts-ci` считаются выведенными из эксплуатации и не должны регистрироваться заново.

## Bootstrap service

`reina-rts-bootstrap.service` — локальный health stub, а не полноценный MMO/RTS сервер.

- `/healthz` подтверждает только состояние локального процесса.
- `/readyz` не означает готовность сетевой игры.
- сервис не должен быть открыт в Интернет.

Для первичной установки используется `ops/vienna/install-server.sh`.

## Скрипты

- `preflight.sh` — безопасная предварительная проверка VPS.
- `full-audit.sh` — read-only аудит текущего состояния хоста.
- `install-server.sh` — установка локального bootstrap health service.
- `purge-legacy-game.sh` — необратимая очистка старого игрового окружения; не запускается автоматически.

Runner-specific deploy/install scripts удалены после миграции Android CI на GitHub-hosted infrastructure.

Синтаксис оставшихся Vienna shell-скриптов проверяет `.github/workflows/vienna-ops-lint.yml`.
