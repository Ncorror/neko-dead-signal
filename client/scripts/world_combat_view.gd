extends Node3D
## World adapter: touch targeting, bounded effects, HP/skills and PvE actor views.

const COMBAT := preload("res://scripts/world_combat.gd")
const LYRA := preload("res://scripts/lyra_voss_animations.gd")
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
var danger_marker: MeshInstance3D
var boss_label: Label
var aim_skill := -1
var chase_age := 0.0
var chasing := false
var effects: Array[Dictionary] = []
var attack_serial := 0
var death_pending := false
var death_ready := false

func install(world, bottom: VBoxContainer) -> void:
    zone = world
    model = zone.make_combat_model()
    if model.has_method("set_profile"):
        model.set_profile(zone.progress.character_id)
    model.configure(zone.navigation, zone.combat_state())
    for i in range(model.enemies.size()):
        var actor := Node3D.new()
        actor.name = "WorldEnemy_%d" % i
        add_child(actor)
        if model.enemies[i]["vehicle"]:
            zone._box(actor, Vector3.ZERO, Vector3(1.0, 1.1, 1.2), Color("#b25757"))
            zone._box(actor, Vector3(0, 1.1, 0.25), Vector3(0.2, 0.2, 1.0), Color("#e6a06c"))
        else:
            var body: Node3D = zone._person(actor, Vector3.ZERO, Color("#b76c65"), "Marauder")
            body.rotation.y = PI
        actors.append(actor)
        var boss: bool = model.enemies[i].get("boss", false)
        if boss:
            actor.scale = Vector3.ONE * 1.8
            zone._box(actor, Vector3(-0.65, 0.1, 0), Vector3(0.35, 0.6, 1.5), Color("#77615a"))
            zone._box(actor, Vector3(0.65, 0.1, 0), Vector3(0.35, 0.6, 1.5), Color("#77615a"))
        labels.append(zone._caption(actor, "", 2.1 if boss else 2.8))
    aim_marker = _ring(1.0, Color("#e9c16d"))
    enemy_marker = _ring(0.8, Color("#ef817b"))
    danger_marker = _ring(2.8, Color("#ff785b"))
    boss_label = zone._label(bottom, "", 15)
    boss_label.hide()
    health_label = zone._label(bottom, "", 14)
    skills = HFlowContainer.new()
    bottom.add_child(skills)
    for i in range(5):
        var button: Button = zone._button(COMBAT.SKILL_NAMES[i], _choose_skill.bind(i))
        button.custom_minimum_size = Vector2(126, 54)
        button.add_theme_font_size_override("font_size", 13)
        button.tooltip_text = COMBAT.SKILL_NAMES[i].replace("\n", " ") + " · КД %d с" % COMBAT.COOLDOWNS[i]
        button.visible = model.profile_id != "lyra_voss"
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
        call_deferred("_begin_death")

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
    var is_lyra: bool = model.profile_id == "lyra_voss"
    health_label.text = ("ЛИРА ВОСС · ОЗ %d/100 · СНАЙПЕР · ДАЛЬНОСТЬ 16" % ceili(model.hp)) if is_lyra else ("АМИНА · ОЗ %d/100 · Взрывной специалист: гранаты ослабляют броню на 10%% / 4 с" % ceili(model.hp))
    if model.protocol > 0 and not is_lyra:
        health_label.text += " · ПРОТОКОЛ: %d с" % ceili(model.protocol)
    for i in range(5):
        var label: String = COMBAT.SKILL_NAMES[i]
        if model.cooldowns[i] > 0:
            label += " · %d" % ceili(model.cooldowns[i])
        if aim_skill == i:
            label = "◆ " + label
        if skill_buttons[i].text != label:
            skill_buttons[i].text = label
        skill_buttons[i].visible = not is_lyra
        skill_buttons[i].disabled = is_lyra or model.hp <= 0 or model.cooldowns[i] > 0
    cancel_button.visible = aim_skill >= 0
    respawn_button.visible = model.hp <= 0 and death_ready
    if hint.text.is_empty():
        hint.text = "Коснись врага — подойти и открыть снайперский огонь. Навыки Лиры подключим отдельным набором." if is_lyra else "Коснись врага — подойти и атаковать. Граната / рывок — навык, затем цель."
    for i in range(model.enemies.size()):
        var enemy: Dictionary = model.enemies[i]
        actors[i].visible = model.enabled and enemy["hp"] > 0
        var movement: Vector3 = enemy["at"] - actors[i].position
        if movement.length_squared() > 0.0001:
            actors[i].rotation.y = atan2(movement.x, movement.z)
        actors[i].position = enemy["at"]
        var text: String = "%s · %d/%d" % [enemy["name"], ceili(enemy["hp"]), int(enemy["max_hp"])]
        if enemy["returning"]:
            text += "\nВОЗВРАЩАЕТСЯ"
        elif enemy["weak"] > 0:
            text += "\nБРОНЯ −10%"
        if labels[i].text != text:
            labels[i].text = text
    boss_label.hide()
    danger_marker.hide()
    for enemy in model.enemies:
        if not enemy.get("boss", false) or enemy["hp"] <= 0 or not enemy["aggro"]:
            continue
        boss_label.show()
        boss_label.text = "БОСС · %s · ОЗ %d/%d%s" % [enemy["name"], ceili(enemy["hp"]), int(enemy["max_hp"]), " · ПЕРЕГРУЗКА" if enemy.get("enraged", false) else ""]
        if enemy.get("windup", 0.0) > 0:
            danger_marker.show()
            danger_marker.position = enemy["blast_at"] + Vector3(0, 0.12, 0)
            boss_label.text += " · ВЫЙДИ ИЗ КРУГА: %.1f с" % enemy["windup"]
    enemy_marker.visible = model.enabled and model.alive(model.attack_target)
    if enemy_marker.visible:
        enemy_marker.position = model.enemies[model.attack_target]["at"] + Vector3(0, 0.1, 0)

func pick_enemy(at: Vector2) -> int:
    if not model.enabled or model.hp <= 0:
        return -1
    var nearest := -1
    var best := 30.0
    for i in range(model.enemies.size()):
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
    if not model.in_safe(zone.hero.position) and zone.hero.position.distance_to(at) <= model.weapon_range and zone.navigation.has_clear_shot(zone.hero.position, at):
        if chasing:
            zone._clear_route()
            chasing = false
        return
    chase_age -= delta
    if chase_age > 0:
        return
    chase_age = 0.4
    var destination := at.move_toward(zone.hero.position, model.weapon_range * 0.85)
    if model.in_safe(destination) or not zone.navigation.has_clear_shot(destination, at):
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

func update_hero_facing() -> void:
    # Navigation owns heading while moving. Once planted, face the same
    # explicit/retaliation target that the simulation uses, even on cooldown.
    if model.profile_id != "lyra_voss" or not model.enabled or model.hp <= 0 or not zone.route.is_empty():
        return
    var target: int = model.weapon_target()
    if not model.alive(target) or model.enemies[target]["returning"] or model.in_safe(zone.hero.position):
        return
    var at: Vector3 = model.enemies[target]["at"]
    if not model._can_shoot(zone.hero.position, at, model.weapon_range):
        return
    var direction: Vector3 = at - zone.hero.position
    direction.y = 0.0
    if direction.length_squared() > 0.0001:
        zone.heading = atan2(direction.x, direction.z)

func tick(delta: float) -> void:
    var hero_can_fire: bool = model.profile_id != "lyra_voss" or zone.route.is_empty()
    var aimed_target := -2
    if model.profile_id == "lyra_voss" and hero_can_fire:
        var target: int = model.weapon_target()
        aimed_target = target
        hero_can_fire = false
        if model.alive(target):
            var direction: Vector3 = model.enemies[target]["at"] - zone.hero.position
            var target_heading := atan2(direction.x, direction.z)
            # Let the body settle onto the firing direction instead of sending
            # a sniper shot sideways during a target switch. No delayed shot
            # is queued: the simulation revalidates the target every tick.
            hero_can_fire = absf(angle_difference(zone.hero.rotation.y, target_heading)) <= LYRA.FIRE_ANGLE_TOLERANCE
    model.tick(delta, zone.hero.position, hero_can_fire, aimed_target)
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
    var trace: MeshInstance3D = zone._box(self, start, Vector3(0.10, 0.10, 0.10), color)
    var flight := clampf(distance / 70.0, 0.06, 0.18)
    var tween := create_tween()
    tween.tween_property(trace, "position", end, flight).set_trans(Tween.TRANS_LINEAR)
    _effect(trace, flight + 0.03)

func _events() -> void:
    var important := false
    for event in model.take_events():
        var name: String = event["type"]
        var details: Dictionary = event.duplicate()
        details.erase("type")
        for key in ["from", "to"]:
            if details.has(key):
                details[key] = str(details[key])
        zone._event(name, details)
        if name == "boss_blast":
            var ring := _ring(2.8, Color("#ffb06d"))
            ring.position = event["to"] + Vector3(0, 0.14, 0)
            ring.show()
            _effect(ring, 0.35)
        elif name == "hero_shot":
            _trace(event["from"], event["to"], Color("#b1f8ed"))
            if model.profile_id == "lyra_voss" and zone.hero_motion != null:
                attack_serial += 1
                var token := attack_serial
                var duration := LYRA.play_attack(zone.hero_motion)
                if duration > 0:
                    _restore_lyra_after_attack(token, duration)
        elif name == "enemy_shot":
            _trace(event["from"], event["to"], Color("#ef9c75"))
        elif name == "skill_cast" and event["skill"] in [1, 2, 4]:
            var ring := _ring(3.0 if event["skill"] == 4 else (2.5 if event["skill"] == 1 else 0.6), Color("#e9c16d"))
            ring.position = event["to"] + Vector3(0, 0.12, 0)
            ring.show()
            _effect(ring, 0.4)
        elif name in ["enemy_defeated", "enemy_respawned"]:
            important = true
        elif name == "hero_defeated":
            zone._stop()
            important = true
            _begin_death()
    if important:
        if not zone._checkpoint():
            zone._show_notice(zone.progress.error_text)
        zone._refresh()

func _restore_lyra_after_attack(token: int, seconds: float) -> void:
    await get_tree().create_timer(maxf(seconds, 0.05)).timeout
    if token != attack_serial or model.hp <= 0 or zone.hero_motion == null:
        return
    if str(zone.hero_motion.get_meta("neko_lyra_motion", "")) != "attack":
        return
    LYRA.restore_ready(zone.hero_motion)


func _begin_death() -> float:
    if death_pending:
        return 0.0
    death_pending = true
    death_ready = false
    attack_serial += 1
    var delay := 0.85
    if model.profile_id == "lyra_voss" and zone.hero_motion != null:
        delay = maxf(delay, LYRA.play_death(zone.hero_motion))
    _show_death_after(delay)
    refresh()
    return delay


func _show_death_after(seconds: float) -> void:
    await get_tree().create_timer(maxf(seconds, 0.05)).timeout
    if not death_pending or model.hp > 0:
        return
    death_ready = true
    refresh()
    zone._popup(death_dialog)


func _respawn() -> void:
    if model.respawn():
        death_pending = false
        death_ready = false
        attack_serial += 1
        death_dialog.hide()
        zone._stop()
        if model.profile_id == "lyra_voss" and zone.hero_motion != null:
            LYRA.restore_ready(zone.hero_motion)
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
