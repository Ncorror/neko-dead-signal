extends Control
## Editor-first player avatar screen. No gameplay rig or fabricated cosmetic controls.
const PREVIEW_SCRIPT := preload("res://scripts/avatar_static_preview.gd")
const PROFILE_STORE := preload("res://scripts/character_profile_store.gd")
const NAVY := Color("#07141e")
const PANEL := Color("#0d2230")
const CYAN := Color("#70d9e9")
const WHITE := Color("#e8f7fc")
const MUTED := Color("#93adba")

var avatar_preview: SubViewportContainer
var avatar_name: LineEdit
var saved_name: Label
var status_label: Label
var editor_panel: VBoxContainer
var inventory_panel: VBoxContainer
var editor_tab: Button
var inventory_tab: Button
var current_mode := 0

func _ready() -> void:
    _build_layout()
    var profile: Dictionary = PROFILE_STORE.load_profile()
    avatar_name.text = String(profile.get("name", ""))
    _set_mode(0)
    call_deferred("_report_avatar")

func _build_layout() -> void:
    var background := ColorRect.new()
    background.color = NAVY
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var margins := MarginContainer.new()
    add_child(margins)
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 18)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margins.add_child(column)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 14)
    column.add_child(header)
    var back := _button("◀ НАЗАД", 54)
    back.custom_minimum_size.x = 128
    back.pressed.connect(_back_to_menu)
    header.add_child(back)
    var branding := VBoxContainer.new()
    branding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(branding)
    branding.add_child(_label("NEKO: DEAD SIGNAL", 23, WHITE))
    branding.add_child(_label("СОЗДАНИЕ ПЕРСОНАЖА  /  ИНВЕНТАРЬ", 12, CYAN))

    var content := HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 16)
    column.add_child(content)

    var left := PanelContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(left)
    var model_column := VBoxContainer.new()
    model_column.add_theme_constant_override("separation", 6)
    left.add_child(model_column)
    model_column.add_child(_label("FEMALE BASE V3  /  3D MODEL", 14, CYAN))
    avatar_preview = PREVIEW_SCRIPT.new()
    avatar_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    avatar_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
    avatar_preview.custom_minimum_size = Vector2(320, 320)
    model_column.add_child(avatar_preview)
    model_column.add_child(_label("Повернуть: один палец  •  Приблизить: два пальца", 13, MUTED))

    var right := PanelContainer.new()
    right.custom_minimum_size.x = 320
    right.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(right)
    var options := VBoxContainer.new()
    options.add_theme_constant_override("separation", 12)
    right.add_child(options)
    options.add_child(_label("ПЕРСОНАЖ ИГРОКА", 21, WHITE))
    options.add_child(_label("Человеческая экспедиция", 13, MUTED))

    var tabs := HBoxContainer.new()
    options.add_child(tabs)
    editor_tab = _button("РЕДАКТОР", 48)
    editor_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor_tab.pressed.connect(_set_mode.bind(0))
    tabs.add_child(editor_tab)
    inventory_tab = _button("ИНВЕНТАРЬ", 48)
    inventory_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    inventory_tab.pressed.connect(_set_mode.bind(1))
    tabs.add_child(inventory_tab)

    editor_panel = VBoxContainer.new()
    editor_panel.add_theme_constant_override("separation", 10)
    options.add_child(editor_panel)
    editor_panel.add_child(_label("ИМЯ ПЕРСОНАЖА", 13, CYAN))
    avatar_name = LineEdit.new()
    avatar_name.placeholder_text = "Имя твоего героя"
    avatar_name.custom_minimum_size.y = 48
    editor_panel.add_child(avatar_name)
    editor_panel.add_child(_label("Базовая внешность: Female Base v3", 15, WHITE))
    editor_panel.add_child(_label("Стойка: естественная  •  Без анимаций", 13, MUTED))
    var save := _button("СОХРАНИТЬ ПРОФИЛЬ", 54)
    save.pressed.connect(_save_profile)
    editor_panel.add_child(save)

    inventory_panel = VBoxContainer.new()
    inventory_panel.add_theme_constant_override("separation", 10)
    options.add_child(inventory_panel)
    inventory_panel.add_child(_label("ЭКИПИРОВКА", 17, CYAN))
    saved_name = _label("", 15, WHITE)
    inventory_panel.add_child(saved_name)
    inventory_panel.add_child(_label("Комплект: базовая экспедиционная одежда", 14, WHITE))
    inventory_panel.add_child(_label("3D-просмотр использует ту же модель.", 13, MUTED))

    var reset := _button("СБРОСИТЬ КАМЕРУ", 46)
    reset.pressed.connect(func() -> void: avatar_preview.reset_view())
    options.add_child(reset)
    status_label = _label("", 13, MUTED)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    options.add_child(status_label)

func _set_mode(mode: int) -> void:
    current_mode = clampi(mode, 0, 1)
    editor_panel.visible = current_mode == 0
    inventory_panel.visible = current_mode == 1
    editor_tab.modulate = CYAN if current_mode == 0 else WHITE
    inventory_tab.modulate = CYAN if current_mode == 1 else WHITE
    if current_mode == 1:
        var profile: Dictionary = PROFILE_STORE.load_profile()
        saved_name.text = "Герой: " + String(profile.get("name", "не сохранён"))

func _report_avatar() -> void:
    if avatar_preview.active_model != null:
        status_label.text = "3D-модель загружена. Вращение и масштабирование доступны."
    else:
        status_label.text = "3D-модель отсутствует в этой сборке. Требуется asset editor_relaxed.glb."

func _save_profile() -> void:
    if PROFILE_STORE.save_profile(avatar_name.text):
        status_label.text = "Профиль сохранён."
    else:
        status_label.text = "Не удалось сохранить профиль. Проверь имя и хранилище."

func _back_to_menu() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
        _back_to_menu()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _back_to_menu()
        get_viewport().set_input_as_handled()

func _button(text: String, height: float) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size.y = height
    b.add_theme_font_size_override("font_size", 15)
    b.add_theme_color_override("font_color", WHITE)
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.border_color = Color("#356070")
    style.set_border_width_all(1)
    style.set_content_margin_all(9)
    b.add_theme_stylebox_override("normal", style)
    return b

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label
