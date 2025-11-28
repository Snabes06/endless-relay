extends Camera3D

@export var target_path: NodePath = NodePath("Player")
@export var offset_z_mode: Vector3 = Vector3(0, 4, 10) # player forward along -Z → camera behind at +Z
@export var offset_x_mode: Vector3 = Vector3(10, 4, 0) # player forward along -X → camera behind at +X
@export var look_offset: Vector3 = Vector3(0, 1, 0)
@export var smooth_speed: float = 8.0
@export var reorient_duration: float = 0.6
@export var debug: bool = false
@export var debug_interval: float = 1.0

var _target: Node3D = null
var _t_accum := 0.0
var _initialized := false
var _last_x_mode: bool = false
var _blend_t: float = 1.0
var _blend_start: Vector3 = Vector3.ZERO
var _blend_end: Vector3 = Vector3.ZERO

func _ready():
	current = true
	_target = get_node_or_null(target_path)
	if _target == null:
		push_warning("FollowCamera: target not found at path " + str(target_path))
	set_process(true)
	_initialized = true
	if debug:
		print("[FollowCamera] ready; cam pos=", global_transform.origin)
	# Ensure clip planes are reasonable
	near = 0.05
	far = 4000.0

func _process(delta):
	if not _initialized:
		return
	if _target == null:
		_target = get_tree().get_current_scene().get_node_or_null(target_path) if get_tree() and get_tree().get_current_scene() else get_node_or_null(target_path)
		if _target == null:
			return
	# Determine current mode from player flag (Player now exposes 'turned_x')
	var x_mode := false
	var turned_val = _target.get("turned_x")
	if turned_val != null:
		x_mode = bool(turned_val)

	# Handle smooth reorientation when mode changes
	if x_mode != _last_x_mode:
		_last_x_mode = x_mode
		_blend_t = 0.0
		_blend_start = _current_offset()
		_blend_end = offset_x_mode if x_mode else offset_z_mode

	# Compute blended offset
	var use_offset: Vector3 = _current_offset()
	var desired_pos = _target.global_transform.origin + use_offset
	# simple smooth lerp for position
	var new_pos = global_transform.origin.lerp(desired_pos, clamp(smooth_speed * delta, 0.0, 1.0))
	global_transform.origin = new_pos
	# Look directly at the player from the current offset (stable front-facing)
	var look_target = _target.global_transform.origin + look_offset
	look_at(look_target, Vector3.UP)
	# fail-safe: if we somehow look away (dot forward vs target direction too low) do a reset
	var to_target = (_target.global_transform.origin - global_transform.origin).normalized()
	var fwd = -global_transform.basis.z
	if fwd.dot(to_target) < 0.1:
		look_at(_target.global_transform.origin + look_offset, Vector3.UP)
	if debug:
		_t_accum += delta
		if _t_accum >= debug_interval:
			_t_accum = 0.0
			print("[FollowCamera] cam=", global_transform.origin, " target=", _target.global_transform.origin, " fwd=", fwd, " x_mode=", x_mode)

func _current_offset() -> Vector3:
	if _blend_t < 1.0:
		# Advance blend
		_blend_t = clamp(_blend_t + (1.0 / max(0.0001, reorient_duration)) * get_process_delta_time(), 0.0, 1.0)
		# Ease in-out for smoothness
		var t = _ease_in_out(_blend_t)
		return _blend_start.lerp(_blend_end, t)
	return offset_x_mode if _last_x_mode else offset_z_mode

func _ease_in_out(t: float) -> float:
	# Smoothstep-like curve
	return t * t * (3.0 - 2.0 * t)
