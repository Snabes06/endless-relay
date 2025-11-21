extends CharacterBody3D

@export var base_speed: float = 8.0
@export var max_speed: float = 22.0
@export var speed_accel_per_sec: float = 0.18 # linear acceleration term
@export var accel_curve_power: float = 1.0 # 1 = linear, <1 fast early, >1 slow early
@export var gravity: float = -24.0
@export var jump_speed: float = 8.5
@export var lane_count: int = 3
@export var lane_width: float = 2.0
@export var lateral_speed: float = 12.0
@export var turn_duration: float = 0.0 # no blend; kept for potential future use

var current_lane: int = 1
var target_x: float = 0.0
var velocity_y: float = 0.0
var ray_down: RayCast3D
var debug_frames: int = 0
var _spawn_pos: Vector3
var _lane_center: float = 0.0
var _elapsed: float = 0.0
var _score_manager: Node = null
var turned_x: bool = false # true after any horizontal (X-axis) turn, left or right
var turn_x_sign: int = 0 # -1 for forward along -X, +1 for forward along +X
var target_z: float = 0.0
var _lateral_origin_z: float = 0.0

func _ready():
	floor_snap_length = 0.6
	_lane_center = float(lane_count - 1) / 2.0
	target_x = (current_lane - _lane_center) * lane_width
	_spawn_pos = global_transform.origin
	ray_down = get_node_or_null("RayDown")
	_score_manager = get_tree().root.get_node_or_null("ScoreManager")

func _physics_process(delta: float):
	_elapsed += delta
	var current_speed = _compute_forward_speed()
	# Instant turn mode; no interpolation branch
	# Lateral interpolation depends on direction (non-turning)
	var lateral_v := 0.0
	if not turned_x:
		var current_x = global_transform.origin.x
		var dx = target_x - current_x
		lateral_v = dx * lateral_speed
		if abs(lateral_v * delta) > abs(dx):
			lateral_v = dx / max(delta, 0.0001)
	else:
		var current_z = global_transform.origin.z
		var dz = target_z - current_z
		lateral_v = dz * lateral_speed
		if abs(lateral_v * delta) > abs(dz):
			lateral_v = dz / max(delta, 0.0001)

	# Gravity + jump
	if not is_on_floor():
		velocity_y += gravity * delta
	else:
		velocity_y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity_y = jump_speed

	if not turned_x:
		velocity.x = lateral_v
		velocity.y = velocity_y
		velocity.z = -current_speed
	else:
		# After turning, forward is along X with sign turn_x_sign; lateral along Z
		velocity.x = turn_x_sign * current_speed
		velocity.y = velocity_y
		velocity.z = lateral_v
	move_and_slide()


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.event_is_action(event, "move_left"):
			move_left()
		elif InputMap.event_is_action(event, "move_right"):
			move_right()

func move_left():
	current_lane = clamp(current_lane - 1, 0, lane_count - 1)
	if not turned_x:
		target_x = (current_lane - _lane_center) * lane_width
	else:
		target_z = _lateral_origin_z + (current_lane - _lane_center) * (-lane_width)

func move_right():
	current_lane = clamp(current_lane + 1, 0, lane_count - 1)
	if not turned_x:
		target_x = (current_lane - _lane_center) * lane_width
	else:
		target_z = _lateral_origin_z + (current_lane - _lane_center) * (-lane_width)

func is_performing_action(action_name: String) -> bool:
	if action_name == "jump":
		return not is_on_floor()
	return false

func set_terrain_mod(_speed_mod: float, _stamina_mult_in: float):
	pass

func reset_terrain_mod():
	pass

# Called by deadly obstacles (spikes) to send player back to start
func reset_to_start():
	# Reposition to recorded spawn position with a slight upward offset to avoid immediate re-collision
	var pos = _spawn_pos
	pos.y += 0.5
	global_transform.origin = pos
	# Reset lane & lateral targeting
	current_lane = 1
	target_x = (current_lane - _lane_center) * lane_width
	# Clear velocities
	velocity = Vector3.ZERO
	velocity_y = 0.0
	_elapsed = 0.0

func start_turn_left():
	# Immediate 90° left turn: face -X, preserve position
	turned_x = true
	turn_x_sign = -1
	rotation.y = -PI * 0.5
	_lane_center = float(lane_count - 1) / 2.0
	var lane_offset = (current_lane - _lane_center) * (-lane_width)
	_lateral_origin_z = global_transform.origin.z - lane_offset
	target_z = global_transform.origin.z
	velocity.x = 0.0
	velocity.z = 0.0

func start_turn_right():
	# Immediate 90° right turn: face +X, preserve position
	turned_x = true
	turn_x_sign = 1
	rotation.y = PI * 0.5
	_lane_center = float(lane_count - 1) / 2.0
	var lane_offset = (current_lane - _lane_center) * (-lane_width)
	_lateral_origin_z = global_transform.origin.z - lane_offset
	target_z = global_transform.origin.z
	velocity.x = 0.0
	velocity.z = 0.0

# Removed angle helper functions (not needed for instant turn)

func _compute_forward_speed() -> float:
	# Subway Surfers style: speed increases over time, capped; multiplier can raise cap.
	var mult := 1
	# Direct property access; ScoreManager defines 'multiplier'. Remove invalid has_variable usage.
	if _score_manager:
		mult = _score_manager.multiplier
	var max_cap = max_speed + (mult - 1) * 0.8
	var inc = speed_accel_per_sec * pow(_elapsed, accel_curve_power)
	return clamp(base_speed + inc, base_speed, max_cap)


func get_current_speed() -> float:
	return _compute_forward_speed()

func get_current_time_elapsed() -> float:
	return _elapsed
