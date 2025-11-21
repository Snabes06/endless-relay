extends Area3D

@export var stamina_damage := 20.0
@export var momentum_loss := 20.0
@export var one_shot := true
@export var required_action := "" # "jump", "slide", "vault" or empty for no specific action

var _disabled := false

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if not body:
		return
	var bname = ""
	if body.has_method("get_name"):
		bname = body.get_name()
	else:
		bname = str(body)
	# Debug print removed for production cleanliness
	# If an action is required to avoid the obstacle, ask the body if it's performing it
	if required_action != "" and body.has_method("is_performing_action"):
		var ok = body.is_performing_action(required_action)
		if ok:
			# successful avoid — optionally grant a small momentum bonus
			if body.has_method("apply_perfect_stride"):
				body.apply_perfect_stride(0.0, 6.0)
			if one_shot:
				disable_temporarily()
			return
	# Deadly spike behavior: reset player to start instead of applying damage
	# Now triggers full level reload via GameManager if available
	# Only treat as deadly if collider looks like the player (has reset_to_start)
	if body.has_method("reset_to_start"):
		var gm := get_tree().root.get_node_or_null("GameManager")
		if gm and gm.has_method("reset_level"):
			gm.reset_level()
		else:
			body.reset_to_start()
		if one_shot:
			disable_temporarily()
		return
	# Fallback: if no reset method, keep old damage behavior
	if body.has_method("apply_obstacle_hit"):
		body.apply_obstacle_hit(stamina_damage, momentum_loss)
		if one_shot:
			disable_temporarily()

func disable_temporarily():
	# hide and stop monitoring collisions so it's effectively inactive
	_disabled = true
	# Use deferred to avoid modifying physics state during signal emission
	if has_method("set_monitoring"):
		set_deferred("monitoring", false)
	# disable any collision shapes if present
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
		if child is Timer:
			child.stop()
	visible = false

func reset():
	_disabled = false
	visible = true
	if has_method("set_monitoring"):
		set_deferred("monitoring", true)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", false)
		if child is Timer:
			child.stop()
