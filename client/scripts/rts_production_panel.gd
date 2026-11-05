extends PanelContainer
## Mobile factory controls; resource and queue rules stay in RTSProduction.

var operation
var balance_label: Label
var queue_label: Label
var progress: ProgressBar
var train_button: Button
var cancel_button: Button
var title: Label
var refresh_age := 0.0

func install(owner_node) -> void:
    operation = owner_node
    name = "ProductionPanel"
    mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#0b202bf5")
    style.border_color = Color("#4b8795")
    style.set_border_width_all(1)
    style.set_content_margin_all(14)
    add_theme_stylebox_override("panel", style)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    add_child(column)
    var heading := HBoxContainer.new()
    column.add_child(heading)
    title = Label.new()
    title.text = "ПОЛЕВОЙ ЗАВОД" if GameState.faction_index == 0 else "УЗЕЛ СИНТЕЗА"
    title.add_theme_font_size_override("font_size", 19)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title)
    var close := Button.new()
    close.text = "×"
    close.custom_minimum_size = Vector2(40, 40)
    close.pressed.connect(hide)
    heading.add_child(close)
    balance_label = Label.new()
    balance_label.add_theme_font_size_override("font_size", 16)
    column.add_child(balance_label)
    queue_label = Label.new()
    queue_label.add_theme_font_size_override("font_size", 16)
    column.add_child(queue_label)
    progress = ProgressBar.new()
    progress.custom_minimum_size.y = 14
    progress.show_percentage = false
    column.add_child(progress)
    train_button = Button.new()
    train_button.custom_minimum_size.y = 48
    train_button.add_theme_font_size_override("font_size", 18)
    train_button.pressed.connect(func() -> void: operation._queue_reinforcement())
    column.add_child(train_button)
    cancel_button = Button.new()
    cancel_button.text = "ОТМЕНИТЬ ПОСЛЕДНИЙ  ·  +100"
    cancel_button.custom_minimum_size.y = 42
    cancel_button.add_theme_font_size_override("font_size", 15)
    cancel_button.pressed.connect(func() -> void: operation._cancel_reinforcement())
    column.add_child(cancel_button)
    var hint := Label.new()
    hint.text = "Подкрепление идёт к точке сбора.\nДальние тайники дают дополнительные ресурсы."
    hint.add_theme_font_size_override("font_size", 13)
    column.add_child(hint)
    refresh()

func _process(delta: float) -> void:
    refresh_age += delta
    if visible and refresh_age >= 0.1:
        refresh_age = 0.0
        refresh()

func refresh() -> void:
    if operation == null:
        return
    var work = operation._factory_work()
    title.text = "%s · %d" % [operation.construction.building_title(operation.active_factory), operation.active_factory["id"]]
    balance_label.text = "РЕСУРСЫ: %d  ·  ВЫПУЩЕНО: %d\nОБЗОР: %d" % [work.balance, work.completed,
        int(operation.construction.sight_radius(operation.active_factory))]
    var remaining: float = 0.0 if work.pending.is_empty() else work.pending[0]
    queue_label.text = "ОЧЕРЕДЬ: %d/%d  ·  %s" % [work.pending.size(), work.QUEUE_LIMIT,
        "НЕТ ПИТАНИЯ" if not operation.active_factory.get("powered", false) else
        ("ВЫХОД ЗАНЯТ" if work.exit_blocked else ("%d с" % ceili(remaining) if not work.pending.is_empty() else "ГОТОВ"))]
    progress.value = 0.0 if work.pending.is_empty() else 100.0 * (1.0 - remaining / work.BUILD_SECONDS)
    train_button.text = "%s  ·  %d  /  %d с" % [operation._reinforcement_name(), work.UNIT_COST, int(work.BUILD_SECONDS)]
    train_button.disabled = not work.enabled or work.balance < work.UNIT_COST or work.pending.size() >= work.QUEUE_LIMIT
    cancel_button.disabled = not work.enabled or work.pending.is_empty()
