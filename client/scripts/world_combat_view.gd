extends Node3D
## World adapter: touch targeting, bounded effects, HP/skills and PvE actor views.

const COMBAT := preload("res://scripts/world_combat.gd")
var model = COMBAT.new()
var zone
var actors: Array[Node3D] = []
var labels: Array[Label3D] = []
var skill_buttons: Array[Button] = []
var health_label: Label
var hint: Label
var skills: HFlowContainer
var cancel_button: Button
var respawn_button: Button
var death_dialog: AcceptDialog
var aim_marker: MeshInstance3D
var enemy_marker: MeshInstance3D
var aim_skill := -1
var chase_age := 0.0
var chasing := false
var effects: Array[Dictionary] = []

func install(world, bottom: VBoxContainer) -> void:
    zone = world
    model.configure(zone.navigation, zone.progress.state()["combat"])
    for i in range(3):
        var actor := Node3D.new()
        actor.name = "WorldEnemy_%d" % i
        add_child(actor)
        if i == 2:
            zone._box(actor, Vector3.ZERO, Vector3(1.0, 1.1, 1.2), Color("#b25757"))
            zone._box(actor, Vector3(0, 1.1, 0.25), Vector3(0.2, 0.2, 1.0), Color("#e6a06c"))
        else:
            var body: Node3D = zone._person(actor, Vector3.ZERO, Color("#b76c65"), "Marauder")
            body.rotation.y = PI
        actors.append(actor)
        labels.append(zone._caption(actor, "", 2.8))
    aim_marker = _ring(1.0, Color("#e9c16d"))
    enemy_marker = _ring(0.8, Color("#ef817b"))
    health_label = zone._label(bottom, "", 14)
    skills = HFlowContainer.new()
    bottom.add_child(skills)
    for i in range(5):
        var button: Button = zone._button(COMBAT.SKILL_NAMES[i], _choose_skill.bind(i))
        button.custom_minimum_size = Vector2(126, 54)
        button.add_theme_font_size_override("font_size", 13)
        button.tooltip_text = COMBAT.SKILL_NAMES[i].replace("\n", " ") + " · КД %d с" % COMBAT.COOLDOWNS[i]
        skills.add_child(button)
        skill_buttons.append(button)
    cancel_button = zone._button("ОТМЕНА", cancel_aim)
    skills.add_child(cancel_button)
    respawn_button = zone._button("ВОЗРОДИТЬСЯ", _respawn)
    skills.add_child(respawn_button)
    hint = zone._label(bottom, "", 14)
    death_dialog = AcceptDialog.new()
    death_dialog.title = "Герой повержен"
    death_dialog.dialog_text = "Возвращение на посадочную площадку. Прогресс задания и награда сохраняются. Откаты навыков не сбрасываются."
    death_dialog.ok_button_text = "ВОЗРОДИТЬСЯ"
    death_dialog.confirmed.connect(_respawn)
    add_child(death_dialog)
    refresh()
    if model.enabled and model.hp <= 0:
        call_deferred("_show_death")

func _ring(radius: float, color: Color) -> MeshInstance3D:
    var ring := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius - 0.06
    mesh.outer_radius = radius + 0.06
    ring.mesh = mesh
    ring.material_override = zone._material(color)
    ring.hide()
    add_child(ring)
    return ring

func refresh() -> void:
    health_label.visible = model.enabled
    skills.visible = model.enabled
    hint.visible = model.enabled
    health_label.text = "АМИНА · ОЗ %d/100 · Взрывной специалист: гранаты ослабляют броню на 10%% / 4 с" % ceili(model.hp)
    if model.protocol > 0:
        health_label.text += " · ПРОТОКОЛ: %d с" % ceili(model.protocol)
    for i in range(5):
        var label: String = COMBAT.SKILL_NAMES[i]
        if model.cooldowns[i] > 0:
            label += " · %d" % ceili(model.cooldowns[i])
        if aim_skill == i:
            label = "◆ " + label
        if skill_buttons[i].text != label:
            skill_buttons[i].text = label
        skill_buttons[i].disabled = model.hp <= 0 or model.cooldowns[i] > 0
    cancel_button.visible = aim_skill >= 0
    respawn_button.visible = model.hp <= 0
    if hint.text.is_empty():
        hint.text = "Коснись врага — подойти и атаковать. Граната / рывок — навык, затем цель."
    for i in range(3):
        var enemy: Dictionary = model.enemies[i]
        actors[i].visible = model.enabled and enemy["hp"] > 0
        var movement: Vector3 = enemy["at"] - actors[i].position
        if movement.length_squared() > 0.0001:
            actors[i].rotation.y = atan2(movement.x, movement.z)
        actors[i].position = enemy["at"]
        var text: String = "%s · %d/%d" % [COMBAT.ENEMY_NAMES[i], ceili(enemy["hp"]), int(enemy["max_hp"])]
        if enemy["returning"]:
            text += "\nВОЗВРАЩАЕТСЯ"
        elif enemy["weak"] > 0:
            text += "\nБРОНЯ −10%"
        if labels[i].text != text:
            labels[i].text = text
    enemy_marker.visible = model.enabled and model.alive(model.attack_target)
    if enemy_marker.visible:
        enemy_marker.position = model.enemies[model.attack_target]["at"] + Vector3(0, 0.1, 0)

func pick_enemy(at: Vector2) -> int:
    if not model.enabled or model.hp <= 0:
        return -1
    var nearest := -1
    var best := 30.0
    for i in range(3):
        if not model.alive(i) or zone.camera.is_position_behind(actors[i].position + Vector3.UP):
            continue
        var a: Vector2 = zone.camera.unproject_position(actors[i].position)
        var b: Vector2 = zone.camera.unproject_position(actors[i].position + Vector3.UP * 2.6)
        var distance := at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
        if distance < best:
            best = distance
            nearest = i
    return nearest

func target_enemy(id: int) -> void:
    zone._stop()
    if model.select_target(id):
        zone._follow()
        chase_age = 0
        zone._event("attack_order", {"enemy": id})
        refresh()

func cancel_aim() -> void:
    aim_skill = -1
    aim_marker.hide()
    if hint != null:
        hint.text = "Коснись врага — подойти и атаковать. В движении ответный огонь сохраняется."
        refresh()

func cancel_orders() -> void:
    model.attack_target = -1
    chasing = false
    cancel_aim()

func _choose_skill(skill: int) -> void:
    zone._reset_gesture()
    if not model.enabled or model.hp <= 0 or model.cooldowns[skill] > 0:
        return
    if skill == 0:
        _cast(0, zone.hero.position)
        return
    if aim_skill == skill:
        cancel_aim()
        return
    aim_skill = skill
    hint.text = "ВЫБЕРИ ЦЕЛЬ: %s. Касание земли / врага; ОТМЕНА или Назад — отменить." % COMBAT.SKILL_NAMES[skill].replace("\n", " ")
    var radius := 3.0 if skill == 4 else (2.5 if skill == 1 else 0.7)
    aim_marker.scale = Vector3(radius, 1, radius)
    aim_marker.position = zone.hero.position + Vector3(0, 0.1, -3)
    aim_marker.show()
    refresh()

func aim_preview(at: Vector2) -> void:
    if aim_skill < 0:
        return
    var point: Variant = zone._ground(at)
    if point == null:
        return
    if aim_skill == 3:
        point = model.dash_end(zone.hero.position, point)
    aim_marker.position = point + Vector3(0, 0.1, 0)
    aim_marker.material_override.albedo_color = Color("#69e6e5") if model.cast_error(aim_skill, zone.hero.position, point).is_empty() else Color("#ef817b")

func consume_tap(at: Vector2) -> bool:
    if model.enabled and model.hp <= 0:
        return true
    if aim_skill < 0:
        return false
    var id := pick_enemy(at)
    var point: Variant = model.enemies[id]["at"] if id >= 0 else zone._ground(at)
    if point != null:
        _cast(aim_skill, point)
    return true

func _cast(skill: int, point: Vector3) -> void:
    var result: Dictionary = model.cast(skill, zone.hero.position, point)
    if not result["ok"]:
        hint.text = result["error"]
        return
    if skill == 3:
        var from: Vector3 = zone.hero.position
        zone._clear_route()
        model.attack_target = -1
        chasing = false
        zone.hero.position = result["at"]
        var direction: Vector3 = zone.hero.position - from
        zone.heading = atan2(direction.x, direction.z)
        zone._follow()
    cancel_aim()
    _events()
    if not zone._checkpoint():
        zone._show_notice(zone.progress.error_text)
    refresh()

func before_movement(delta: float) -> void:
    if not model.enabled or model.hp <= 0 or not model.alive(model.attack_target):
        return
    var at: Vector3 = model.enemies[model.attack_target]["at"]
    if model.enemies[model.attack_target]["returning"]:
        zone._stop()
        return
    if zone.hero.position.distance_to(at) <= COMBAT.RANGE and zone.navigation.has_clear_shot(zone.hero.position, at):
        if chasing:
            zone._clear_route()
            chasing = false
        return
    chase_age -= delta
    if chase_age > 0:
        return
    chase_age = 0.4
    var destination := at.move_toward(zone.hero.position, COMBAT.RANGE * 0.85)
    if not zone.navigation.has_clear_shot(destination, at):
        destination = at.move_toward(zone.hero.position, 1.8)
    var avoid: Array[Vector3] = []
    for enemy in model.enemies:
        if enemy["hp"] > 0:
            avoid.append(enemy["at"])
    var path: Array[Vector3] = zone.navigation.get_path(zone.hero.position, destination, avoid)
    if not path.is_empty():
        zone.route = path
        zone.route_index = 0
        zone.interaction = -2
        chasing = true

func tick(delta: float) -> void:
    model.tick(delta, zone.hero.position)
    if chasing and not model.alive(model.attack_target):
        zone._clear_route()
        chasing = false
    _events()
    for i in range(effects.size() - 1, -1, -1):
        effects[i]["left"] -= delta
        if effects[i]["left"] <= 0:
            effects[i]["node"].queue_free()
            effects.remove_at(i)
    refresh()

func _effect(node: Node3D, seconds: float) -> void:
    if effects.size() >= 48:
        effects.pop_front()["node"].queue_free()
    effects.append({"node": node, "left": seconds})

func _trace(from: Vector3, to: Vector3, color: Color) -> void:
    var start := from + Vector3.UP
    var end := to + Vector3.UP
    var distance := start.distance_to(end)
    if distance < 0.05:
        return
    var trace: MeshInstance3D = zone._box(self, (start + end) * 0.5 - Vector3(0, 0.025, 0), Vector3(0.05, 0.05, distance), color)
    trace.look_at(end)
    _effect(trace, 0.14)

func _events() -> void:
    var important := false
    for event in model.take_events():
        var name: String = event["type"]
        var details := event.duplicate()
        details.erase("type")
        for key in ["from", "to"]:
            if details.has(key):
                details[key] = str(details[key])
        zone._event(name, details)
        if name in ["hero_shot", "enemy_shot"]:
            _trace(event["from"], event["to"], Color("#b1f8ed") if name == "hero_shot" else Color("#ef9c75"))
        elif name == "skill_cast" and event["skill"] in [1, 2, 4]:
            var ring := _ring(3.0 if event["skill"] == 4 else (2.5 if event["skill"] == 1 else 0.6), Color("#e9c16d"))
            ring.position = event["to"] + Vector3(0, 0.12, 0)
            ring.show()
            _effect(ring, 0.4)
        elif name == "enemy_defeated":
            important = true
        elif name == "hero_defeated":
            zone._stop()
            important = true
            call_deferred("_show_death")
    if important:
        if not zone._checkpoint():
            zone._show_notice(zone.progress.error_text)
        zone._refresh()

func _show_death() -> void:
    if model.hp <= 0:
        zone._popup(death_dialog)

func _respawn() -> void:
    if model.respawn():
        death_dialog.hide()
        zone._stop()
        zone.hero.position = zone.PROGRESS.SPAWN
        zone._follow()
        _events()
        if not zone._checkpoint():
            zone._show_notice(zone.progress.error_text)
        refresh()

func handle_back() -> bool:
    if death_dialog.visible:
        death_dialog.hide()
        return true
    if aim_skill >= 0:
        cancel_aim()
        return true
    return false
