extends CharacterBody3D

@export var forward_speed: float = 8.0
@export var gravity: float = -24.0
@export var jump_speed: float = 8.5
@export var lane_count: int = 3
@export var lane_width: float = 2.0
@export var lateral_speed: float = 12.0

var current_lane: int = 1
var target_x: float = 0.0
var velocity_y: float = 0.0
var ray_down: RayCast3D
var debug_frames: int = 0

func _ready():
	floor_snap_length = 0.6
	var center = float(lane_count - 1) / 2.0
	target_x = (current_lane - center) * lane_width
	ray_down = get_node_or_null("RayDown")

func _physics_process(delta: float):
	# Lateral interpolation
	var current_x = global_transform.origin.x
	var dx = target_x - current_x
	var lateral_v = dx * lateral_speed
	if abs(lateral_v * delta) > abs(dx):
		lateral_v = dx / max(delta, 0.0001)

	# Gravity + jump
	if not is_on_floor():
		velocity_y += gravity * delta
	else:
		velocity_y = 0.0
		if Input.is_action_just_pressed("jump"):
			velocity_y = jump_speed

	velocity.x = lateral_v
	velocity.y = velocity_y
	velocity.z = -forward_speed
	move_and_slide()

	# Direct downward ray + node ray for first frames
	if debug_frames < 120:
		var from = global_transform.origin
		var to = from + Vector3(0, -6, 0)
		var params = PhysicsRayQueryParameters3D.create(from, to)
		params.collision_mask = 1
		var hit = get_world_3d().direct_space_state.intersect_ray(params)
		if hit.is_empty():
			print("[PLAYER RAY] no hit underfoot z=", global_transform.origin.z)
		else:
			print("[PLAYER RAY] hit ", hit.get("collider"), " at ", hit.get("position"))
		var ray_hit = ray_down and ray_down.is_colliding()
		var ray_dist = -1.0
		if ray_hit:
			var hp = ray_down.get_collision_point()
			ray_dist = global_transform.origin.y - hp.y
		debug_frames += 1
		print("[PLAYER DBG] frame=", debug_frames, " y=", global_transform.origin.y, " vy=", velocity_y, " on_floor=", is_on_floor(), " ray_hit=", ray_hit, " ray_dist=", ray_dist)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.event_is_action(event, "move_left"):
			move_left()
		elif InputMap.event_is_action(event, "move_right"):
			move_right()

func move_left():
	current_lane = clamp(current_lane - 1, 0, lane_count - 1)
	var center = float(lane_count - 1) / 2.0
	target_x = (current_lane - center) * lane_width

func move_right():
	current_lane = clamp(current_lane + 1, 0, lane_count - 1)
	var center = float(lane_count - 1) / 2.0
	target_x = (current_lane - center) * lane_width

func is_performing_action(action_name: String) -> bool:
	if action_name == "jump":
		return not is_on_floor()
	return false

func set_terrain_mod(_speed_mod: float, _stamina_mult_in: float):
	pass

func reset_terrain_mod():
	pass
