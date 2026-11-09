extends SubViewportContainer
## Static 3D presentation shared by the avatar editor and inventory.
## Keeps the approved high-detail GLB separate from RTS commander models.
const MODEL_PATH := "res://assets/characters/female_base_v3/editor_relaxed.glb"
const MODEL_FIT := preload("res://scripts/rts_character_fit.gd")
const DISPLAY_HEIGHT := 2.75

var preview: SubViewport
var pivot: Node3D
var camera: Camera3D
var active_model: Node3D
var model_bounds := AABB()
var zoom_multiplier := 1.0
var dragging_mouse := false
var touches: Dictionary = {}

func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    preview = SubViewport.new()
    preview.size = Vector2i(640, 768)
    preview.transparent_bg = true
    preview.own_world_3d = true
    preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
    add_child(preview)

    var world := Node3D.new()
    preview.add_child(world)
    pivot = Node3D.new()
    world.add_child(pivot)

    var environment := WorldEnvironment.new()
    var lighting := Environment.new()
    lighting.background_mode = Environment.BG_COLOR
    lighting.background_color = Color("#0a1720")
    lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    lighting.ambient_light_color = Color("#b6c4dc")
    lighting.ambient_light_energy = 0.7
    environment.environment = lighting
    world.add_child(environment)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-42, 35, 0)
    key.light_energy = 1.5
    world.add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-2.0, 2.5, 3.0)
    fill.light_energy = 0.8
    world.add_child(fill)

    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    world.add_child(camera)
    camera.current = true
    resized.connect(_frame_model)
    load_avatar()

func load_avatar() -> bool:
    if active_model != null:
        active_model.queue_free()
        active_model = null
    if not ResourceLoader.exists(MODEL_PATH):
        push_warning("NEKO_AVATAR_GLTF_NOT_INSTALLED: " + MODEL_PATH)
        return false
    var resource: Resource = load(MODEL_PATH)
    if not (resource is PackedScene):
        push_warning("NEKO_AVATAR_GLTF_NOT_SCENE")
        return false
    var root: Node = (resource as PackedScene).instantiate()
    if not (root is Node3D):
        root.queue_free()
        return false
    pivot.add_child(root)
    active_model = root as Node3D
    var fit: Dictionary = MODEL_FIT.fit_to_height(active_model, DISPLAY_HEIGHT)
    if not bool(fit.get("ok", false)):
        active_model.queue_free()
        active_model = null
        return false
    model_bounds = fit["bounds"]
    pivot.rotation.y = 0.0
    zoom_multiplier = 1.0
    _frame_model()
    return true

func _frame_model() -> void:
    if camera == null or preview == null or model_bounds.size.y <= 0.0:
        return
    var aspect: float = maxf(0.5, size.x / maxf(size.y, 1.0))
    var radius_x: float = maxf(absf(model_bounds.position.x), absf(model_bounds.end.x))
    var radius_z: float = maxf(absf(model_bounds.position.z), absf(model_bounds.end.z))
    var diameter: float = 2.0 * Vector2(radius_x, radius_z).length()
    camera.size = maxf(model_bounds.size.y, diameter / aspect) * 1.16 * zoom_multiplier
    var center_y: float = model_bounds.get_center().y
    camera.position = Vector3(0.0, center_y, maxf(model_bounds.size.y, diameter) + 2.5)
    camera.look_at(Vector3(0.0, center_y, 0.0), Vector3.UP)

func reset_view() -> void:
    if pivot == null:
        return
    pivot.rotation.y = 0.0
    zoom_multiplier = 1.0
    _frame_model()

func _zoom(factor: float) -> void:
    zoom_multiplier = clampf(zoom_multiplier * factor, 0.58, 2.3)
    _frame_model()

func _gui_input(event: InputEvent) -> void:
    if active_model == null:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
        else:
            touches.erase(event.index)
        accept_event()
    elif event is InputEventScreenDrag and touches.has(event.index):
        if touches.size() == 1:
            touches[event.index] = event.position
            pivot.rotation.y += event.relative.x * TAU / maxf(size.x, 1.0)
        elif touches.size() == 2:
            var fingers: Array = touches.keys()
            var before: float = (touches[fingers[0]] - touches[fingers[1]]).length()
            touches[event.index] = event.position
            var after: float = (touches[fingers[0]] - touches[fingers[1]]).length()
            if before > 1.0 and after > 1.0:
                _zoom(before / after)
        accept_event()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging_mouse = event.pressed
            accept_event()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(0.91)
            accept_event()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.09)
            accept_event()
    elif event is InputEventMouseMotion and dragging_mouse:
        pivot.rotation.y += event.relative.x * TAU / maxf(size.x, 1.0)
        accept_event()
    elif event is InputEventMagnifyGesture:
        _zoom(1.0 / maxf(event.factor, 0.1))
        accept_event()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        touches.clear()
        dragging_mouse = false
