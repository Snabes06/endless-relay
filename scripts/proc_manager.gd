extends Node3D

@export var player_path: NodePath = NodePath("../Player")
@export var obstacle_scene: PackedScene
@export var slope_scene: PackedScene
@export var lane_count: int = 3
@export var lane_width: float = 2.0
@export var spawn_ahead_min: float = 20.0
@export var spawn_ahead_max: float = 40.0
@export var recycle_behind: float = 8.0
@export var slope_chance: float = 0.25
@export var spawn_interval_z: float = 8.0
@export var debug: bool = true

var _player: Node3D
var _next_spawn_z: float = -20.0
var _spawned: Array[Node3D] = []

func _ready():
	_player = get_node_or_null(player_path)
	if _player == null:
		push_warning("ProcManager: player not found")
	_next_spawn_z = -spawn_ahead_min
	set_process(true)

func _process(_delta: float):
	if _player == null:
		_player = get_node_or_null(player_path)
		if _player == null:
			return
	var pz = _player.global_transform.origin.z
	# Spawn ahead as the player moves forward (-Z)
	while _next_spawn_z > pz - spawn_ahead_max:
		_spawn_one(_next_spawn_z)
		_next_spawn_z -= spawn_interval_z
	# Recycle behind
	for n in _spawned.duplicate():
		if n and n.is_inside_tree():
			if n.global_transform.origin.z > pz + recycle_behind:
				n.queue_free()
				_spawned.erase(n)

func _spawn_one(zpos: float):
	var roll = randf()
	if roll < slope_chance and slope_scene:
		var lane = randi() % lane_count
		var center = float(lane_count - 1) / 2.0
		var x = (lane - center) * lane_width
		var slope = slope_scene.instantiate()
		if slope is Node3D:
			var n3 = slope as Node3D
			n3.position = Vector3(x, 0, zpos)
			get_parent().add_child(n3)
			_spawned.append(n3)
			if debug:
				print("[PROC] slope lane=", lane, " z=", zpos)
			return
	if obstacle_scene:
		var lane = randi() % lane_count
		var center = float(lane_count - 1) / 2.0
		var x = (lane - center) * lane_width
		var inst = obstacle_scene.instantiate()
		if inst is Node3D:
			var n = inst as Node3D
			n.position = Vector3(x, 0, zpos)
			get_parent().add_child(n)
			_spawned.append(n)
			if debug:
				print("[PROC] obstacle lane=", lane, " z=", zpos)
