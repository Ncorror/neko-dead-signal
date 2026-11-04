extends Node
## Shared sight, obstacle occlusion, atomic budgeted updates and real scene filtering.

const SIGHT := preload("res://scripts/rts_visibility.gd")
const NAVIGATION := preload("res://scripts/rts_navigation.gd")
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_VISIBILITY_TEST_FAIL " + message)

func _commit(sight, nav, observers: Array[Vector3]) -> void:
    sight.request_snapshot(observers, true)
    var frames := 0
    while sight.scanning and frames < 100:
        sight.advance(nav, 32)
        _check(sight.last_step_checks <= 32, "scan exceeded per-frame ray budget")
        frames += 1
    _check(not sight.scanning, "visibility scan did not finish")

func _land():
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false # Isolate the existing fixed-budget scenario.
    op.objectives.expanded = false # Retain original landing goals in this regression.
    return op

func _run() -> void:
    var nav = NAVIGATION.new()
    nav.configure()
    var sight = SIGHT.new()
    sight.configure(Rect2(-25, -25, 50, 50), 1.0, 5.0)
    var observers: Array[Vector3] = [Vector3(-10, 0, 0), Vector3(10, 0, 0)]
    _check(not sight.is_visible(Vector3.ZERO) and not sight.was_explored(Vector3.ZERO), "new map must be unknown")
    sight.request_snapshot(observers)
    sight.advance(nav, 1)
    _check(sight.scanning and sight.revision == 0 and not sight.is_visible(observers[0]),
        "partial scan must not publish a flickering half-map")
    while sight.scanning:
        sight.advance(nav, 32)
    _check(sight.is_visible(observers[0]) and sight.is_visible(observers[1])
        and not sight.is_visible(Vector3.ZERO), "shared sight must be a union of observer circles")
    _check(not sight.request_snapshot(observers), "stationary observers must not rebuild the texture")
    _commit(sight, nav, [Vector3(0, 0, 10)])
    _check(not sight.is_visible(observers[0]) and sight.was_explored(observers[0]),
        "exploration memory must survive leaving an area")
    var old_cell: Vector2i = sight.world_to_cell(observers[0])
    var mask_bytes: PackedByteArray = sight.mask_image().get_data()
    _check(mask_bytes[old_cell.y * sight.dimensions.x + old_cell.x] == 100,
        "incremental fog texture must dim old sight instead of leaving a bright cell")
    _commit(sight, nav, [])
    _check(not sight.is_visible(Vector3(0, 0, 10)) and sight.was_explored(Vector3(0, 0, 10)),
        "losing all observers must remove current sight but retain history")
    _check(not sight.is_visible(Vector3(25, 0, 0)) and not sight.was_explored(Vector3(-26, 0, 0)),
        "out-of-map queries must stay hidden")

    nav.set_blocked_box(Vector3.ZERO, Vector3(2, 2, 8), 0.75)
    sight.configure(Rect2(-12, -12, 24, 24), 1.0, 8.0)
    _commit(sight, nav, [Vector3(-4, 0, 0)])
    _check(sight.is_visible(Vector3.ZERO), "the near obstacle itself must be discoverable")
    _check(not sight.is_visible(Vector3(3, 0, 0)), "obstacle must hide cells behind it")
    _check(sight.is_visible(Vector3(-4, 0, 5)), "open side of observer should remain visible")
    var mask: Image = sight.mask_image()
    _check(mask.get_width() == 24 and mask.get_height() == 24, "mask must match the map")
    sight.request_snapshot([Vector3(4, 0, 0)])
    sight.advance(nav, 1)
    sight.clear_current()
    sight.advance(nav, 10000)
    _check(not sight.scanning and sight.visible.count(1) == 0 and sight.was_explored(Vector3.ZERO),
        "clearing sight must cancel an in-progress snapshot without erasing history")
    _check(sight.mask_image().get_data().count(255) == 0, "cached mask retained cleared sight")

    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    var op = await _land()
    _check(not op.sentry.visible and not op.crates[2].visible, "unscouted enemy and remote crate leaked into scene")
    _check(op.crates[0].visible, "nearby supply crate must be visible at landing")
    op._issue_attack()
    _check(op.attackers.is_empty() and op.unit_paths.is_empty(), "hidden enemy must not accept an attack order")
    var hidden_target: Vector2 = op.view_camera.unproject_position(op.sentry.position + Vector3.UP)
    op._handle_tap(hidden_target)
    _check(op.attackers.is_empty(), "tap must not select a hidden enemy through the fog")
    op._stop_selected_units()
    op.hero.position = Vector3(4, 0, -4)
    op._update_visibility(0.0, true)
    _check(op.sentry.visible, "approaching a sentry must reveal it")
    op._issue_attack()
    _check(op.attackers.has(op.hero), "revealed enemy must accept an attack")
    op.escort.position = Vector3(13, 0, -6)
    op._update_visibility(0.0, true)
    _check(op.crates[2].visible, "escort must contribute to shared sight")
    op.sentry.damage = 100
    op._shoot(op.sentry, op.escort)
    op._update_visibility(0.0, true)
    _check(not op.crates[2].visible and op.visibility.was_explored(Vector3(13, 0, -6)),
        "dead ally must stop revealing remote objects, while exploration remains")
    op = await _land()
    _check(not op.visibility.was_explored(Vector3(13, 0, -6)), "fresh landing must reset explored terrain")
    if failures == 0:
        print("RTS_VISIBILITY_TEST_PASS")
    get_tree().quit(0 if failures == 0 else 1)
