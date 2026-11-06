extends "res://scripts/world_zone.gd"
## Separate walkable PvE area. No quest acceptance is needed to see or fight enemies.

const HUNT := preload("res://scripts/world_hunt.gd")
const RUINS := [
    [Vector3(-3, 0, 10), Vector3(4, 2.6, 7)],
    [Vector3(-19, 0, -3), Vector3(6, 3.4, 4)],
    [Vector3(1, 0, 1), Vector3(4, 1.7, 4)],
    [Vector3(17, 0, 12), Vector3(7, 2.2, 4)],
    [Vector3(-7, 0, -16), Vector3(4, 3.0, 7)],
    [Vector3(12, 0, -10), Vector3(5, 2.2, 3)]]

func world_state() -> Dictionary:
    var saved: Dictionary = progress.state()["hunt"]
    saved["camera_preset"] = PROGRESS.CAMERA_PRESET
    return saved

func combat_state() -> Dictionary:
    return progress.hunt_combat_state()

func make_combat_model():
    return HUNT.new()

func _create_world() -> void:
    var environment := WorldEnvironment.new()
    var sky := Environment.new()
    sky.background_mode = Environment.BG_COLOR
    sky.background_color = Color("#152127")
    sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    sky.ambient_light_color = Color("#c5d2d2")
    sky.ambient_light_energy = 0.8
    environment.environment = sky
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.1
    add_child(sun)
    _box(self, Vector3(0, -0.4, 0), Vector3(66, 0.4, 66), Color("#343d3d"))
    # Roads, lit camp pads and rusted structures provide landmarks without hiding enemies.
    _box(self, Vector3(-9, 0.01, 10), Vector3(5, 0.04, 35), Color("#4a4e49"))
    _box(self, Vector3(7, 0.015, -4), Vector3(35, 0.04, 4), Color("#4a4e49"))
    _box(self, Vector3(18, 0.01, -19), Vector3(13, 0.06, 13), Color("#60504a"))
    for item in RUINS:
        _box(self, item[0], item[1], Color("#67534b"))
        _box(self, item[0] + Vector3(0, item[1].y, 0), Vector3(item[1].x + 0.2, 0.12, item[1].z + 0.2), Color("#92725a"))
        navigation.set_blocked_box(item[0], item[1], 0.7)
    for i in range(17):
        var edge := -32.0 + i * 4
        for z in [-32.0, 32.0]:
            _box(self, Vector3(edge, 0, z), Vector3(2.8, 1.0 + (i % 3) * 0.5, 2), Color("#38474a"))
    for marker in [[Vector3(-10, 0, 4), "ЛАГЕРЬ МАРОДЁРОВ"],
            [Vector3(12, 0, 3), "ЗАНЯТЫЙ СКЛАД"], [Vector3(1, 0, -12), "ДОЗОР ДРОНОВ"],
            [Vector3(18, 0, -22), "СТРАЖ УЗЛА · БОСС"]]:
        var sign := Node3D.new()
        sign.position = marker[0] + Vector3(0, 0, -3)
        add_child(sign)
        _caption(sign, marker[1], 3.0)
    _box(self, COMBAT.SAFE_AT + Vector3(0, 0.02, 0), Vector3(11, 0.06, 11), Color("#3a6063"))
    npc = Node3D.new()
    npc.name = "OutpostGate"
    npc.position = NPC_AT
    add_child(npc)
    _box(npc, Vector3(-1.5, 0, 0), Vector3(0.35, 2.5, 0.35), Color("#70d8d5"))
    _box(npc, Vector3(1.5, 0, 0), Vector3(0.35, 2.5, 0.35), Color("#70d8d5"))
    _caption(npc, "В ФОРПОСТ\nБезопасная площадка", 3.4)
    for z in range(8, 0, -2):
        _box(self, Vector3(-13, 0.06, z), Vector3(0.12, 0.1, 0.6), Color("#e6b271"))
    _create_hero()
    _create_camera_and_marker()

func _create_ui() -> void:
    super._create_ui()
    zone_title.text = "СЕКТОР 02 · РЖАВЫЙ ТРАКТ"
    return_button.text = "В ФОРПОСТ"
    sector_button.hide()
    return_dialog.title = "Вернуться в форпост?"
    return_dialog.dialog_text = "Сохранятся ОЗ, откаты, награда и состояние лагерей."
    return_dialog.ok_button_text = "В ФОРПОСТ"
    combat_view.hint.text = "Враги уже в секторе. Коснись врага для атаки. «ПОКАЗАТЬ ЦЕЛЬ» — ближайший лагерь."

func _refresh() -> void:
    if status == null:
        return
    var claimed: bool = progress.state()["hunt"]["claimed"]
    status.text = "АМИНА · Опыт %d · Кредиты %d · Открытая PvE-зона" % [progress.experience(), progress.credits()]
    var alive := 0
    for enemy in combat_view.model.enemies:
        if enemy["hp"] > 0 and not enemy["boss"]:
            alive += 1
    quest_label.text = "ЛАГЕРЯ: %d/8 врагов · БОСС: %s · %s" % [alive,
        "В СЕКТОРЕ" if combat_view.model.alive(HUNT.BOSS) else "ПОВЕРЖЕН",
        "Первая награда получена: +200 опыта / +150 кредитов" if claimed else "Первая победа над боссом: +200 опыта / +150 кредитов"]

func _show_goal() -> void:
    var distance := INF
    focus = NPC_AT
    for enemy in combat_view.model.enemies:
        if enemy["hp"] <= 0:
            continue
        var current: float = hero.position.distance_to(enemy["at"])
        if current < distance:
            distance = current
            focus = enemy["at"]
    following = false
    preview_seconds = GOAL_PREVIEW_SECONDS

func _open_journal() -> void:
    journal.title = "Ржавый тракт · Мобы и босс"
    journal.dialog_text = "Три группы: лагерь мародёров севернее входа, занятый склад на востоке и дозор дронов на севере. Страж узла находится в северо-восточной части.\n\nКоснись врага — герой подойдёт и откроет огонь. Пять навыков Амины доступны сразу, поручение Веги не требуется.\n\nСильный импульс босса отмечается кругом на земле за 1,4 с. Выйди из круга касанием или рывком. При 40% ОЗ босс переходит в перегрузку. Импульсная граната снижает темп босса, не отменяя его подготовку.\n\nМобы возвращаются через 45 с, босс — через 120 с. Лагерь не появляется под героем; время вне игры заморожено.\nЗа первую победу над боссом: 200 опыта / 150 кредитов один раз. Повторные бои доступны без повторной награды.\n\nГолубая площадка у входа безопасна и восстанавливает ОЗ. Переходы не сбрасывают ОЗ или откаты."
    _popup(journal)

func _interact(target: int) -> void:
    if target == -1 and hero.position.distance_to(NPC_AT) <= 3:
        _request_return()

func _checkpoint() -> bool:
    if not progress.writable:
        save_label.text = progress.error_text
        return false
    var had_reward: bool = progress.state()["hunt"]["claimed"]
    var ok: bool = progress.checkpoint_sector(hero.position, zoom, combat_view.model.snapshot())
    save_label.text = "Прогресс сохранён." if ok else progress.error_text
    if ok and not had_reward and progress.state()["hunt"]["claimed"]:
        _event("boss_rewarded", {"xp": PROGRESS.BOSS_XP, "credits": PROGRESS.BOSS_CREDITS})
    if ok:
        _refresh()
    return ok

func _return_to_ship() -> void:
    if not _checkpoint():
        _show_notice(progress.error_text)
        return
    _event("sector_left", {"character": progress.character_id})
    get_tree().change_scene_to_file("res://scenes/world_zone.tscn")
