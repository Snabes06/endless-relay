extends Area3D

@export var prompt_scene: PackedScene
@export var input_action: StringName = &"move_left" # will be overridden based on turn_direction
@export var turn_direction: String = "left" # "left" or "right"
@export var slow_time_scale: float = 0.3
@export var prompt_duration_sec: float = 1.5
@export var one_shot: bool = true
@export var ground_scene_x: PackedScene

var _active: bool = false

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	# Proactively clear obstacles near the turn and block further spawns in this zone
	var main := get_tree().current_scene
	if main:
		var proc := main.get_node_or_null("ProcManager")
		if proc:
			var my_pos := global_transform.origin
			# Compute forward coordinate based on current axis of ProcManager (before turn it's Z)
			var axis: String = "Z"
			if proc.has_method("get"):
				axis = String(proc.get("axis"))
			var coord := my_pos.z if axis == "Z" else my_pos.x
			# Prevent spawns in a small window around the corner and clear up to 3 existing
			if proc.has_method("set_no_spawn_zone"):
				proc.set_no_spawn_zone(coord, 10.0)
			if proc.has_method("clear_near"):
				proc.clear_near(coord, 12.0, 3)

func _on_body_entered(body: Node):
	if _active:
		return
	# Determine if player can turn in requested direction
	var can_turn := false
	if body:
		if turn_direction == "left" and body.has_method("start_turn_left"):
			can_turn = true
		elif turn_direction == "right" and body.has_method("start_turn_right"):
			can_turn = true
	if can_turn:
		_active = true
		# Disable spawning until turn accepted
		var main := get_tree().current_scene
		if main:
			var proc := main.get_node_or_null("ProcManager")
			if proc and proc.has_method("set"):
				proc.set("enabled", false)
		# Slow motion
		Engine.time_scale = slow_time_scale
		# Show prompt
		var p: Control = _get_prompt()
		if p != null:
			# Set correct input action based on direction
			input_action = &"move_left" if turn_direction == "left" else &"move_right"
			# Use setter if available to refresh hint; fall back to property set
			if p.has_method("set_input_action"):
				p.call("set_input_action", input_action)
			else:
				p.set("input_action", input_action)
				if p.has_method("refresh_hint"):
					p.call("refresh_hint")
			p.set("duration_sec", prompt_duration_sec)
			p.connect("accepted", Callable(self, "_on_prompt_accepted").bind(body))
			p.connect("timeout", Callable(self, "_on_prompt_timeout"))
			_get_ui_root().add_child(p)
	else:
		# Non-player entered; ignore
		pass

func _on_prompt_accepted(player: Node):
	# Restore time and commit turn in requested direction
	Engine.time_scale = 1.0
	var main := get_tree().current_scene
	var dir_sign := -1 if turn_direction == "left" else 1
	if player:
		if turn_direction == "left" and player.has_method("start_turn_left"):
			player.start_turn_left()
		elif turn_direction == "right" and player.has_method("start_turn_right"):
			player.start_turn_right()
		# Switch active ground to X-axis and enable its infinite recentering
		if main:
			var ground_z := main.get_node_or_null("GroundBody")
			if ground_z and ground_z.has_method("set"):
				ground_z.set("enabled", false)
			var ground_x := main.get_node_or_null("GroundBodyX")
			if ground_x == null and ground_scene_x:
				ground_x = ground_scene_x.instantiate()
				if ground_x:
					main.add_child(ground_x)
					# Center ground's Z directly under player to avoid falling off edge
					if ground_x is Node3D:
						var gb = ground_x as Node3D
						var t = gb.transform
						t.origin.z = player.global_transform.origin.z
						gb.transform = t
			if ground_x and ground_x.has_method("set"):
				ground_x.set("enabled", true)
				ground_x.set("axis", "X")
				ground_x.set("direction_sign", dir_sign)
			var proc := main.get_node_or_null("ProcManager")
			if proc:
				if proc.has_method("reset_for_axis"):
					proc.reset_for_axis("X", dir_sign, player)
				else:
					proc.set("axis", "X")
					proc.set("direction_sign", dir_sign)
				if proc.has_method("set"):
					proc.set("enabled", true)
				if proc.has_method("clear_near_box"):
					var p: Node3D = player
					var px = p.global_transform.origin.x
					var pz = p.global_transform.origin.z
					proc.clear_near_box(px, pz, 18.0, 6.0, 6)
	# Disable trigger if one_shot
	if one_shot:
		set_deferred("monitoring", false)
		queue_free()

func _on_prompt_timeout():
	Engine.time_scale = 1.0
	_active = false
	# Re-enable spawning if we disabled it on entry
	var main := get_tree().current_scene
	if main:
		var proc := main.get_node_or_null("ProcManager")
		if proc and proc.has_method("set"):
			proc.set("enabled", true)

func _get_prompt() -> Control:
	if prompt_scene:
		var inst = prompt_scene.instantiate()
		return inst as Control
	# fallback: load default scene if present
	if ResourceLoader.exists("res://ui/TurnPrompt.tscn"):
		var res = load("res://ui/TurnPrompt.tscn")
		if res:
			var node = res.instantiate()
			return node as Control
	return null

func _get_ui_root() -> Node:
	var main := get_tree().current_scene
	if main:
		var hud := main.get_node_or_null("HUD")
		if hud:
			return hud
	return get_tree().root
