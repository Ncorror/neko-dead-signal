extends Control
## First screen: faction and officer selection, no networking yet.

const FACTIONS := ["Люди — флот «Рэйна»", "Саари — Звёздный Конклав"]
const OFFICERS := [
    ["Мира Кейд — инженер", "Лира Восс — разведчица"],
    ["Сэйра Нэл — следопыт", "Оралин — тактик"]
]

var faction_index: int = 0
var officer_index: int = 0
var officer_selector: OptionButton
var status_label: Label

func _ready() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color("#0b1521")
    add_child(backdrop)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var margin := MarginContainer.new()
    add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 18)
    margin.add_child(layout)

    var heading := Label.new()
    heading.text = "REINA: DEAD SIGNAL"
    heading.add_theme_font_size_override("font_size", 30)
    layout.add_child(heading)

    var subtitle := Label.new()
    subtitle.text = "RTS Prototype · выбираем цивилизацию и офицера"
    layout.add_child(subtitle)

    layout.add_child(_caption("Цивилизация"))
    var faction_selector := OptionButton.new()
    faction_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for title in FACTIONS:
        faction_selector.add_item(title)
    faction_selector.item_selected.connect(_on_faction_selected)
    layout.add_child(faction_selector)

    layout.add_child(_caption("Офицер для высадки"))
    officer_selector = OptionButton.new()
    officer_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    officer_selector.item_selected.connect(_on_officer_selected)
    layout.add_child(officer_selector)

    var confirm_button := Button.new()
    confirm_button.text = "Подтвердить состав десанта"
    confirm_button.pressed.connect(_on_confirm_pressed)
    layout.add_child(confirm_button)

    var deploy_button := Button.new()
    deploy_button.text = "Тестовая высадка на планету"
    deploy_button.pressed.connect(_on_deploy_pressed)
    layout.add_child(deploy_button)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(status_label)

    _refresh_officers()
    status_label.text = "Выбери офицера — он будет доступен с начала будущего боя."

func _caption(value: String) -> Label:
    var label := Label.new()
    label.text = value
    return label

func _on_faction_selected(index: int) -> void:
    faction_index = index
    officer_index = 0
    _refresh_officers()

func _on_officer_selected(index: int) -> void:
    officer_index = index

func _refresh_officers() -> void:
    officer_selector.clear()
    for officer in OFFICERS[faction_index]:
        officer_selector.add_item(officer)
    officer_selector.select(0)
    status_label.text = "Выбери офицера. Боевые сцены пока не реализованы."

func _on_confirm_pressed() -> void:
    var faction: String = FACTIONS[faction_index]
    var officer: String = OFFICERS[faction_index][officer_index]
    status_label.text = "Выбрано: %s | %s. Следующий этап — высадка." % [faction, officer]

func _on_deploy_pressed() -> void:
    GameState.configure(faction_index, officer_index, FACTIONS[faction_index], OFFICERS[faction_index][officer_index])
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
