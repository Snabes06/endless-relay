extends Camera3D

@export var target_path: NodePath = NodePath("Player")
@export var offset: Vector3 = Vector3(0, 4, 10)
@export var look_offset: Vector3 = Vector3(0, 1, 0)
@export var smooth_speed: float = 8.0
@export var yaw_offset_deg: float = 0.0
@export var debug: bool = true
@export var debug_interval: float = 1.0

var _target: Node3D = null
var _t_accum := 0.0
var _initialized := false

func _ready():
    current = true
    _target = get_node_or_null(target_path)
    if _target == null:
        push_warning("FollowCamera: target not found at path " + str(target_path))
    set_process(true)
    _initialized = true
    print("[FollowCamera] ready; cam pos=", global_transform.origin)
    # Ensure clip planes are reasonable
    near = 0.05
    far = 2000.0

func _process(delta):
    if not _initialized:
        return
    if _target == null:
        _target = get_tree().get_current_scene().get_node_or_null(target_path) if get_tree() and get_tree().get_current_scene() else get_node_or_null(target_path)
        if _target == null:
            return
    var desired_pos = _target.global_transform.origin + offset
    # simple smooth lerp
    var new_pos = global_transform.origin.lerp(desired_pos, clamp(smooth_speed * delta, 0.0, 1.0))
    global_transform.origin = new_pos
    # Look directly at the player from the current offset (stable front-facing)
    var look_target = _target.global_transform.origin + look_offset
    look_at(look_target, Vector3.UP)
    # Ensure camera forward points toward negative Z travel direction
    # Player travels along -Z, so we place camera slightly ahead (+Z) and look back.
    # fail-safe: if we somehow look away (dot forward vs target direction > 0.99) do a reset
    var to_target = (_target.global_transform.origin - global_transform.origin).normalized()
    var fwd = -global_transform.basis.z
    if fwd.dot(to_target) < 0.1:
        look_at(_target.global_transform.origin + look_offset, Vector3.UP)
    if debug:
        _t_accum += delta
        if _t_accum >= debug_interval:
            _t_accum = 0.0
            print("[FollowCamera] cam=", global_transform.origin, " target=", _target.global_transform.origin, " fwd=", fwd)