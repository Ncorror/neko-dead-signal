extends Node
## Unified debug-only diagnostics UI, shareable text via clipboard, ZIP via user://.

var popup: AcceptDialog

func install(owner_node: Node, button_bar: HBoxContainer) -> void:
    if not RTSDiagnostics.enabled:
        return
    popup = AcceptDialog.new()
    popup.title = "REINA RTS · Диагностика"
    popup.dialog_text = "Запись активна только в debug APK.\nСоздай ZIP или скопируй краткий отчёт."
    popup.min_size = Vector2i(650, 260)
    popup.get_ok_button().text = "ЗАКРЫТЬ"
    popup.add_button("КОПИРОВАТЬ", true, "copy")
    popup.add_button("СОЗДАТЬ ZIP", true, "zip")
    popup.custom_action.connect(_on_action)
    owner_node.add_child(popup)
    var btn := Button.new()
    btn.text = "ЛОГИ"
    btn.custom_minimum_size = Vector2(94, 47)
    btn.pressed.connect(_open)
    button_bar.add_child(btn)

func _open() -> void:
    if popup == null:
        return
    RTSDiagnostics.event("ui", "diagnostics_opened")
    popup.dialog_text = "DEBUG-логирование включено.\nZIP собирает события игры и системные сообщения Godot.\nНикакой автоматической отправки на сервер нет."
    popup.popup_centered(Vector2i(680, 300))

func _on_action(action: StringName) -> void:
    if action == &"copy":
        DisplayServer.clipboard_set(RTSDiagnostics.report_preview())
        popup.dialog_text = "Последние события скопированы в буфер обмена.\nВставь текст в Telegram вместе со скриншотами."
    elif action == &"zip":
        var path: String = RTSDiagnostics.make_report()
        if path.is_empty():
            popup.dialog_text = "Ошибка записи ZIP. Используй КОПИРОВАТЬ и пришли отчёт."
        else:
            popup.dialog_text = "ZIP сохранён в приватном каталоге игры:\n" + path + "\n\nНа Android файл пока нужно извлечь через Termux/ADB.\nНе публикуй отчёт открыто."
