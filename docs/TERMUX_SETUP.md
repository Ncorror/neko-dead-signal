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
