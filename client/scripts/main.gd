extends Control
## Mobile-first orbital command deck. Functional selection and local 3D deployment.
## Textures/models are deliberately placeholders pending our original Meshy assets.

const HOLOGRAM := preload("res://scripts/command_visuals.gd")
const DIAGNOSTICS_UI := preload("res://scripts/rts_diagnostics_ui.gd")
const COMMANDER_3D := preload("res://scripts/commander_3d_preview.gd")
const BG := Color("#050f18")
const PANEL := Color("#071a25")
const EDGE := Color("#204351")
const CYAN := Color("#5cdee8")
const MUTED := Color("#849ba8")
const WHITE := Color("#eaf7fc")

const FACTIONS := [
    {
        "name": "ЛЮДИ",
        "full": "Люди — флот «Рэйна»",
        "fleet": "ЭКСПЕДИЦИОННЫЙ ФЛОТ",
        "hint": "Технологии, экспедиция и штурмовые платформы.",
        "color": Color("#5cdee8")
    },
    {
        "name": "СААРИ",
        "full": "Саари — Звёздный Конклав",
        "fleet": "ЗВЁЗДНЫЙ КОНКЛАВ",
        "hint": "Разведка, энергетические системы и манёвренность.",
        "color": Color("#c4a1ff")
    }
]
const OFFICERS := [
    [
        {
            "name": "АМИНА",
            "full": "Амина — разведка и дроны",
            "role": "РАЗВЕДКА / ДРОНЫ",
            "bio": "Кошачьи наушники, лёгкая экспедиционная экипировка. Находит скрытые ресурсы и ведёт дроны.",
            "perk": "ОРБИТАЛЬНОЕ СКАНИРОВАНИЕ",
            "call": "E-03"
        },
        {
            "name": "РЭЙНА",
            "full": "Рэйна — командование",
            "role": "КОМАНДОВАНИЕ / КООРДИНАЦИЯ",
            "bio": "Командир десантной группы. Координирует строй, тактическую связь и поддержку отрядов.",
            "perk": "ТАКТИЧЕСКИЙ ПРИКАЗ",
            "call": "E-04"
        },
        {
            "name": "МИРА КЕЙД",
            "full": "Мира Кейд — инженер",
            "role": "ИНЖЕНЕР / ПОДДЕРЖКА",
            "bio": "Техник экспедиции. Первая выходит на поверхность, восстанавливает узлы и ведёт десант.",
            "perk": "ПОЛЕВОЙ РЕМОНТ",
            "call": "E-01"
        },
        {
            "name": "ЛИРА ВОСС",
            "full": "Лира Восс — снайпер-разведчик",
            "role": "СНАЙПЕР / РАЗВЕДКА",
            "bio": "Снайпер-разведчик экспедиции. Дальняя поддержка из подготовленной позиции — её будущая специализация.",
            "perk": "ПОДГОТОВЛЕННАЯ ПОЗИЦИЯ",
            "call": "E-02"
        }
    ],
    [
        {
            "name": "СЭЙРА НЭЛ",
            "full": "Сэйра Нэл — следопыт",
            "role": "РАЗВЕДКА / МОБИЛЬНОСТЬ",
            "bio": "Командир передовых групп Саари. Проводит отряды через опасные участки.",
            "perk": "СКРЫТЫЙ МАРШРУТ",
            "call": "S-01"
        },
        {
            "name": "ОРАЛИН",
            "full": "Оралин — тактик",
            "role": "ТАКТИКА / КООРДИНАЦИЯ",
            "bio": "Офицер Конклава. Управляет разведывательными звеньями и распределяет силы.",
            "perk": "ТАКТИЧЕСКАЯ СВЯЗЬ",
            "call": "S-02"
        }
    ]
]

var faction_index: int = 0
var officer_index: int = 0
var faction_buttons: Array[Button] = []
var officer_buttons: Array[Button] = []
var hero_visual: Control
var hero_portrait: TextureRect
var hero_preview_3d: SubViewportContainer
var portrait_cache: Dictionary = {}
var officer_scroll: ScrollContainer
var hero_name: Label
var hero_role: Label
var hero_bio: Label
var hero_perk: Label
var hero_call: Label
var faction_details: Label
var selected_fleet: Label
var cta: Button
var close_button: Button
var exit_dialog: ConfirmationDialog

func _ready() -> void:
    faction_index = clampi(GameState.faction_index, 0, FACTIONS.size() - 1)
    officer_index = clampi(GameState.officer_index, 0, OFFICERS[faction_index].size() - 1)
    _build_screen()
    _refresh_selection()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("ui", "orbital_open", {"faction": faction_index, "officer": officer_index})
    call_deferred("_reveal_selected_officer")

func _build_screen() -> void:
    var background := HOLOGRAM.new()
    background.mode = 0
    add_child(background)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var tint := ColorRect.new()
    tint.color = Color(0.01, 0.055, 0.085, 0.15)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tint)
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var margins := MarginContainer.new()
    margins.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(margins)
    margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margins.add_theme_constant_override("margin_left", 28)
    margins.add_theme_constant_override("margin_right", 28)
    margins.add_theme_constant_override("margin_top", 18)
    margins.add_theme_constant_override("margin_bottom", 17)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 15)
    margins.add_child(root)
    _build_exit_dialog()
    _build_header(root)
    _build_content(root)
    _build_footer(root)

func _build_exit_dialog() -> void:
    exit_dialog = ConfirmationDialog.new()
    exit_dialog.title = "Выход из игры"
    exit_dialog.dialog_text = "Завершить игру?"
    exit_dialog.ok_button_text = "Выйти"
    exit_dialog.cancel_button_text = "Остаться"
    exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
    add_child(exit_dialog)

func _confirm_exit() -> void:
    exit_dialog.popup_centered(Vector2i(420, 180))

func _handle_back() -> void:
    for child in get_children():
        if child.get_script() == DIAGNOSTICS_UI and child.popup != null and child.popup.visible:
            child.popup.hide()
            return
    if exit_dialog.visible:
        exit_dialog.hide()
    else:
        _confirm_exit()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and exit_dialog != null:
        _handle_back()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _handle_back()
        get_viewport().set_input_as_handled()

func _build_header(parent: VBoxContainer) -> void:
    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 82
    header.add_theme_constant_override("separation", 20)
    parent.add_child(header)

    var brand := VBoxContainer.new()
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.add_theme_constant_override("separation", 0)
    header.add_child(brand)
    brand.add_child(_label("REINA: DEAD SIGNAL", 29, WHITE, true))
    brand.add_child(_label("ORBITAL COMMAND  /  ПРЕДВАРИТЕЛЬНЫЙ ПРОТОТИП", 12, CYAN))

    var status := VBoxContainer.new()
    status.alignment = BoxContainer.ALIGNMENT_CENTER
    header.add_child(status)
    status.add_child(_label("●  ЛОКАЛЬНАЯ СЕССИЯ", 13, Color("#a5d5cb")))
    status.add_child(_label("Серверный бой ещё не подключён", 11, MUTED))

    close_button = _button("ВЫХОД", false, 52)
    close_button.custom_minimum_size = Vector2(112, 52)
    close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    close_button.pressed.connect(_confirm_exit)
    if RTSDiagnostics.enabled:
        var debug_panel := DIAGNOSTICS_UI.new()
        add_child(debug_panel)
        debug_panel.install(self, header)
    header.add_child(close_button)

func _build_content(parent: VBoxContainer) -> void:
    var row := HBoxContainer.new()
    row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 17)
    parent.add_child(row)

    var left := _panel(row, 304)
    left.add_child(_label("01   /   СТОРОНА КОНФЛИКТА", 13, CYAN))
    left.add_child(_label("ВЫБЕРИ РАСУ", 22, WHITE, true))
    for i in range(FACTIONS.size()):
        var b := _button("", false, 72)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(_select_faction.bind(i))
        faction_buttons.append(b)
        left.add_child(b)
    faction_details = _label("", 13, MUTED)
    faction_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    faction_details.custom_minimum_size.y = 42
    left.add_child(faction_details)
    left.add_child(_rule())
    left.add_child(_label("02   /   КОМАНДИР ДЕСАНТА", 13, CYAN))
    var roster_controls := HBoxContainer.new()
    roster_controls.add_theme_constant_override("separation", 8)
    left.add_child(roster_controls)
    var previous := _button("◀ ПРЕД.", false, 38)
    previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    previous.pressed.connect(_change_officer.bind(-1))
    roster_controls.add_child(previous)
    var next := _button("СЛЕД. ▶", false, 38)
    next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next.pressed.connect(_change_officer.bind(1))
    roster_controls.add_child(next)
    officer_scroll = ScrollContainer.new()
    var scroll := officer_scroll
    scroll.custom_minimum_size = Vector2(0, 136)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
    scroll.follow_focus = true
    scroll.scroll_deadzone = 7
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    left.add_child(scroll)
    var officer_list := VBoxContainer.new()
    officer_list.add_theme_constant_override("separation", 6)
    officer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(officer_list)
    for i in range(OFFICERS[0].size()):
        var b := _button("", false, 51)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.pressed.connect(_select_officer.bind(i))
        officer_buttons.append(b)
        officer_list.add_child(b)
    left.add_child(_label("Командир высаживается вместе с первым десантом.", 12, MUTED, false, true))

    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 1)
    row.add_child(center)

    center.add_child(_label("ДОСЬЕ КОМАНДИРА  /  ПОВОРОТ СВАЙПОМ", 13, Color("#a8d6df")))
    var portrait_holder := Control.new()
    portrait_holder.custom_minimum_size = Vector2(245, 280)
    portrait_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    portrait_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(portrait_holder)

    hero_visual = HOLOGRAM.new()
    hero_visual.mode = 1
    hero_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait_holder.add_child(hero_visual)
    hero_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    hero_portrait = TextureRect.new()
    hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hero_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero_portrait.visible = false
    portrait_holder.add_child(hero_portrait)
    hero_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hero_preview_3d = COMMANDER_3D.new()
    portrait_holder.add_child(hero_preview_3d)
    hero_preview_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    hero_name = _label("", 27, WHITE, true)
    hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(hero_name)
    hero_role = _label("", 13, CYAN)
    hero_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(hero_role)
    center.add_child(_gap(10))
    hero_call = _label("", 12, MUTED)
    hero_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center.add_child(hero_call)

    var right := _panel(row, 338)
    right.add_child(_label("03   /   ПАРАМЕТРЫ ВЫСАДКИ", 13, CYAN))
    right.add_child(_label("ОПЕРАЦИЯ 001", 24, WHITE, true))
    right.add_child(_label("НЕИЗВЕДАННАЯ ПЛАНЕТА", 13, Color("#95c7d5")))
    right.add_child(_rule())
    right.add_child(_label("ФЛОТИЛИЯ", 12, MUTED))
    selected_fleet = _label("", 16, WHITE)
    right.add_child(selected_fleet)
    right.add_child(_label("ПРОФИЛЬ КОМАНДИРА", 12, MUTED))
    hero_bio = _label("", 14, WHITE)
    hero_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_bio.custom_minimum_size.y = 70
    right.add_child(hero_bio)
    right.add_child(_label("СПЕЦИАЛИЗАЦИЯ · В РАЗРАБОТКЕ", 12, MUTED))
    hero_perk = _label("", 15, CYAN, true)
    right.add_child(hero_perk)
    right.add_child(_stretch())
    right.add_child(_rule())
    if GameState.last_report.is_empty():
        right.add_child(_label("ЗАДАЧА ДЕСАНТА", 12, CYAN))
        right.add_child(_label("Собери три припаса, захвати два узла и разверни добычу с энергетикой. Уничтожь охрану.", 13, WHITE, false, true))
    else:
        right.add_child(_label("ИТОГ ПОСЛЕДНЕЙ ВЫСАДКИ", 12, CYAN))
        right.add_child(_label(GameState.last_report, 13, WHITE, false, true))
    cta = _button("НАЧАТЬ ВЫСАДКУ    ›", true, 67)
    cta.pressed.connect(_deploy)
    right.add_child(cta)

func _build_footer(parent: VBoxContainer) -> void:
    var line := _rule()
    parent.add_child(line)
    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 12)
    parent.add_child(footer)
    footer.add_child(_label("REINA SYSTEMS  /  ОБЩИЙ ЭКСПЕДИЦИОННЫЙ ФЛОТ", 11, MUTED))
    footer.add_child(_stretch_horizontal())
    footer.add_child(_label("ANDROID  •  PRE-ALPHA %s  •  BASE RECONNAISSANCE" % ProjectSettings.get_setting("application/config/version", "dev"), 11, Color("#87b2bf")))

func _panel(parent: HBoxContainer, minimum_width: float) -> VBoxContainer:
    var outer := PanelContainer.new()
    outer.custom_minimum_size.x = minimum_width
    outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var panel_style := _style(Color(0.015, 0.09, 0.125, 0.88), Color("#2a5864"), 1)
    panel_style.set_content_margin_all(0.0)
    outer.add_theme_stylebox_override("panel", panel_style)
    parent.add_child(outer)
    var inset := MarginContainer.new()
    for side in ["left", "top", "right", "bottom"]:
        inset.add_theme_constant_override("margin_" + side, 18)
    outer.add_child(inset)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 6)
    inset.add_child(body)
    return body

func _style(background: Color, border: Color, border_size: int = 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(border_size)
    style.set_corner_radius_all(6)
    style.content_margin_left = 13.0
    style.content_margin_right = 13.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style

func _button(caption: String, primary: bool = false, min_height: float = 56.0) -> Button:
    var b := Button.new()
    b.text = caption
    b.clip_text = true
    b.custom_minimum_size.y = min_height
    b.add_theme_font_size_override("font_size", 16 if primary else 14)
    b.add_theme_color_override("font_color", Color("#06202a") if primary else WHITE)
    b.add_theme_color_override("font_hover_color", Color("#081c23") if primary else Color("#ffffff"))
    b.add_theme_color_override("font_pressed_color", Color("#051721") if primary else WHITE)
    b.add_theme_stylebox_override("normal", _style(CYAN if primary else Color("#102b38"), CYAN if primary else EDGE))
    b.add_theme_stylebox_override("hover", _style(Color("#a0edf1") if primary else Color("#1a4754"), CYAN, 2))
    b.add_theme_stylebox_override("pressed", _style(Color("#3cbfc8") if primary else Color("#275465"), CYAN, 2))
    b.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, CYAN, 2))
    return b

func _label(caption: String, font_size: int, color: Color, strong: bool = false, wrap: bool = false) -> Label:
    var l := Label.new()
    l.text = caption
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
    if strong:
        l.add_theme_constant_override("outline_size", 1)
        l.add_theme_color_override("font_outline_color", Color("#081522"))
    return l

func _rule() -> ColorRect:
    var line := ColorRect.new()
    line.color = EDGE
    line.custom_minimum_size.y = 1
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return line

func _gap(height: float) -> Control:
    var gap := Control.new()
    gap.custom_minimum_size.y = height
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return gap

func _stretch() -> Control:
    var gap := Control.new()
    gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return gap

func _stretch_horizontal() -> Control:
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return gap

func _select_faction(i: int) -> void:
    if i < 0 or i >= FACTIONS.size():
        return
    if faction_index != i:
        faction_index = i
        officer_index = clampi(GameState.officers_by_faction[i], 0, OFFICERS[i].size() - 1)
    _store_selected_commander()
    _refresh_selection()
    call_deferred("_reveal_selected_officer")

func _change_officer(direction: int) -> void:
    var count: int = OFFICERS[faction_index].size()
    if count > 0:
        _select_officer(posmod(officer_index + direction, count))

func _select_officer(i: int) -> void:
    if i < 0 or i >= OFFICERS[faction_index].size():
        return
    officer_index = i
    _store_selected_commander()
    _refresh_selection()
    call_deferred("_reveal_selected_officer")

func _store_selected_commander() -> void:
    var faction: Dictionary = FACTIONS[faction_index]
    var officer: Dictionary = OFFICERS[faction_index][officer_index]
    GameState.set_selection(faction_index, officer_index, faction["full"], officer["full"])
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("commander", "selected", {"faction": faction_index, "officer": officer_index})

func _reveal_selected_officer() -> void:
    if officer_scroll != null and officer_index < officer_buttons.size():
        officer_scroll.ensure_control_visible(officer_buttons[officer_index])

func _refresh_selection() -> void:
    var faction: Dictionary = FACTIONS[faction_index]
    var officer: Dictionary = OFFICERS[faction_index][officer_index]
    for i in range(faction_buttons.size()):
        var active: bool = i == faction_index
        var f: Dictionary = FACTIONS[i]
        var b := faction_buttons[i]
        b.text = ("◆   " if active else "◇   ") + f["name"] + "\n      " + f["fleet"]
        b.add_theme_stylebox_override("normal", _style(Color("#183843") if active else Color("#0a2530"), f["color"] if active else EDGE, 2 if active else 1))
        b.add_theme_color_override("font_color", f["color"] if active else WHITE)
        b.add_theme_font_size_override("font_size", 14)
    for i in range(officer_buttons.size()):
        var b := officer_buttons[i]
        b.visible = i < OFFICERS[faction_index].size()
        if not b.visible:
            continue
        var active: bool = i == officer_index
        var p: Dictionary = OFFICERS[faction_index][i]
        b.text = ("◆   " if active else "◇   ") + p["name"] + "\n      " + p["role"]
        b.add_theme_stylebox_override("normal", _style(Color("#183843") if active else Color("#0a2530"), faction["color"] if active else EDGE, 2 if active else 1))
        b.add_theme_color_override("font_color", faction["color"] if active else WHITE)

    faction_details.text = faction["hint"]
    hero_visual.faction_index = faction_index
    hero_visual.officer_index = officer_index
    hero_visual.queue_redraw()
    _update_portrait()
    hero_name.text = officer["name"]
    hero_role.text = officer["role"]
    hero_bio.text = officer["bio"]
    hero_perk.text = officer["perk"]
    hero_perk.add_theme_color_override("font_color", faction["color"])
    hero_call.text = "ID: " + officer["call"] + "    •    ОФИЦЕР ГОТОВ"
    selected_fleet.text = faction["fleet"]
    cta.add_theme_stylebox_override("normal", _style(faction["color"], faction["color"]))
    cta.add_theme_stylebox_override("hover", _style(faction["color"].lightened(0.2), faction["color"], 2))

func _update_portrait() -> void:
    var has_3d: bool = hero_preview_3d.set_commander(faction_index, officer_index)
    hero_visual.visible = not has_3d
    if has_3d:
        hero_portrait.visible = false
        return
    var portrait_id := ""
    if faction_index == 0:
        var portraits := ["amina", "reina", "mira_kade", "lyra_voss"]
        portrait_id = portraits[officer_index]
    # The Saari portraits have not been approved or generated yet.
    if portrait_id.is_empty():
        hero_portrait.visible = false
        return
    if not portrait_cache.has(portrait_id):
        var asset_path := "res://assets/portraits/" + portrait_id + ".jpg.b64"
        if not FileAccess.file_exists(asset_path):
            portrait_cache[portrait_id] = null
        else:
            var encoded := FileAccess.get_file_as_string(asset_path).replace("\n", "").replace("\r", "").strip_edges()
            var bytes := Marshalls.base64_to_raw(encoded)
            var img := Image.new()
            var error := img.load_jpg_from_buffer(bytes)
            if error != OK:
                push_warning("RTS_PORTRAIT_LOAD_FAILED id=" + portrait_id + " error=" + str(error))
                if RTSDiagnostics.enabled:
                    RTSDiagnostics.event("error", "portrait_decode_failed", {"id": portrait_id, "error": error})
                portrait_cache[portrait_id] = null
            else:
                portrait_cache[portrait_id] = ImageTexture.create_from_image(img)
    var picture: Texture2D = portrait_cache[portrait_id]
    hero_portrait.texture = picture
    hero_portrait.visible = picture != null

func _deploy() -> void:
    var faction: Dictionary = FACTIONS[faction_index]
    var officer: Dictionary = OFFICERS[faction_index][officer_index]
    GameState.configure(faction_index, officer_index, faction["full"], officer["full"])
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("app", "deploy", {"faction": faction_index, "officer": officer_index})
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
