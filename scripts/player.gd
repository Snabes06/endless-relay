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
var lateral_velocity := Vector3.ZERO
var velocity_y := 0.0

var terrain_speed_mod := 1.0
var terrain_stamina_mult := 1.0

var hud = null

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
    var cfg_path := "res://config/gameplay.json"
    if FileAccess.file_exists(cfg_path):
        var cfg := FileAccess.open(cfg_path, FileAccess.ModeFlags.READ)
        var text := cfg.get_as_text()
        cfg.close()
        var data = JSON.parse_string(text)
        if data.error == OK:
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

    # lateral interpolation
    var current_x = global_transform.origin.x
    var dx = target_x - current_x
    var move_x = clamp(dx * lateral_speed * delta, -abs(dx), abs(dx))

    # gravity / jump
    if not is_on_floor():
        velocity_y += gravity * delta
    else:
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

    var move = Vector3(move_x, velocity_y * delta, -speed * delta)
    translate(move)

    # update HUD
    if hud:
        hud.call("update_hud", stamina, effective_pace, momentum, momentum >= burst_cost)

func _input(event):
    if event.is_action_pressed("move_left"):
        move_left()
    elif event.is_action_pressed("move_right"):
        move_right()
    elif event.is_action_just_pressed("use_momentum"):
        _try_burst()
    elif event.is_action_just_pressed("slide"):
        _try_slide()
    elif event.is_action_just_pressed("vault"):
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
