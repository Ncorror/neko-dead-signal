extends SubViewportContainer
## Lightweight 3D commander menu preview; hidden until an original GLB is installed.
## Static GLB can be previewed without a rig. Animation is optional.
const MODEL_FIT := preload("res://scripts/rts_character_fit.gd")
const LYRA_MOTION := preload("res://scripts/lyra_voss_animations.gd")
const MENU_PREVIEW_HEIGHT := 2.75
const MENU_FRONT_YAW_DEGREES := 0.0
const MODELS := [
    ["res://assets/characters/amina/preview.glb",
     "res://assets/characters/reina/preview.glb",
     "res://assets/characters/mira_kade/preview.glb",
     "res://assets/characters/lyra_voss/rigged.glb"],
    ["", ""]
]
var preview: SubViewport
var pivot: Node3D
var active_model: Node3D
var camera: Camera3D
var model_bounds := AABB()
var drag_touch := -1
var drag_mouse := false

func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    preview = SubViewport.new()
    preview.transparent_bg = true
    preview.own_world_3d = true
    preview.size = Vector2i(384, 512)
    preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    add_child(preview)
    var world := Node3D.new()
    preview.add_child(world)
    pivot = Node3D.new()
    world.add_child(pivot)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-43, 35, -16)
    key.light_energy = 1.3
    world.add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-2, 2, 3)
    fill.light_energy = 0.65
    world.add_child(fill)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    world.add_child(camera)
    camera.current = true
    preview.size_changed.connect(_frame_model)
    visible = false

func set_commander(faction: int, officer: int) -> bool:
    if active_model != null:
        active_model.queue_free()
        active_model = null
    if faction < 0 or faction >= MODELS.size():
        return _set_missing()
    if officer < 0 or officer >= MODELS[faction].size():
        return _set_missing()
    var model_path: String = MODELS[faction][officer]
    if model_path.is_empty() or not ResourceLoader.exists(model_path):
        return _set_missing()
    var resource: Resource = load(model_path)
    if not (resource is PackedScene):
        return _set_missing()
    var source: PackedScene = resource as PackedScene
    var model: Node = source.instantiate()
    if not (model is Node3D):
        model.queue_free()
        return _set_missing()
    pivot.add_child(model)
    active_model = model as Node3D
    var fit: Dictionary = MODEL_FIT.fit_to_height(active_model, MENU_PREVIEW_HEIGHT)
    if not bool(fit.get("ok", false)):
        push_warning("RTS_MENU_3D_INVALID_BOUNDS")
        active_model.queue_free()
        active_model = null
        return _set_missing()
    pivot.rotation.y = deg_to_rad(MENU_FRONT_YAW_DEGREES)
    drag_touch = -1
    drag_mouse = false
    model_bounds = fit["bounds"]
    _frame_model()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("visual", "menu_character_fit", {
            "target_height": fit["target_height"],
            "scale": fit["scale"]
        })
    if faction == 0 and officer == 3:
        var player: AnimationPlayer = LYRA_MOTION.find_player(active_model)
        if player != null:
            LYRA_MOTION.hold_ready_pose(player)
    else:
        for child in active_model.find_children("*", "AnimationPlayer", true, false):
            var animation_player: AnimationPlayer = child as AnimationPlayer
            for clip in animation_player.get_animation_list():
                if clip.to_lower().contains("idle"):
                    animation_player.play(clip)
                    break
    visible = true
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("visual", "3d_preview_loaded", {"faction": faction, "officer": officer})
    return true

func _set_missing() -> bool:
    drag_touch = -1
    drag_mouse = false
    visible = false
    return false

func _frame_model() -> void:
    if camera == null or model_bounds.size.y <= 0.0:
        return
    var aspect := float(preview.size.x) / maxf(1.0, float(preview.size.y))
    # A cylinder around the upright model fits every user-selected yaw.
    var radius_x := maxf(absf(model_bounds.position.x), absf(model_bounds.end.x))
    var radius_z := maxf(absf(model_bounds.position.z), absf(model_bounds.end.z))
    var diameter := 2.0 * Vector2(radius_x, radius_z).length()
    camera.size = maxf(model_bounds.size.y, diameter / aspect) * 1.14
    var center_y := model_bounds.get_center().y
    camera.position = Vector3(0.0, center_y, maxf(diameter, model_bounds.size.y) + 2.0)
    camera.look_at(Vector3(0.0, center_y, 0.0), Vector3.UP)

func _gui_input(event: InputEvent) -> void:
    if active_model == null or event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        if event.canceled:
            drag_touch = -1
        elif event.pressed and drag_touch == -1:
            drag_touch = event.index
        elif event.index == drag_touch:
            drag_touch = -1
        accept_event()
    elif event is InputEventScreenDrag and event.index == drag_touch:
        _rotate_by_drag(event.relative.x)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        drag_mouse = event.pressed
        accept_event()
    elif event is InputEventMouseMotion and drag_mouse:
        _rotate_by_drag(event.relative.x)
        accept_event()

func _rotate_by_drag(delta_x: float) -> void:
    pivot.rotation.y += delta_x * TAU / maxf(size.x, 1.0)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        drag_touch = -1
        drag_mouse = false
