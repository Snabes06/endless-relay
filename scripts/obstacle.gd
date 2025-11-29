extends Area3D

@export var stamina_damage := 20.0
@export var momentum_loss := 20.0
@export var one_shot := true
@export var required_action := "" # "jump", "slide", "vault" or empty for no specific action

# Visual model settings
const CACTUS_SCENE_PATH := "res://resources/Prickly pear cactus.glb"
@export var model_scene_path: String = CACTUS_SCENE_PATH
@export var model_scale: Vector3 = Vector3(0.7, 0.7, 0.7)
@export var model_offset: Vector3 = Vector3(0, 0.2, 0)

var _disabled := false

func _ready():
	_setup_visual()
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if not body:
		return
	var _bname = ""
	if body.has_method("get_name"):
		_bname = body.get_name()
	else:
		_bname = str(body)
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
	# Deadly spike behavior: trigger death flow via GameManager when available
	# Only treat as deadly if collider looks like the player (has reset_to_start)
	if body.has_method("reset_to_start"):
		var gm := get_tree().root.get_node_or_null("GameManager")
		if gm and gm.has_method("notify_player_died"):
			gm.notify_player_died()
		else:
			# Fallback to old behavior if no GameManager death flow
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
	# Re-roll random Y rotation on reuse
	_randomize_yaw()

# --- Visual setup ---
func _setup_visual() -> void:
	var holder: Node3D = null
	var existing := get_node_or_null("Visual")
	if existing and existing is Node3D and not (existing is MeshInstance3D):
		holder = existing
	else:
		if existing and existing is MeshInstance3D:
			remove_child(existing)
			existing.queue_free()
		holder = Node3D.new()
		holder.name = "Visual"
		add_child(holder)
	# Clear old children
	for c in holder.get_children():
		c.queue_free()
	var res = load(model_scene_path)
	if res is PackedScene:
		var inst = res.instantiate()
		holder.add_child(inst)
	holder.scale = model_scale
	holder.position = model_offset
	_randomize_yaw()
	_fit_visual_to_ground(holder)

func _randomize_yaw() -> void:
	var holder: Node3D = get_node_or_null("Visual")
	if holder and holder is Node3D:
		var y = randf() * 360.0
		var r = holder.rotation_degrees
		r.y = y
		holder.rotation_degrees = r

func _fit_visual_to_ground(holder: Node3D) -> void:
	if holder == null:
		return
	var result := _compute_visual_bottom(holder)
	if result.get("has", false):
		var bottom := float(result["bottom"])
		holder.position.y += -bottom + 0.02

func _compute_visual_bottom(holder: Node3D) -> Dictionary:
	var state := {
		"has": false,
		"bottom": 0.0
	}
	var start_xf := Transform3D(Basis().scaled(holder.scale), Vector3.ZERO)
	for c in holder.get_children():
		_compute_bottom_recursive(c, start_xf, state)
	return state

func _compute_bottom_recursive(n: Node, xf: Transform3D, state: Dictionary) -> void:
	if not (n is Node3D):
		return
	var nx := xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var aabb: AABB = (n as MeshInstance3D).get_aabb()
		var min_y := INF
		for i in range(8):
			var corner := aabb.get_endpoint(i)
			var world := nx * corner
			if world.y < min_y:
				min_y = world.y
		if not state["has"]:
			state["bottom"] = min_y
			state["has"] = true
		else:
			state["bottom"] = min(state["bottom"], min_y)
	for c in n.get_children():
		_compute_bottom_recursive(c, nx, state)
