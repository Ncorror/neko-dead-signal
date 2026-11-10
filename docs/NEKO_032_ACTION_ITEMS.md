# NEKO 0.0.32 — Приоритетные действия

**После аудита:** 2026-11-10  
**Статус:** Проект стабильный, готов к следующему этапу

## ✅ Выполнено в ходе аудита
- [x] Глубокий аудит всех систем
- [x] Установка Lyra GLB-моделей (rigged.glb + sniper_rifle.glb)
- [x] Проверка всех автоматических тестов (21 test PASS)
- [x] Проверка CI (Repository structure SUCCESS)
- [x] Документирование состояния 0.0.32

## 🔴 P0 — Критические (перед релизом)
Нет блокеров. Сборка работает.

## 🟠 P1 — Высокий приоритет

### 1. Физическая проверка 0.0.32 APK на Android
- [ ] Скачать последний артефакт GitHub Actions
- [ ] Установить на Poco F7 / тестовое устройство
- [ ] Проверить:
  - [ ] Lyra Voss отображается корректно (не placeholder)
  - [ ] Снайперская винтовка видна на спине
  - [ ] Attack animation переключает винтовку в руку
  - [ ] Death animation проигрывается перед respawn UI
  - [ ] Rust Road boss blast работает
  - [ ] FPS стабилен (ожидается 120-121)
  - [ ] Сохранение/загрузка работает
- [ ] Зафиксировать результаты в новом device test document

## 🟡 P2 — Средний приоритет

### 2. Android-иконка приложения
**Проблема:** Приложение использует стандартную иконку Godot

**Действия:**
- [ ] Уточнить у владельца: есть ли утверждённая фирменная иконка NEKO?
- [ ] Проверить `assets/art/` и внешние источники
- [ ] Если есть: добавить как `client/icon.png` (512×512 или 1024×1024)
- [ ] Прописать в `client/project.godot`: 
  ```
  [application]
  config/icon="res://icon.png"
  ```
- [ ] Пересобрать APK, проверить иконку на устройстве

### 3. Документировать Lyra asset installation
**Проблема:** Новый разработчик не узнает, что нужно скачать GLB

**Действия:**
- [ ] Добавить секцию в README.md:
  ```markdown
  ## Development Setup
  
  ### Install Lyra Voss 3D Assets
  Large GLB models are not committed to Git. Download from Google Drive:
  
  ```bash
  pip install gdown==5.2.0
  python3 scripts/install_lyra_voss.py
  python3 scripts/install_lyra_voss_weapon.py
  ```
  
  Or add to CI workflow before Godot import.
  ```

- [ ] Либо: добавить проверку в `.github/workflows/vienna-rts-android.yml`

## 🔵 P3 — Низкий приоритет / Долгосрочное

### 4. Meshy female_base_v3 → Rigged Heroines
- [ ] Экспорт Рэйны (tank class)
- [ ] Экспорт Миры Кейд (healer, уже утверждена)
- [ ] Риг, LOD, анимации
- [ ] Интеграция в игру

### 5. MMO Backend — First Playable
- [ ] Авторитетная симуляция матча
- [ ] Первый PvE супер-данж с серверной проверкой
- [ ] Двоеигроков тест
- [ ] PostgreSQL: аккаунты, прогрессия

### 6. Оптимизация производительности
- [ ] Проверить нагрев устройства при длительной игре
- [ ] Ограничить размер building labels при zoom
- [ ] Профилировать spike >40ms (если повторяется)

## Следующий коммит

После завершения P1/P2:
- Открыть PR из `agent/neko32-claude` в `main`
- Заголовок: `fix(lyra): verified 0.0.32 combat and Android integration`
- Описание: ссылка на audit + action items
- Слить после code review

---
*Актуализировано по результатам полного аудита 2026-11-10*
