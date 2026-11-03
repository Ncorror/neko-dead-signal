extends PanelContainer
## Explicit mobile placement confirmation; a map tap only chooses a site.

var operation
var mode := 0
var inspected: Dictionary = {}
var title: Label
var balance: Label
var message: Label
var progress: ProgressBar
var factory_button: Button
var outpost_button: Button
var action_button: Button
var cancel_button: Button
var refresh_age := 0.0

func install(op) -> void:
    operation = op
    name = "ConstructionPanel"
    mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0b202bf5")
    style.border_color = Color("#59a8af")
    style.set_border_width_all(1)
    style.set_content_margin_all(12)
    add_theme_stylebox_override("panel", style)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    add_child(column)
    var heading := HBoxContainer.new()
    column.add_child(heading)
    title = Label.new()
    title.add_theme_font_size_override("font_size", 18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    var close := Button.new()
    close.text = "×"
    close.custom_minimum_size = Vector2(40, 40)
    close.pressed.connect(func() -> void: operation._close_construction())
    heading.add_child(close)
    balance = Label.new()
    balance.add_theme_font_size_override("font_size", 15)
    column.add_child(balance)
    message = Label.new()
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_font_size_override("font_size", 14)
    column.add_child(message)
    progress = ProgressBar.new()
    progress.custom_minimum_size.y = 14
    progress.show_percentage = false
    column.add_child(progress)
    factory_button = _button(column, "", func() -> void: choose(&"factory"))
    outpost_button = _button(column, "", func() -> void: choose(&"outpost"))
    action_button = _button(column, "", _act)
    cancel_button = _button(column, "", _cancel)
    catalog()

func _button(parent: Control, text: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 45
    button.add_theme_font_size_override("font_size", 15)
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func catalog() -> void:
    operation.construction.cancel_preview()
    inspected = {}
    mode = 0
    show()
    refresh()

func choose(kind: StringName) -> void:
    operation._reset_touch_state()
    operation.construction.begin(kind, operation)
    mode = 1
    inspected = {}
    refresh()

func inspect(entry: Dictionary) -> void:
    operation.production_panel.hide()
    operation.construction.cancel_preview()
    inspected = entry
    mode = 2
    show()
    refresh()

func _act() -> void:
    if mode == 1:
        operation.construction.confirm(operation)
    elif mode == 2 and not inspected.is_empty() and inspected["ready"]:
        if inspected["kind"] == &"factory":
            operation._open_factory(inspected)
        else:
            catalog()
    refresh()

func _cancel() -> void:
    if mode == 2 and not inspected.is_empty() and not inspected["ready"]:
        operation.construction.cancel_site(inspected, operation)
    catalog()

func _process(delta: float) -> void:
    refresh_age += delta
    if visible and refresh_age >= 0.15:
        refresh_age = 0.0
        refresh()

func refresh() -> void:
    if operation == null:
        return
    var work = operation.construction
    var active: bool = operation.outcome == operation.Outcome.ACTIVE
    balance.text = "ОБЩИЕ РЕСУРСЫ: %d" % operation.production.balance
    factory_button.visible = mode == 0
    outpost_button.visible = mode == 0
    action_button.visible = mode != 0
    cancel_button.visible = mode != 0
    progress.visible = mode == 2 and not inspected.is_empty() and not inspected["ready"]
    factory_button.disabled = not active
    outpost_button.disabled = not active
    cancel_button.disabled = not active
    if mode == 0:
        title.text = "СТРОИТЕЛЬСТВО"
        message.text = "Собери ресурсы и разведай площадку. Завод добавляет очередь выпуска, пост даёт обзор."
        factory_button.text = "%s · 200 / 8 с" % work.title(&"factory")
        outpost_button.text = "%s · 100 / 5 с" % work.title(&"outpost")
    elif mode == 1:
        title.text = "ВЫБЕРИ ПЛОЩАДКУ"
        var reason: String = work.refresh_preview(operation)
        message.text = "%s · %d ресурсов\n%s" % [work.title(work.placing),
            work.DEFINITIONS.get(work.placing, {"cost": 0})["cost"],
            "Место свободно. Подтверди строительство." if reason.is_empty() else reason]
        action_button.text = "ПОСТРОИТЬ"
        action_button.disabled = not active or not work.has_candidate or not reason.is_empty()
        cancel_button.text = "НАЗАД К ПОСТРОЙКАМ"
    elif not inspected.is_empty():
        title.text = "%s · %d" % [work.title(inspected["kind"]), inspected["id"]]
        var ready: bool = inspected["ready"]
        message.text = ("Своя очередь производства. Общий запас ресурсов." if inspected["kind"] == &"factory"
            else "Даёт текущий обзор вокруг поста, пока операция продолжается.") if ready else "Развёртывание · осталось %d с" % ceili(inspected["remaining"])
        progress.value = 100.0 * (1.0 - float(inspected["remaining"]) / float(work.DEFINITIONS[inspected["kind"]]["seconds"]))
        action_button.visible = ready
        action_button.text = "ОТКРЫТЬ ЗАВОД" if inspected["kind"] == &"factory" else "СТРОИТЬ ЕЩЁ"
        action_button.disabled = not active
        cancel_button.visible = not ready
        cancel_button.text = "ОТМЕНИТЬ СТРОЙКУ · +%d" % inspected["cost"]
