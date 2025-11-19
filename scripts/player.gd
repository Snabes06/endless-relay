extends CharacterBody3D

@export var base_speed := 8.0
@export var sprint_multiplier := 1.45
@export var lane_count := 3
@export var lane_width := 2.0
@export var lateral_speed := 12.0
@export var gravity := -24.0
@export var jump_speed := 8.5
@export var jump_cost := 8

# Resources
var stamina := 100.0
var stamina_max := 100.0
var stamina_regen_rate := 6.0
var stamina_drain_rate := 12.0

var momentum := 0.0
var momentum_max := 100.0
var momentum_gain_rate := 2.0
var momentum_gain_window := {"min":0.95, "max":1.15}

var burst_cost := 40
var burst_duration := 1.6
var burst_speed_mult := 1.6
var burst_timer := 0.0
var burst_active := false

# runtime
var current_lane := 1
var target_x := 0.0
var velocity_y := 0.0 # vertical component

var terrain_speed_mod := 1.0
var terrain_stamina_mult := 1.0

var hud = null
var debug_floor_frames := 0
var ray_down: RayCast3D = null
var fall_recover_enabled := true
@export var fall_recover_y := 1.2
@export var fall_min_y := -2.0

# Actions: slide / vault
@export var slide_duration := 0.9
@export var slide_stamina_cost := 6
@export var slide_collider_height := 0.6

@export var vault_duration := 0.6
@export var vault_stamina_cost := 10
@export var vault_jump_speed := 6.5

var is_sliding := false
var slide_timer := 0.0
var saved_collider_height := 0.0

var is_vaulting := false
var vault_timer := 0.0

func _ready():
	# load tuning if present
	floor_snap_length = 0.6
	var cfg_path := "res://config/gameplay.json"
	if FileAccess.file_exists(cfg_path):
		var cfg := FileAccess.open(cfg_path, FileAccess.ModeFlags.READ)
		var text := cfg.get_as_text()
		cfg.close()
		var data = JSON.parse_string(text)
		if data is Dictionary and data.has("error") and data.error == OK:
			var obj = data.result
			stamina_max = obj.get("stamina_max", stamina_max)
			stamina = stamina_max
			stamina_regen_rate = obj.get("stamina_regen_rate", stamina_regen_rate)
			stamina_drain_rate = obj.get("stamina_drain_rate", stamina_drain_rate)
			momentum_max = obj.get("momentum_max", momentum_max)
			momentum_gain_rate = obj.get("momentum_gain_rate", momentum_gain_rate)
			momentum_gain_window = obj.get("momentum_gain_window", momentum_gain_window)
			burst_cost = obj.get("burst_cost", burst_cost)
			burst_duration = obj.get("burst_duration", burst_duration)
			burst_speed_mult = obj.get("burst_speed_mult", burst_speed_mult)
			base_speed = obj.get("base_speed", base_speed)
			sprint_multiplier = obj.get("sprint_multiplier", sprint_multiplier)
			lane_count = obj.get("lane_count", lane_count)
			lane_width = obj.get("lane_width", lane_width)

	# find HUD if present
	hud = get_node_or_null("../HUD")
	var center = float(lane_count - 1) / 2.0
	target_x = (current_lane - center) * lane_width
	ray_down = get_node_or_null("RayDown")

func _physics_process(delta):
	# forward velocity
	var pace_mult := 1.0
	if Input.is_action_pressed("sprint") and stamina > 0:
		pace_mult = sprint_multiplier
		stamina -= stamina_drain_rate * terrain_stamina_mult * delta
	else:
		# regen if at sustainable pace
		stamina += stamina_regen_rate * delta

	stamina = clamp(stamina, 0, stamina_max)

	# momentum gain when within window
	var effective_pace := pace_mult
	if effective_pace >= momentum_gain_window.min and effective_pace <= momentum_gain_window.max:
		momentum += momentum_gain_rate * delta
	momentum = clamp(momentum, 0, momentum_max)

	# burst handling
	if burst_active:
		burst_timer -= delta
		if burst_timer <= 0:
			burst_active = false

	var speed = base_speed * pace_mult * terrain_speed_mod
	if burst_active:
		speed *= burst_speed_mult

	# lateral interpolation (velocity based)
	var current_x = global_transform.origin.x
	var dx = target_x - current_x
	var lateral_v = dx * lateral_speed
	# clamp so we don't overshoot in one frame
	if abs(lateral_v * delta) > abs(dx):
		lateral_v = dx / max(delta, 0.0001)

	# gravity / jump using velocity_y
	if not is_on_floor():
		velocity_y += gravity * delta
	else:
		velocity_y = 0.0
		if Input.is_action_just_pressed("jump") and stamina >= jump_cost:
			velocity_y = jump_speed
			stamina -= jump_cost

	# slide timer handling
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			_end_slide()

	# vault timer handling
	if is_vaulting:
		vault_timer -= delta
		if vault_timer <= 0:
			is_vaulting = false

	# Compose velocity per second for CharacterBody3D
	velocity.x = lateral_v
	velocity.y = velocity_y
	velocity.z = -speed
	move_and_slide()

	# Collision details (first 120 frames)
	if debug_floor_frames < 120:
		for i in range(get_slide_collision_count()):
			var c = get_slide_collision(i)
			if c:
				var collider = c.get_collider()
				var cname = ""
				if collider:
					if collider.has_method("get_name"):
						cname = collider.get_name()
					else:
						cname = str(collider)
				print("[PLAYER COLL] idx=", i, " normal=", c.get_normal(), " travel=", c.get_travel(), " collider=", cname)
				if cname == "Ground":
					print("[PLAYER COLL] Ground contact confirmed")

	# Fall recovery safeguard (run every frame after movement)
	if fall_recover_enabled and global_transform.origin.y < fall_min_y:
		var pos = global_transform.origin
		pos.y = fall_recover_y
		global_transform.origin = pos
		velocity.y = 0
		print("[PLAYER RECOVER] Teleported to y=", fall_recover_y, " after falling below ", fall_min_y)

	# Debug ground contact for first 120 physics frames
	if debug_floor_frames < 120:
		debug_floor_frames += 1
		var ray_hit = ray_down and ray_down.is_colliding()
		var ray_dist = -1.0
		if ray_hit:
			var hit_pos = ray_down.get_collision_point()
			ray_dist = global_transform.origin.y - hit_pos.y
		print("[PLAYER DBG] frame=", debug_floor_frames, " y=", global_transform.origin.y, " vy=", velocity_y, " on_floor=", is_on_floor(), " slide_collisions=", get_slide_collision_count(), " layer=", collision_layer, " mask=", collision_mask, " ray_hit=", ray_hit, " ray_dist=", ray_dist)

	# update HUD
	if hud:
		hud.call("update_hud", stamina, effective_pace, momentum, momentum >= burst_cost)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.event_is_action(event, "move_left"):
			move_left()
		elif InputMap.event_is_action(event, "move_right"):
			move_right()
		elif InputMap.event_is_action(event, "use_momentum"):
			_try_burst()
		elif InputMap.event_is_action(event, "slide"):
			_try_slide()
		elif InputMap.event_is_action(event, "vault"):
			_try_vault()

func _try_slide():
	if is_sliding or is_vaulting:
		return
	if stamina >= slide_stamina_cost and is_on_floor():
		stamina -= slide_stamina_cost
		_start_slide()

func _start_slide():
	var col = get_node_or_null("Collision")
	if col and col.shape and col.shape is CapsuleShape3D:
		var s = col.shape
		saved_collider_height = s.height
		s.height = slide_collider_height
	is_sliding = true
	slide_timer = slide_duration

func _end_slide():
	var col = get_node_or_null("Collision")
	if col and col.shape and col.shape is CapsuleShape3D and saved_collider_height > 0:
		col.shape.height = saved_collider_height
	is_sliding = false

func _try_vault():
	if is_vaulting or is_sliding:
		return
	if stamina >= vault_stamina_cost and is_on_floor():
		stamina -= vault_stamina_cost
		is_vaulting = true
		vault_timer = vault_duration
		velocity_y = vault_jump_speed

func is_performing_action(action_name: String) -> bool:
	match action_name:
		"slide":
			return is_sliding
		"vault":
			return is_vaulting
		"jump":
			return not is_on_floor()
	return false

func move_left():
	current_lane = clamp(current_lane - 1, 0, lane_count - 1)
	var center = float(lane_count - 1) / 2.0
	target_x = (current_lane - center) * lane_width

func move_right():
	current_lane = clamp(current_lane + 1, 0, lane_count - 1)
	var center = float(lane_count - 1) / 2.0
	target_x = (current_lane - center) * lane_width

func _try_burst():
	if momentum >= burst_cost and not burst_active:
		momentum -= burst_cost
		burst_active = true
		burst_timer = burst_duration
		# spawn VFX if available
		var vfx = get_node_or_null("BurstVFX")
		if vfx:
			vfx.call("play")

func apply_perfect_stride(stamina_amt: float, momentum_amt: float):
	stamina = clamp(stamina + stamina_amt, 0, stamina_max)
	momentum = clamp(momentum + momentum_amt, 0, momentum_max)
	if hud:
		hud.call("show_perfect")

func apply_obstacle_hit(stamina_damage: float, momentum_loss: float):
	stamina = clamp(stamina - stamina_damage, 0, stamina_max)
	momentum = clamp(momentum - momentum_loss, 0, momentum_max)
	if hud:
		hud.call("show_obstacle")

func set_terrain_mod(speed_mod: float, stamina_mult_in: float):
	terrain_speed_mod = speed_mod
	terrain_stamina_mult = stamina_mult_in

func reset_terrain_mod():
	terrain_speed_mod = 1.0
	terrain_stamina_mult = 1.0
