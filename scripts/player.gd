extends CharacterBody3D

@export var base_speed: float = 8.0
@export var max_speed: float = 22.0
@export var speed_accel_per_sec: float = 0.18 # linear acceleration term
@export var accel_curve_power: float = 1.0 # accel curve
@export var gravity: float = -24.0
@export var jump_speed: float = 8.5
@export var lane_count: int = 6
@export var lane_width: float = 2.0
@export var lateral_speed: float = 12.0

# Visual model and animation
@export var model_scene: PackedScene = preload("res://resources/FBX/Apatosaurus.fbx")
@export var model_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var model_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var model_yaw_degrees: float = 180.0

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

# Model/animation state
var _model_holder: Node3D = null
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""

# Temporary speed boost mechanics (adds to computed forward speed)
@export var boost_decay_per_sec: float = 3.0
var _speed_boost: float = 0.0
var _max_extra_boost: float = 14.0

func _ready():
	floor_snap_length = 0.6
	_lane_center = float(lane_count - 1) / 2.0
	target_x = (current_lane - _lane_center) * lane_width
	_spawn_pos = global_transform.origin
	ray_down = get_node_or_null("RayDown")
	_score_manager = get_tree().root.get_node_or_null("ScoreManager")
	# Load and attach model if configured
	_model_holder = get_node_or_null("Model")
	if _model_holder == null:
		_model_holder = Node3D.new()
		_model_holder.name = "Model"
		add_child(_model_holder)
	# If a chosen model exists in GameManager, override exported model_scene.
	var gm := get_tree().root.get_node_or_null("GameManager")
	if gm and gm.has_method("get_chosen_model_path"):
		var chosen_path: String = gm.get_chosen_model_path()
		if chosen_path != "":
			var loaded := load(chosen_path)
			if loaded is PackedScene:
				model_scene = loaded
			else:
				print_debug("Chosen model path does not point to a PackedScene: %s" % chosen_path)
	if model_scene:
		var inst = model_scene.instantiate()
		if inst:
			_model_holder.add_child(inst)
			# Apply transform (scale, yaw, offset)
			_model_holder.scale = model_scale
			var r = _model_holder.rotation_degrees
			r.y = model_yaw_degrees
			_model_holder.rotation_degrees = r
			_model_holder.position = model_offset
			# Find animation player in the instance
			_anim_player = _find_anim_player(_model_holder)
			if _anim_player:
				# Try to start with idle/run depending on state
				_play_best(["Idle", "idle", "Run", "run"]) 

func _physics_process(delta: float):
	_elapsed += delta
	var current_speed = _compute_forward_speed()
	# Continuous lateral input: A/D (move_left/right) create an axis; clamp within lane bounds
	var lateral_v := 0.0
	if not turned_x:
		var axis = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var current_x = global_transform.origin.x
		var min_x = (0.0 - _lane_center) * lane_width
		var max_x = (float(lane_count - 1) - _lane_center) * lane_width
		var desired_x = clamp(current_x + axis * lateral_speed * delta, min_x, max_x)
		lateral_v = (desired_x - current_x) / max(delta, 0.0001)
	else:
		# If turning were enabled, use Z lateral; currently unused because turning is disabled
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

	# Decay temporary speed boost
	if _speed_boost > 0.0:
		_speed_boost = max(0.0, _speed_boost - boost_decay_per_sec * delta)

	# Animation selection
	if _anim_player:
		var on_floor = is_on_floor()
		var speed = get_current_speed()
		if not on_floor:
			_play_best(["Jump", "jump", "Air", "air", "Fall", "fall"])
		else:
			if speed < 1.0:
				_play_best(["Idle", "idle", "Stand", "stand"]) 
			else:
				_play_best(["Run", "run", "Walk", "walk"]) 
		# Safety: if animation stopped unexpectedly while running, restart a loopable clip
		if not _anim_player.is_playing() and on_floor and speed >= 1.0:
			_play_best(["Run", "run", "Walk", "walk"]) 

	# Update current_lane to nearest based on position for systems that rely on it
	if not turned_x:
		var cx = global_transform.origin.x
		var idxf = cx / lane_width + _lane_center
		current_lane = clamp(int(round(idxf)), 0, lane_count - 1)

func is_performing_action(action_name: String) -> bool:
	if action_name == "jump":
		return not is_on_floor()
	return false

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
	# Ensure turn state is reset (no X-axis mode)
	turned_x = false
	turn_x_sign = 0

func _compute_forward_speed() -> float:
	# Current multiplier
	var mult := 1
	if _score_manager:
		mult = _score_manager.multiplier
	var max_cap = max_speed + (mult - 1) * 0.8
	var inc = speed_accel_per_sec * pow(_elapsed, accel_curve_power)
	return clamp(base_speed + inc + _speed_boost, base_speed, max_cap + _max_extra_boost)

# Speed api; get
func get_current_speed() -> float:
	return _compute_forward_speed()

# Elapsed time api; get
func get_current_time_elapsed() -> float:
	return _elapsed

# --- Model/Animation helpers ---
func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found = _find_anim_player(c)
		if found:
			return found
	return null

func _play_best(names: Array[String]) -> void:
	if _anim_player == null:
		return
	var clips: PackedStringArray = _anim_player.get_animation_list()
	var chosen: String = ""
	# choose first clip matching any preferred token
	for want in names:
		var w = want.to_lower()
		for c in clips:
			if String(c).to_lower().find(w) != -1:
				chosen = String(c)
				break
		if chosen != "":
			break
	if chosen == "" and clips.size() > 0:
		chosen = String(clips[0])
	if chosen != "" and chosen != _current_anim:
		_current_anim = chosen
		# Ensure loop mode for typical locomotion/idle clips
		var lower = chosen.to_lower()
		var should_loop := lower.find("run") != -1 or lower.find("walk") != -1 or lower.find("idle") != -1 or lower.find("stand") != -1
		_set_anim_loop_mode(chosen, should_loop)
		_anim_player.play(chosen, 0.12)

func _set_anim_loop_mode(anim_name: String, loop: bool) -> void:
	if _anim_player == null:
		return
	var anim: Animation = _anim_player.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

# External hooks from game objects to grant a short speed boost (and optional stamina)
func apply_perfect_stride(_stamina_reward: float, momentum_reward: float) -> void:
	# Stamina not modeled; momentum_reward converted to temporary speed boost
	_speed_boost = clamp(_speed_boost + float(momentum_reward), 0.0, _max_extra_boost)
