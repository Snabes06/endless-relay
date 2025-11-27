extends Node3D

@export var player_path: NodePath = NodePath("../Player")
@export var axis: String = "Z" # "Z" or "X"; determines forward direction
@export var direction_sign: int = -1 # -1 for -Z/-X, +1 for +Z/+X (Z uses -1 by default)
@export var obstacle_scene: PackedScene
@export var slope_scene: PackedScene
@export var lane_count: int = 6
@export var lane_width: float = 2.0
@export var spawn_ahead_min: float = 20.0
@export var spawn_ahead_max: float = 40.0
@export var recycle_behind: float = 8.0
@export var slope_chance: float = 0.25
@export var spawn_interval_z: float = 8.0
@export var debug: bool = false
@export var enabled: bool = true
@export var turn_trigger_scene: PackedScene
@export var turn_trigger_chance: float = 0.04 # low probability per spawn step
@export var turn_trigger_min_gap: float = 120.0 # minimum forward distance between turn triggers

var _last_turn_spawn_coord: float = -1e9

var _player: Node3D
var _next_spawn_pos: float = -20.0
var _spawned: Array[Node3D] = []
var _no_spawn_center: float = 0.0
var _no_spawn_half: float = 0.0
var _lateral_origin: float = 0.0

func _ready():
	_player = get_node_or_null(player_path)
	if _player == null:
		push_warning("ProcManager: player not found")
	var p = _get_player_forward_coord()
	_next_spawn_pos = p + direction_sign * spawn_ahead_min
	set_process(true)

func _process(_delta: float):
	if not enabled:
		return
	if _player == null:
		_player = get_node_or_null(player_path)
		if _player == null:
			return
	var pcoord = _get_player_forward_coord()
	# Spawn ahead along current axis.
	while _should_spawn_more(pcoord):
		# Opportunistic lane swap trigger spawning (only before first turn, on Z axis)
		if axis == "Z" and turn_trigger_scene and turn_trigger_chance > 0.0:
			var player_turned := false
			if _player:
				var tv = _player.get("turned_x")
				if tv != null:
					player_turned = bool(tv)
			if not player_turned:
				var gap_ok: bool = abs(_next_spawn_pos - _last_turn_spawn_coord) >= turn_trigger_min_gap
				var active_triggers := get_tree().get_nodes_in_group("turn_trigger").size() > 0
				if gap_ok and not active_triggers and randf() < turn_trigger_chance:
					_spawn_turn_trigger(_next_spawn_pos)
					_last_turn_spawn_coord = _next_spawn_pos
		# Skip spawning within a configured no-spawn zone (e.g., around a turn)
		if _is_in_no_spawn(_next_spawn_pos):
			_next_spawn_pos += direction_sign * spawn_interval_z
			continue
		_spawn_one(_next_spawn_pos)
		_next_spawn_pos += direction_sign * spawn_interval_z
	# Recycle behind
	for n in _spawned.duplicate():
		if n and n.is_inside_tree():
			if _is_behind(n, pcoord):
				n.queue_free()
				_spawned.erase(n)

func _spawn_one(pos_along: float):
	var roll = randf()
	if roll < slope_chance and slope_scene:
		var lane = randi() % lane_count
		var center = float(lane_count - 1) / 2.0
		var lateral = (lane - center) * lane_width
		var slope = slope_scene.instantiate()
		if slope is Node3D:
			var n3 = slope as Node3D
			n3.position = _compose_position(pos_along, lateral)
			_apply_orientation(n3)
			get_parent().add_child(n3)
			_spawned.append(n3)
			# Debug print removed (enable by setting debug=true)
			return
	if obstacle_scene:
		var lane = randi() % lane_count
		var center = float(lane_count - 1) / 2.0
		var lateral2 = (lane - center) * lane_width
		var inst = obstacle_scene.instantiate()
		if inst is Node3D:
			var n = inst as Node3D
			n.position = _compose_position(pos_along, lateral2)
			_apply_orientation(n)
			get_parent().add_child(n)
			_spawned.append(n)
			# Debug print removed (enable by setting debug=true)

func _compose_position(forward_coord: float, lateral_coord: float) -> Vector3:
	# Map forward axis along axis, lateral perpendicular
	if axis == "Z":
		return Vector3(_lateral_origin + lateral_coord, 0, forward_coord)
	else:
		# forward along X; lateral along Z (invert lateral to keep left/right consistent if desired)
		return Vector3(forward_coord, 0, _lateral_origin + lateral_coord)

func _get_player_forward_coord() -> float:
	return _player.global_transform.origin.z if axis == "Z" else _player.global_transform.origin.x

func _should_spawn_more(pcoord: float) -> bool:
	# Want to spawn until next is out to spawn_ahead_max in front of player
	var limit = pcoord + direction_sign * spawn_ahead_max
	# We should keep spawning while next lies closer than limit in forward direction
	return (direction_sign > 0 and _next_spawn_pos <= limit) or (direction_sign < 0 and _next_spawn_pos >= limit)

func _is_behind(n: Node3D, pcoord: float) -> bool:
	var ncoord = n.global_transform.origin.z if axis == "Z" else n.global_transform.origin.x
	var behind_limit = pcoord - direction_sign * recycle_behind
	return (direction_sign > 0 and ncoord < behind_limit) or (direction_sign < 0 and ncoord > behind_limit)

func _is_in_no_spawn(pos_along: float) -> bool:
	return _no_spawn_half > 0.0 and abs(pos_along - _no_spawn_center) <= _no_spawn_half

func set_no_spawn_zone(center: float, half_extent: float) -> void:
	_no_spawn_center = center
	_no_spawn_half = max(half_extent, 0.0)

func clear_near(center: float, radius: float, max_count: int = 3) -> int:
	var removed := 0
	for n in _spawned.duplicate():
		if n and n.is_inside_tree():
			var ncoord = n.global_transform.origin.z if axis == "Z" else n.global_transform.origin.x
			if abs(ncoord - center) <= radius:
				n.queue_free()
				_spawned.erase(n)
				removed += 1
				if removed >= max_count:
					break
	return removed

func clear_near_box(forward_center: float, lateral_center: float, forward_radius: float, lateral_radius: float, max_count: int = 6) -> int:
	var removed := 0
	for n in _spawned.duplicate():
		if n and n.is_inside_tree():
			var f = n.global_transform.origin.z if axis == "Z" else n.global_transform.origin.x
			var l = n.global_transform.origin.x if axis == "Z" else n.global_transform.origin.z
			if abs(f - forward_center) <= forward_radius and abs(l - lateral_center) <= lateral_radius:
				n.queue_free()
				_spawned.erase(n)
				removed += 1
				if removed >= max_count:
					break
	return removed

func reset_for_axis(new_axis: String, new_direction_sign: int, player: Node3D) -> void:
	axis = new_axis
	direction_sign = new_direction_sign
	# Reset spawn cursor to be ahead of the player along the new axis
	var pcoord = player.global_transform.origin.z if axis == "Z" else player.global_transform.origin.x
	_next_spawn_pos = pcoord + direction_sign * spawn_ahead_min
	# Align lateral lanes with player's current lateral coordinate so spawns line up with the runner
	var center = float(lane_count - 1) / 2.0
	var player_lane: int = int(center)
	if player:
		var lane_val = player.get("current_lane")
		if lane_val != null:
			player_lane = int(lane_val)
	if axis == "Z":
		var px = player.global_transform.origin.x
		var lane_offset = (player_lane - center) * lane_width
		_lateral_origin = px - lane_offset
	else:
		var pz = player.global_transform.origin.z
		# After left turn, lateral offset uses negative lane width in player code; reflect here
		var lane_offset2 = (player_lane - center) * (-lane_width)
		_lateral_origin = pz - lane_offset2
	# Clear existing spawned instances to avoid leftover hazards at the corner
	for n in _spawned.duplicate():
		if n and n.is_inside_tree():
			n.queue_free()
		_spawned.erase(n)
	# Clear any previous no-spawn zones by default; caller may set a new one
	_no_spawn_center = 0.0
	_no_spawn_half = 0.0

func _apply_orientation(n: Node3D) -> void:
	var yaw: float = 0.0
	var use_axis: String = axis
	var use_dir: int = direction_sign
	if _player:
		if _player and _player.get("turned_x") != null and bool(_player.get("turned_x")):
			use_axis = "X"
			# For X axis, direction_sign may be -1 (left turn) or +1 (right turn)
			use_dir = direction_sign
		else:
			use_axis = "Z"
			use_dir = direction_sign
	# Map asset forward (-Z) to current forward axis.
	if use_axis == "Z":
		yaw = 0.0 if use_dir < 0 else PI
	else:
		# On X axis: -X → +90°, +X → -90°
		yaw = PI * 0.5 if use_dir < 0 else -PI * 0.5
	var r = n.rotation
	r.y = yaw
	n.rotation = r

func _spawn_turn_trigger(pos_along: float) -> void:
	var inst = turn_trigger_scene.instantiate()
	if inst is Node3D:
		var n = inst as Node3D
		# Center lane (no lateral offset)
		var lateral := 0.0
		n.position = _compose_position(pos_along, lateral)
		# Random direction selection
		var turn_dir = "left" if (randi() % 2 == 0) else "right"
		n.set("turn_direction", turn_dir)
		# Add to scene & group for tracking
		get_parent().add_child(n)
		n.add_to_group("turn_trigger")
		if debug:
			print("[ProcManager] Spawned turn trigger at", pos_along)
