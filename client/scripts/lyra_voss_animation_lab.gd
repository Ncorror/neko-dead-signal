extends Control
## Preview imported Lyra animation tracks without controlling RTS gameplay.
const PREVIEW := preload("res://scripts/commander_3d_preview.gd")
const LYRA := preload("res://scripts/lyra_voss_animations.gd")

var model_view: SubViewportContainer
var player: AnimationPlayer
var status: Label
var entries: VBoxContainer
var preview_origin := Vector3.ZERO
var timeline: HSlider
var time_label: Label
var pause_button: Button
var weapon_button: Button
var selected_clip := ""
var paused := false
var weapon_in_hand := false
var playback_speed := 1.0

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
    model_view.custom_minimum_size = Vector2(320, 220)
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
    var transport := HBoxContainer.new()
    root.add_child(transport)
    pause_button = _button("ПАУЗА", 44)
    pause_button.pressed.connect(_toggle_pause)
    transport.add_child(pause_button)
    for direction in [-1, 1]:
        var step := _button("− КАДР" if direction < 0 else "+ КАДР", 44)
        step.pressed.connect(_step.bind(direction))
        transport.add_child(step)
    var speed := OptionButton.new()
    for caption in ["0,25×", "0,5×", "1×"]:
        speed.add_item(caption)
    speed.select(2)
    speed.item_selected.connect(_set_speed)
    transport.add_child(speed)
    weapon_button = _button("ОРУЖИЕ: СПИНА", 44)
    weapon_button.pressed.connect(_toggle_weapon)
    transport.add_child(weapon_button)
    time_label = _label("0,00 / 0,00 с", 14)
    transport.add_child(time_label)
    timeline = HSlider.new()
    timeline.custom_minimum_size.y = 32
    timeline.step = 0.001
    timeline.editable = false
    timeline.value_changed.connect(_scrub)
    root.add_child(timeline)
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
    var clips := LYRA.review_clips(player)
    for clip in clips:
        var b := _button(str(clip).replace("_", " "), 42)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.disabled = LYRA.resolve_clip(player, str(clip)).is_empty()
        b.pressed.connect(_play.bind(str(clip)))
        entries.add_child(b)
    preview_origin = model_view.active_model.position
    status.text = "Загружено %d анимаций · исходных %d / 20" % [clips.size(), LYRA.loaded_count(player)]
    _hold()

func _hold() -> void:
    if model_view != null and model_view.active_model != null:
        model_view.active_model.position = preview_origin
    if player != null and LYRA.restore_ready(player):
        selected_clip = ""
        paused = true
        weapon_in_hand = LYRA.has_authored_rifle(player)
        weapon_button.text = "ОРУЖИЕ: КИСТЬ" if weapon_in_hand else "ОРУЖИЕ: СПИНА"
        timeline.editable = false
        timeline.set_value_no_signal(0)
        time_label.text = "—"
        pause_button.text = "ПУСК"
        status.text = "Авторская Rifle_Ready · preview, требуется проверка на Android." if weapon_in_hand else "Временная стойка из Walking; ноги сброшены в rest. Не авторский idle."

func _play(clip: String) -> void:
    if model_view != null and model_view.active_model != null:
        model_view.active_model.position = preview_origin
    if player != null:
        if LYRA.play_preview(player, clip):
            selected_clip = clip
            paused = false
            player.speed_scale = playback_speed
            player.seek(0.0, true)
            timeline.max_value = player.current_animation_length
            timeline.editable = true
            pause_button.text = "ПАУЗА"
            status.text = "Проигрывается: " + clip
            _update_pose_display()
        else:
            status.text = "Отсутствует: " + clip

func _process(_delta: float) -> void:
    if player == null or model_view == null or model_view.active_model == null:
        return
    if str(player.get_meta("neko_lyra_motion", "")) != "preview":
        return
    if not player.is_playing():
        paused = true
        pause_button.text = "ПУСК"
    _update_pose_display()

func _update_pose_display() -> void:
    if player == null or selected_clip.is_empty():
        return
    timeline.set_value_no_signal(player.current_animation_position)
    time_label.text = "%.2f / %.2f с" % [player.current_animation_position, player.current_animation_length]
    var offset: Vector3 = LYRA.root_motion_offset(player)
    var model: Node3D = model_view.active_model
    model.position = Vector3(
        preview_origin.x - offset.x * model.scale.x,
        preview_origin.y,
        preview_origin.z - offset.z * model.scale.z
    )

func _toggle_pause() -> void:
    if player == null or selected_clip.is_empty():
        return
    if player.is_playing():
        player.pause()
        paused = true
    else:
        var at := player.current_animation_position
        player.play()
        if at >= player.current_animation_length:
            player.seek(0.0, true)
        paused = false
    pause_button.text = "ПУСК" if paused else "ПАУЗА"

func _scrub(seconds: float) -> void:
    if player == null or selected_clip.is_empty():
        return
    player.pause()
    player.seek(clampf(seconds, 0.0, player.current_animation_length), true)
    paused = true
    pause_button.text = "ПУСК"
    _update_pose_display()

func _step(direction: int) -> void:
    if player != null and not selected_clip.is_empty():
        _scrub(player.current_animation_position + float(direction) / 30.0)

func _set_speed(index: int) -> void:
    playback_speed = [0.25, 0.5, 1.0][index]
    if player != null:
        player.speed_scale = playback_speed

func _toggle_weapon() -> void:
    if player == null:
        return
    var ok := LYRA.stow_weapon(player) if weapon_in_hand else LYRA.ready_weapon(player)
    if ok:
        weapon_in_hand = not weapon_in_hand
        weapon_button.text = "ОРУЖИЕ: КИСТЬ" if weapon_in_hand else "ОРУЖИЕ: СПИНА"
        status.text = "Крепление к правой кисти — проверка клипа, не готовый двухручный хват." if weapon_in_hand else "Оружие за спиной."


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
