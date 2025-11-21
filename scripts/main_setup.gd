extends Node3D

func _ready():
	var cam: Camera3D = get_node_or_null("Player/Camera3D")
	if cam == null:
		cam = get_node_or_null("Camera3D")
	if cam:
		cam.current = true
	else:
		push_warning("MainSetup: Camera3D not found (checked Player/Camera3D and root)")
	# Align player to ground at start to avoid spawn glitches
	var player: CharacterBody3D = get_node_or_null("Player")
	if player:
		var from = player.global_transform.origin + Vector3(0, 5.0, 0)
		var to = player.global_transform.origin + Vector3(0, -10.0, 0)
		var params = PhysicsRayQueryParameters3D.create(from, to)
		params.collision_mask = 1
		var hit = get_world_3d().direct_space_state.intersect_ray(params)
		if not hit.is_empty():
			var pos = player.global_transform.origin
			pos.y = hit.get("position").y + 1.0
			player.global_transform.origin = pos
			player.velocity.y = 0.0
			print("[MainSetup] Player aligned to ground at y=", pos.y)

	# Ground diagnostics & fallback
	var ground_body := get_node_or_null("GroundBody")
	if ground_body == null:
		push_warning("[MainSetup] GroundBody missing; inline ground should exist.")
	else:
		var has_shape := false
		for c in ground_body.get_children():
			if c is CollisionShape3D:
				has_shape = true
		if not has_shape:
			push_warning("[MainSetup] GroundBody has no collider.")
		else:
			print("[MainSetup] GroundBody + collider OK")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.event_is_action(event, "toggle_side_cam"):
			var main_cam: Camera3D = get_node_or_null("Camera3D")
			var side_cam: Camera3D = get_node_or_null("DebugSideCam")
			if main_cam and side_cam:
				if side_cam.current:
					side_cam.current = false
					main_cam.current = true
					print("[Camera] Switched to main camera")
				else:
					main_cam.current = false
					side_cam.current = true
					print("[Camera] Switched to side camera")
