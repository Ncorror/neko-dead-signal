# Termux: работа с созданным репозиторием

Репозиторий уже создан в GitHub — не запускай повторно `gh repo create`.

```bash
pkg install -y git gh
gh auth status
gh repo clone Ncorror/neko-dead-signal
cd neko-dead-signal
bash scripts/verify-layout.sh
```

Godot-проект находится в `client/`. Для импортирования внешних GLB используй `client/assets/` только после проверки лицензий и веса ассетов. Секреты и ключи подписи не коммитить.

Проверка наличия новых коммитов:
```bash
gh run list -R Ncorror/neko-dead-signal --limit 5
git status --short --branch
```

## Проверка RTS-сборок

```bash
gh run list -R Ncorror/neko-dead-signal --workflow vienna-rts-android.yml --limit 5
```

**Важно:** готовую сборку берём из успешного запуска `main`; feature-ветка проходит CI до слияния, затем `main` собирается отдельно. Для скачивания APK используй точный ID успешного запуска Actions и артефакт `neko-dead-signal-debug-N`. `neko-dead-signal-ci-logs-N` содержит журналы, а не приложение. Начиная с 0.0.16 тестовый артефакт содержит только APK (текущий — `NEKO_DEAD_SIGNAL-0.0.29-debug.apk`); HTML-тестбук больше не нужен для проверки, задания выдаются в чате. Исходные модели и портреты из ZIP нужно публиковать отдельным бинарным коммитом; индекс `ASSETS.json` не заменяет PNG/GLB.

Управление в версии pure RTS: касание юнита — выделение, касание земли — перемещение, свайп — камера, `+/-` или два пальца — масштаб. «СТРОЙКА» — выбор и подтверждение здания. Системная «Назад» закрывает панель либо просит подтверждение выхода/возврата. Никакого джойстика.

**Важно после rename:** если старая локальная копия уже существует, не клонируй повторно: `git remote set-url origin https://github.com/Ncorror/neko-dead-signal.git` внутри этого checkout. Перед правкой проверь `git status` и `git remote -v`. Новое приложение `com.ncorror.neko.deadsignal` устанавливается отдельно от старого ID, поэтому старую версию и её данные пока не удаляй.
