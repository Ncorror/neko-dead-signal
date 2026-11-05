extends Node
## Automatic MMO camera, measured walking speed and non-destructive 0.0.21 saves.

const PATH := "user://world-camera-regression/progress.json"
const STORE := preload("res://scripts/world_progress.gd")
var failures := 0
var zone

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_CAMERA_TEST_FAIL " + message)

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _legacy_save() -> void:
    _clean()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH).get_base_dir())
    var data := {"version": 1, "characters": {"amina": {
        "accepted": true, "claimed": true, "relays": [0, 1, 2], "position": [-18, 18], "zoom": 30.0}}}
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func _load_zone() -> void:
    get_tree().change_scene_to_file("res://scenes/world_zone.tscn")
    await get_tree().scene_changed
    zone = get_tree().current_scene
    zone.set_physics_process(false)
    zone.set_process(false)
    for frame in range(8):
        await get_tree().process_frame
        zone._process(0)

func _camera_for(seconds: float) -> void:
    for frame in range(ceili(seconds * 60)):
        zone._update_camera(1.0 / 60.0)

func _centre() -> Vector2:
    var bounds: Rect2 = zone.get_viewport().get_visible_rect()
    return Vector2(bounds.get_center().x, (zone.top_panel.get_global_rect().end.y + zone.bottom_panel.get_global_rect().position.y) * 0.5)

func _run() -> void:
    get_tree().current_scene = null
    GameState.world_progress_path = PATH
    GameState.set_selection(0, 0, "Люди", "Амина")
    var fresh = STORE.new()
    _clean()
    fresh.open_profile(PATH, 0, 0)
    _check(fresh.state()["zoom"] == 16, "new profiles do not start with the closer camera")
    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        _legacy_save()
        get_tree().root.size = size
        await _load_zone()
        _check(zone.zoom == 16 and zone.following and zone.progress.credits() == 75
            and zone.progress.experience() == 100 and zone.progress.state()["relays"] == [0, 1, 2],
            "legacy camera migration lost reward/relays or failed to move the view closer")
        _check(zone.camera.unproject_position(zone.hero.position + Vector3.UP).distance_to(_centre()) < 2,
            "resting hero is not centred between the HUD panels at " + str(size))
        for fps in [30, 60, 120]:
            zone._stop()
            zone.hero.position = zone.PROGRESS.SPAWN
            zone.rendered_focus = zone.hero.position
            zone._follow()
            zone._move_to(Vector3(-11, 0, 18))
            var start: Vector3 = zone.hero.position
            for frame in range(fps):
                zone._physics_process(1.0 / fps)
                zone._update_camera(1.0 / fps)
                _check(zone.camera.unproject_position(zone.hero.position + Vector3.UP).distance_to(_centre()) < 35,
                    "moving hero escaped the follow centre at %d FPS / %s" % [fps, size])
            var metres: float = zone.hero.position.distance_to(start)
            _check(metres > 4.0 and metres < 4.4, "one second of walking is not about 4.2 units at " + str(fps))
        zone._stop()
        var at: Vector3 = zone.hero.position
        zone._pan(Vector2(45, 0))
        zone.contacts[0] = Vector2(500, 350)
        _camera_for(2)
        _check(not zone.following, "camera returned while the inspection finger was still held")
        zone.contacts.clear()
        _camera_for(2.5)
        _check(zone.following and zone.hero.position == at, "camera did not return automatically after the swipe")
        zone._show_goal()
        _check(not zone.following and zone.route.is_empty(), "goal preview moved the player")
        _camera_for(4.8)
        _check(zone.following, "goal preview permanently disabled follow")
        zone._show_goal()
        zone._move_to(Vector3(-11, 0, 18))
        _check(zone.following and zone.preview_seconds == 0, "movement did not immediately restore automatic follow")
        zone._stop()
        zone._checkpoint()
        zone.zoom = 25.0
        _check(zone._checkpoint(), "manual zoom could not be saved")
        await _load_zone()
        _check(zone.zoom == 25 and zone.progress.state()["camera_preset"] == 2 and zone.progress.credits() == 75,
            "updated camera preset overwrote a later manual zoom or changed the reward")
    _clean()
    GameState.world_progress_path = STORE.DEFAULT_PATH
    if failures == 0:
        print("WORLD_CAMERA_TEST_PASS sizes=3 fps=30,60,120 auto_follow=ok peek=temporary hud_center=ok speed=4.2 migration=once reward=preserved")
    get_tree().quit(0 if failures == 0 else 1)
