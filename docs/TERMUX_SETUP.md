# Termux: работа с созданным репозиторием

Репозиторий уже создан в GitHub — не запускай повторно `gh repo create`.

```bash
pkg install -y git gh
gh auth status
git clone https://github.com/Ncorror/reina-dead-signal-rts.git
cd reina-dead-signal-rts
bash scripts/verify-layout.sh
```

Godot-проект находится в `client/`. Для импортирования внешних GLB используй `client/assets/` только после проверки лицензий и веса ассетов. Секреты и ключи подписи не коммитить.

Проверка наличия новых коммитов:
```bash
gh run list -R Ncorror/reina-dead-signal-rts --limit 5
git status --short --branch
```

## Проверка RTS-сборок

```bash
gh run list -R Ncorror/reina-dead-signal-rts --workflow vienna-rts-android.yml --limit 5
```

**Важно:** готовую сборку берём из успешного запуска `main`; feature-ветка проходит CI до слияния, затем `main` собирается отдельно. Для скачивания APK используй точный ID успешного запуска Actions и артефакт `reina-rts-debug-N`. `reina-rts-ci-logs-N` содержит журналы, а не приложение. Исходные модели и портреты из ZIP нужно публиковать отдельным бинарным коммитом; индекс `ASSETS.json` не заменяет PNG/GLB.

Управление в версии pure RTS: касание юнита — выделение, касание земли — перемещение, свайп — камера, `+/-` или два пальца — масштаб. «СТРОЙКА» — выбор и подтверждение здания. Системная «Назад» закрывает панель либо просит подтверждение выхода/возврата. Никакого джойстика.
