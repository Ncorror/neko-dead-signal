# Vienna CI / bootstrap operations

Текущий репозиторий: `Ncorror/neko-dead-signal`.

Системные имена `reina-rts-vienna-01`, `reina-rts-ci`, `/opt/reina-rts`, `reina-rts-bootstrap.service` и `reina-rts-debug.keystore` сохраняются **только ради совместимости с уже работающим VPS и подписью Android**. Это не название игрового продукта и не повод возвращать старый лор.

## Обычная работа

Исправный runner переустанавливать для каждой сборки не нужно. Android CI запускается workflow `.github/workflows/vienna-rts-android.yml` и требует self-hosted label `reina-rts-ci`.

`reina-rts-bootstrap.service` на `127.0.0.1:18777` — только health stub. `/healthz` подтверждает процесс, а `/readyz` не означает готовую сетевую игру. Авторитетный MMO/RTS match server ещё не реализован.

## Первое развёртывание или осознанное восстановление

Из Termux:

```bash
gh api "repos/Ncorror/neko-dead-signal/contents/ops/vienna/deploy-one-shot-termux.sh?ref=main" --jq '.content' | base64 -d > "$HOME/deploy-neko-dead-signal-vienna.sh"
bash "$HOME/deploy-neko-dead-signal-vienna.sh"
```

Нужны действующие GitHub authorization, SSH-доступ к Vienna и sudo. Секреты в чат не вставлять. Launcher разрешает `main` или явно заданный ref в commit SHA и разворачивает один согласованный набор файлов.

## Скрипты

- `preflight.sh` — безопасная предварительная проверка.
- `full-audit.sh` — чтение текущего состояния хоста.
- `install-runner.sh` — установка/восстановление self-hosted runner.
- `install-server.sh` — установка локального bootstrap health service.
- `deploy-one-shot-termux.sh` — одноразовый orchestrator из Termux.
- `switch-vienna-root.sh` — служебное переключение корня развёртывания.
- `audit-old-runner.sh` — диагностика оставшегося старого runner service; не обычный путь.
- `purge-legacy-game.sh` — **необратимая** утилита очистки старого игрового окружения. Не запускается обычным CI, аудитом или обновлением и требует отдельного осознанного решения.

Синтаксис всех Vienna shell-скриптов проверяет `.github/workflows/vienna-ops-lint.yml`.
