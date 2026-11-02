extends SubViewportContainer
## Lightweight 3D commander menu preview; hidden until an original GLB is installed.
## Static GLB can be previewed without a rig. Animation is optional.
const MODEL_FIT := preload("res://scripts/rts_character_fit.gd")
const MENU_PREVIEW_HEIGHT := 2.75
const MENU_FRONT_YAW_DEGREES := 90.0
const MODELS := [
    ["res://assets/characters/amina/preview.glb",
     "res://assets/characters/reina/preview.glb",
     "res://assets/characters/mira_kade/preview.glb",
     "res://assets/characters/lyra_voss/preview.glb"],
    ["", ""]
]
var preview: SubViewport
var pivot: Node3D
var active_model: Node3D

func _ready() -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
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
    var camera := Camera3D.new()
    camera.position = Vector3(0, 1.55, 3.0)
    camera.fov = 37.0
    world.add_child(camera)
    camera.look_at(Vector3(0, 1.35, 0), Vector3.UP)
    camera.current = true
    set_process(false)
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
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("visual", "menu_character_fit", {
            "target_height": fit["target_height"],
            "scale": fit["scale"]
        })
    for child in active_model.find_children("*", "AnimationPlayer", true, false):
        var animation_player: AnimationPlayer = child as AnimationPlayer
        for clip in animation_player.get_animation_list():
            if clip.to_lower().contains("idle"):
                animation_player.play(clip)
                break
    visible = true
    set_process(true)
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("visual", "3d_preview_loaded", {"faction": faction, "officer": officer})
    return true

func _set_missing() -> bool:
    set_process(false)
    visible = false
    return false

func _process(delta: float) -> void:
    if active_model != null:
        pivot.rotation.y += minf(delta, 0.1) * 0.20
