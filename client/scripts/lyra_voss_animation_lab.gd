extends Control
## Preview imported Lyra animation tracks without controlling RTS gameplay.
const PREVIEW := preload("res://scripts/commander_3d_preview.gd")
const LYRA := preload("res://scripts/lyra_voss_animations.gd")

var model_view: SubViewportContainer
var player: AnimationPlayer
var status: Label
var entries: VBoxContainer

func _ready() -> void:
    var background := ColorRect.new()
    background.color = Color("#07151e")
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var margins := MarginContainer.new()
    add_child(margins)
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 15)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    margins.add_child(root)
    var header := HBoxContainer.new()
    root.add_child(header)
    var back := _button("◀ НАЗАД", 48)
    back.pressed.connect(_back)
    header.add_child(back)
    var title := _label("ЛИРА ВОСС · АНИМАЦИИ", 23)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_child(title)
    var idle := _button("СТОЙКА", 48)
    idle.pressed.connect(_hold)
    header.add_child(idle)
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation", 10)
    root.add_child(columns)
    var model_frame := PanelContainer.new()
    model_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    model_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_child(model_frame)
    model_view = PREVIEW.new()
    model_view.custom_minimum_size = Vector2(320, 330)
    model_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    model_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    model_frame.add_child(model_view)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size.x = 305
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_child(scroll)
    entries = VBoxContainer.new()
    entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(entries)
    status = _label("Загрузка модели…", 14)
    root.add_child(status)
    root.add_child(_label("Поверни модель пальцем. Часть боевых клипов содержит перемещение скелета.", 12))
    call_deferred("_load")

func _load() -> void:
    if not model_view.set_commander(0, 3):
        status.text = "Лира GLB отсутствует в этой сборке."
        return
    player = LYRA.find_player(model_view.active_model)
    if player == null:
        status.text = "AnimationPlayer не найден."
        return
    for clip in LYRA.CLIP_NAMES:
        var b := _button(str(clip).replace("_", " "), 42)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.disabled = LYRA.resolve_clip(player, str(clip)).is_empty()
        b.pressed.connect(_play.bind(str(clip)))
        entries.add_child(b)
    status.text = "Загружено %d / 20 анимаций" % LYRA.loaded_count(player)
    _hold()

func _hold() -> void:
    if player != null and LYRA.hold_ready_pose(player):
        status.text = "Стойка: устойчивые ноги из Standing_Reload, руки из Walking."

func _play(clip: String) -> void:
    if player != null:
        if LYRA.play_preview(player, clip):
            status.text = "Проигрывается: " + clip
        else:
            status.text = "Отсутствует: " + clip

func _back() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
        _back()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _back()
        get_viewport().set_input_as_handled()

func _button(caption: String, height: float) -> Button:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size.y = height
    b.add_theme_font_size_override("font_size", 14)
    return b

func _label(caption: String, font_size: int) -> Label:
    var l := Label.new()
    l.text = caption
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", Color("#c9edf9"))
    return l
