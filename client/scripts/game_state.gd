extends Node
## Lightweight state passed from the orbital selection screen to a local prototype.
var faction_index: int = 0
var officer_index: int = 0
var faction_name: String = "Люди — флот «Рэйна»"
var officer_name: String = "Амина — разведка и дроны"
var last_report := ""

func configure(next_faction_index: int, next_officer_index: int, next_faction_name: String, next_officer_name: String) -> void:
    faction_index = next_faction_index
    officer_index = next_officer_index
    faction_name = next_faction_name
    officer_name = next_officer_name
