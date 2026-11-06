extends Node
## Native travel and touch UI, then ordinary combat against every camp and the boss.

const STORE := preload("res://scripts/world_progress.gd")
const HUNT := preload("res://scripts/world_hunt.gd")
const COMBAT := preload("res://scripts/world_combat.gd")
const PATH := "user://world-sector-regression/progress.json"
var zone
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_SECTOR_TEST_FAIL " + message)

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _press(button: Button) -> void:
    _check(button.is_visible_in_tree() and button.get_viewport().get_visible_rect().encloses(button.get_global_rect()),
        "button clipped: " + button.text + " " + str(button.get_global_rect()))
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = button.get_global_rect().get_center()
        touch.pressed = down
        button.get_viewport().push_input(touch, true)

func _settle() -> void:
    for frame in range(10):
        await get_tree().process_frame
        if is_instance_valid(zone):
            zone._process(0)

func _adopt() -> void:
    await get_tree().scene_changed
    zone = get_tree().current_scene
    zone.set_physics_process(false)
    zone.set_process(false)
    await _settle()

func _advance(seconds: float) -> void:
    for frame in range(ceili(seconds * 60)):
        var before: Vector3 = zone.hero.position
        zone._physics_process(1.0 / 60)
        zone._process(1.0 / 60)
        _check(zone.navigation.has_walkable_segment(before, zone.hero.position), "hero crossed a ruin")
        _check(zone.combat_view.effects.size() <= 48, "effects exceeded their budget")

func _native_cast(skill: int, at: Vector3) -> bool:
    var pixel: Vector2 = zone.camera.unproject_position(at + Vector3.UP)
    if zone._over_ui(pixel) or zone.camera.is_position_behind(at):
        return false
    _press(zone.combat_view.skill_buttons[skill])
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = pixel
        touch.pressed = down
        zone.get_viewport().push_input(touch, true)
    if zone.combat_view.aim_skill >= 0:
        zone.combat_view.cancel_aim()
    return true

func _walk(at: Vector3, seconds: float = 20) -> void:
    _check(zone._move_to(at), "no route to " + str(at))
    _advance(seconds)
    _check(zone.hero.position.distance_to(at) <= 1.2 and zone.combat_view.model.hp > 0,
        "walk failed at=%s goal=%s hp=%s" % [zone.hero.position, at, zone.combat_view.model.hp])

func _fight(ids: Array, seconds: float = 100) -> bool:
    var evading := false
    for turn in range(int(seconds * 10)):
        var model = zone.combat_view.model
        if model.hp <= 0:
            return false
        var nearest := -1
        var distance := INF
        for id in ids:
            if model.alive(id):
                var current: float = zone.hero.position.distance_to(model.enemies[id]["at"])
                if current < distance:
                    nearest = id
                    distance = current
        if nearest < 0:
            return true
        var boss: Dictionary = model.enemies[HUNT.BOSS]
        if boss["windup"] > 0:
            if not evading and zone.hero.position.distance_to(boss["blast_at"]) < HUNT.BLAST_RADIUS + 0.3:
                for offset in [Vector3(-3.8, 0, 0), Vector3(3.8, 0, 0), Vector3(0, 0, 3.8), Vector3(0, 0, -3.8)]:
                    var point: Vector3 = zone.hero.position + offset
                    if point.distance_to(boss["home"]) < 10.8 and zone.navigation.has_walkable_segment(zone.hero.position, point):
                        evading = zone._move_to(point)
                        if evading:
                            break
            _advance(0.1)
            continue
        evading = false
        if model.attack_target < 0:
            zone.combat_view.target_enemy(nearest)
        if distance <= COMBAT.GRENADE_RANGE and zone.navigation.has_clear_shot(zone.hero.position, model.enemies[nearest]["at"]):
            if model.cooldowns[0] == 0:
                _press(zone.combat_view.skill_buttons[0])
            if model.launcher == 0:
                for skill in ([2, 1, 4] if model.enemies[nearest]["vehicle"] else [1, 4, 2]):
                    if model.cooldowns[skill] == 0:
                        _native_cast(skill, model.enemies[nearest]["at"])
                        break
        _advance(0.1)
    return false

func _run() -> void:
    get_tree().current_scene = null
    GameState.world_progress_path = PATH
    GameState.set_selection(0, 0, "Люди", "Амина")
    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        _clean()
        get_tree().root.size = size
        zone = null
        get_tree().change_scene_to_file("res://scenes/main.tscn")
        await get_tree().scene_changed
        await _settle()
        var menu = get_tree().current_scene
        _check(not menu.pve_button.disabled, "Amina cannot enter the free battle area")
        _press(menu.pve_button)
        await _adopt()
        _check(zone.combat_view.model.enabled and zone.combat_view.actors.size() == 9
            and zone.combat_view.actors[HUNT.BOSS].visible and not zone.progress.state()["accepted"],
            "free entry hid enemies behind story acceptance")
        _check(zone.zone_title.text.contains("РЖАВЫЙ ТРАКТ"), "ship button entered the old empty scene")
        for enemy in zone.combat_view.model.enemies:
            _check(zone.navigation.is_walkable(zone.navigation.world_to_cell(enemy["home"]))
                and not zone.navigation.get_path(zone.hero.position, enemy["home"]).is_empty(), "enemy camp has no walkable approach")
        for button in zone.combat_view.skill_buttons:
            _check(button.is_visible_in_tree() and get_viewport().get_visible_rect().encloses(button.get_global_rect()),
                "skill clipped at " + str(size))
        _check(zone.bottom_panel.get_global_rect().position.y - zone.top_panel.get_global_rect().end.y > 200,
            "battle UI occupies the playfield at " + str(size))
        _press(zone.goal_button)
        _check(zone.focus == zone.combat_view.model.enemies[0]["at"], "goal button did not show the nearest camp")
        _press(zone.follow_button)
        _check(zone.following, "camera follow broke in the new area")
        _press(zone.logs_button)
        await _settle()
        _check(zone.diagnostics_panel.popup.visible, "logs do not open in the new area")
        zone._handle_back()
        _press(zone.return_button)
        await _settle()
        _press(zone.return_dialog.get_ok_button())
        await _adopt()
        _check(zone.zone_title.text.contains("ПРИБРЕЖНЫЙ УЗЕЛ"), "sector exit did not return to the outpost")
        _press(zone.sector_button)
        await _adopt()
        _check(zone.combat_view.actors.size() == 9, "outpost travel returned to an empty scene")

    # Smallest landscape. Play all camps and the boss with unchanged damage, HP and timers.
    for ids in [[0, 1, 2], [3, 4, 5], [6, 7]]:
        var won := _fight(ids)
        _check(won, "ordinary camp was not soloable ids=%s hp=%s at=%s" % [ids, zone.combat_view.model.hp, zone.hero.position])
        if not won:
            _finish()
            return
        _walk(COMBAT.SAFE_AT, 24)
        _check(zone.combat_view.model.hp >= 99, "safe pad did not restore health between camps")
    # The eastern road avoids renewed camps while approaching the boss arena.
    _walk(Vector3(25, 0, 22), 16)
    _walk(Vector3(25, 0, -9), 10)
    var boss_won := _fight([HUNT.BOSS])
    _check(boss_won, "boss was not soloable with ground-warning dodges hp=%s at=%s boss=%s" % [zone.combat_view.model.hp, zone.hero.position, zone.combat_view.model.enemies[HUNT.BOSS]])
    if not boss_won:
        _finish()
        return
    _check(zone.progress.state()["hunt"]["claimed"] and zone.progress.experience() == 200 and zone.progress.credits() == 150,
        "boss kill did not atomically grant the first-clear reward")
    var health: float = zone.combat_view.model.hp
    var timers: Array = zone.combat_view.model.cooldowns.duplicate()
    var spawn_time: float = zone.combat_view.model.respawns[HUNT.BOSS]
    var position: Vector3 = zone.hero.position
    zone._checkpoint()
    zone._return_to_ship()
    await _adopt()
    _check(zone.combat_view.model.hp == health and zone.combat_view.model.cooldowns == timers
        and zone.progress.credits() == 150 and zone.hero.position == STORE.SPAWN,
        "outpost travel reset vitals/timers or moved the outpost position")
    _press(zone.sector_button)
    await _adopt()
    _check(zone.hero.position == position and zone.combat_view.model.hp == health and zone.combat_view.model.cooldowns == timers
        and not zone.combat_view.model.alive(HUNT.BOSS) and absf(zone.combat_view.model.respawns[HUNT.BOSS] - spawn_time) < 0.001
        and zone.progress.credits() == 150, "reentry reset health, boss, spawn time or one-time reward")
    _finish()

func _finish() -> void:
    _clean()
    if failures == 0:
        print("WORLD_SECTOR_TEST_PASS sizes=3 ship,outpost=native camps=8 boss=solo,warning_dodges vitals=shared reward=once logs=ok")
    get_tree().quit(0 if failures == 0 else 1)
