extends Node
## Selected commander is live state across scene changes and persisted across app restarts.
const SELECTION_FILE := "user://commander_selection.cfg"

var faction_index: int = 0
var officer_index: int = 0
var faction_name: String = "Люди — флот «Рэйна»"
var officer_name: String = "Амина — штурмовой ДД"
var last_report := ""
var officers_by_faction: Array[int] = [0, 0]
var world_progress_path := "user://world/progress-v1.json"
var surface_progress_path := "user://surface/sector01-v1.json"

func _ready() -> void:
    var cfg := ConfigFile.new()
    var err := cfg.load(SELECTION_FILE)
    if err == ERR_FILE_NOT_FOUND:
        return
    if err != OK:
        push_warning("RTS_SELECTION_LOAD_FAILED error=" + str(err))
        return
    faction_index = clampi(int(cfg.get_value("commander", "faction", 0)), 0, 1)
    officers_by_faction[0] = clampi(int(cfg.get_value("commander", "human", 0)), 0, 3)
    officers_by_faction[1] = clampi(int(cfg.get_value("commander", "saari", 0)), 0, 1)
    officer_index = officers_by_faction[faction_index]
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("commander", "selection_restored", {"faction": faction_index, "officer": officer_index})

func set_selection(next_faction_index: int, next_officer_index: int, next_faction_name: String, next_officer_name: String) -> void:
    faction_index = clampi(next_faction_index, 0, 1)
    officer_index = clampi(next_officer_index, 0, 3 if faction_index == 0 else 1)
    officers_by_faction[faction_index] = officer_index
    faction_name = next_faction_name
    officer_name = next_officer_name
    var cfg := ConfigFile.new()
    cfg.set_value("commander", "faction", faction_index)
    cfg.set_value("commander", "human", officers_by_faction[0])
    cfg.set_value("commander", "saari", officers_by_faction[1])
    var err := cfg.save(SELECTION_FILE)
    if err != OK:
        push_warning("RTS_SELECTION_SAVE_FAILED error=" + str(err))
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("commander", "selection_saved", {"faction": faction_index, "officer": officer_index})

func configure(next_faction_index: int, next_officer_index: int, next_faction_name: String, next_officer_name: String) -> void:
    set_selection(next_faction_index, next_officer_index, next_faction_name, next_officer_name)
