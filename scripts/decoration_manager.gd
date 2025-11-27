extends Node3D

@export var player_path: NodePath = NodePath("../Player")
@export var auto_load_from_folder: bool = true
@export var folder_path: String = "res://resources/LowPoly Environment Pack"
@export var prop_scenes: Array[PackedScene] = []
@export var exclude_name_contains: Array[String] = ["mount", "terrain", "environment", "mud"] # skip large/occluding meshes or muddy ground chunks
@export var grass_keywords: Array[String] = ["grass"]
@export var spawn_ahead_min: float = 20.0
@export var spawn_ahead_max: float = 60.0
@export var spawn_interval: float = 6.0 # base interval; can be overridden by speed-scaling
@export var min_interval: float = 4.0
@export var max_interval: float = 10.0
@export var ref_speed: float = 14.0 # speed at which interval approaches min_interval
@export var recycle_behind: float = 12.0
@export var max_active: int = 120
@export var playable_margin: float = 1.0 # extra padding beyond last lane center
@export var world_half_width_x: float = 20.0 # outer bound (e.g., half of ground width)
@export var min_band_gap: float = 2.0 # gap between playable edge and start of band
@export var random_yaw: bool = true
@export var min_scale: float = 0.8
@export var max_scale: float = 1.4
@export var y_offset: float = 0.0
@export var grass_extra_per_step: int = 5 # additional grass instances per spawn step
@export var grass_bundles_per_step: int = 2 # number of bundles to place per step (0 to disable bundles)
@export var grass_bundle_size: int = 5 # items per bundle
@export var grass_bundle_radius: float = 1.4 # radial jitter around bundle center in X
@export var grass_bundle_z_jitter: float = 2.0 # forward jitter range for grass within a bundle
@export var grass_min_scale: float = 0.6
@export var grass_max_scale: float = 1.1
@export var grass_max_active: int = 300
@export var debug: bool = false

var _player: Node3D = null
var _next_spawn_z: float = -20.0
var _spawned: Array[Node3D] = []
var _grass_scenes: Array[PackedScene] = []
var _grass_count: int = 0

func _ready():
	_player = get_node_or_null(player_path)
	if not _player:
		push_warning("DecorationManager: player not found")
	if auto_load_from_folder and prop_scenes.is_empty():
		_load_props_from_folder(folder_path)
	# Build grass subset from loaded props
	_grass_scenes.clear()
	for sc in prop_scenes:
		if sc and sc is PackedScene:
			var rp := String(sc.resource_path).to_lower()
			if _is_name_match(rp, grass_keywords):
				_grass_scenes.append(sc)
	if prop_scenes.is_empty():
		push_warning("DecorationManager: no prop scenes found; nothing will spawn")
	var pz = _get_player_z()
	_next_spawn_z = pz - spawn_ahead_min
	set_process(true)

func _process(_delta: float):
	if not _player:
		_player = get_node_or_null(player_path)
		if not _player:
			return
	var pz = _get_player_z()
	# Spawn ahead (remember player runs toward negative Z)
	var step = _effective_interval()
	while _should_spawn_more(pz):
		if prop_scenes.is_empty():
			break
		if _spawned.size() >= max_active:
			break
		# Spawn one general decoration
		_spawn_one(_next_spawn_z)
		# Spawn grass cover: prefer bundles; fallback to flat extra count
		if _grass_scenes.size() > 0 and _grass_count < grass_max_active:
			if grass_bundles_per_step > 0 and grass_bundle_size > 0:
				var bundles_to_place = grass_bundles_per_step
				for b in range(bundles_to_place):
					# Choose band and bundle center
					var half = _get_playable_half_width()
					var inner_left = -half - min_band_gap
					var inner_right = half + min_band_gap
					var left_min = -world_half_width_x
					var left_max = inner_left
					var right_min = inner_right
					var right_max = world_half_width_x
					var choose_left = (randi() % 2) == 0
					var cx: float = randf_range(left_min, left_max) if choose_left else randf_range(right_min, right_max)
					for j in range(grass_bundle_size):
						if _grass_count >= grass_max_active:
							break
						var sc_g = _grass_scenes[randi() % _grass_scenes.size()]
						var jitter_x = randf_range(-grass_bundle_radius, grass_bundle_radius)
						var x = cx + jitter_x
						# Clamp within band
						x = clamp(x, left_min, inner_left) if choose_left else clamp(x, inner_right, right_max)
						var jitter_z = randf_range(-grass_bundle_z_jitter, grass_bundle_z_jitter)
						_spawn_with_instance(x, _next_spawn_z + jitter_z, sc_g, true, grass_min_scale, grass_max_scale)
			else:
				if grass_extra_per_step > 0:
					var count = min(grass_extra_per_step, grass_max_active - _grass_count)
					for i in range(count):
						var sc = _grass_scenes[randi() % _grass_scenes.size()]
						var jitter_z = randf_range(-grass_bundle_z_jitter, grass_bundle_z_jitter)
						_spawn_with_scene(_next_spawn_z + jitter_z, sc, true, grass_min_scale, grass_max_scale)
		_next_spawn_z -= step
	# Recycle behind
	for n in _spawned.duplicate():
		if n and n.is_inside_tree():
			if n.global_transform.origin.z > pz + recycle_behind:
				if n.has_meta("is_grass") and bool(n.get_meta("is_grass")):
					_grass_count = max(0, _grass_count - 1)
				n.queue_free()
				_spawned.erase(n)

func _load_props_from_folder(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		push_warning("DecorationManager: cannot open folder: " + path)
		return
	d.list_dir_begin()
	var file_name = d.get_next()
	while file_name != "":
		if not d.current_is_dir():
			if file_name.to_lower().ends_with(".fbx") or file_name.to_lower().ends_with(".tscn"):
				var lower = file_name.to_lower()
				var skip := false
				for kw in exclude_name_contains:
					if lower.find(kw.to_lower()) != -1:
						skip = true
						break
				if not skip:
					var p = path.rstrip("/") + "/" + file_name
					var res = load(p)
					if res and res is PackedScene:
						prop_scenes.append(res)
		file_name = d.get_next()
	d.list_dir_end()
	if debug:
		print("[DecorationManager] loaded props:", prop_scenes.size())

func _get_player_z() -> float:
	return _player.global_transform.origin.z

func _get_player_speed() -> float:
	var sp: float = 0.0
	if _player and _player.has_method("get_current_speed"):
		sp = float(_player.call("get_current_speed"))
	return sp

func _effective_interval() -> float:
	# Scale interval inversely with speed: faster → denser (smaller interval)
	var speed = _get_player_speed()
	var t = clamp(speed / max(0.001, ref_speed), 0.0, 1.5)
	# Map t to [max_interval -> min_interval]
	var eff = lerp(max_interval, min_interval, clamp(t, 0.0, 1.0))
	# Never go below min_interval or above max_interval
	eff = clamp(eff, min_interval, max_interval)
	# If no speed is available, fall back to base spawn_interval within bounds
	if speed <= 0.0:
		eff = clamp(spawn_interval, min_interval, max_interval)
	return eff

func _is_name_match(name_lower: String, keywords: Array[String]) -> bool:
	for kw in keywords:
		if name_lower.find(kw.to_lower()) != -1:
			return true
	return false

func _get_playable_half_width() -> float:
	# Try to infer from player's lane settings if available
	var half = 8.0
	if _player:
		var lane_count = 0
		var lane_width = 0.0
		if _player.has_method("get"):
			var lc = _player.get("lane_count")
			var lw = _player.get("lane_width")
			if lc != null:
				lane_count = int(lc)
			if lw != null:
				lane_width = float(lw)
		if lane_count > 0 and lane_width > 0.0:
			var center = float(lane_count - 1) / 2.0
			half = center * lane_width + playable_margin
	return half

func _spawn_one(zpos: float) -> void:
	# Decide left or right band
	var half = _get_playable_half_width()
	var inner_left = -half - min_band_gap
	var inner_right = half + min_band_gap
	var left_min = -world_half_width_x
	var left_max = inner_left
	var right_min = inner_right
	var right_max = world_half_width_x
	var choose_left = (randi() % 2) == 0
	var x: float
	if choose_left:
		x = randf_range(left_min, left_max)
	else:
		x = randf_range(right_min, right_max)
	var scene: PackedScene = prop_scenes[randi() % prop_scenes.size()]
	_spawn_with_instance(x, zpos, scene, false, min_scale, max_scale)

func _spawn_with_scene(zpos: float, scene: PackedScene, is_grass: bool, smin: float, smax: float) -> void:
	# Decide band for grass as well
	var half = _get_playable_half_width()
	var inner_left = -half - min_band_gap
	var inner_right = half + min_band_gap
	var left_min = -world_half_width_x
	var left_max = inner_left
	var right_min = inner_right
	var right_max = world_half_width_x
	var choose_left = (randi() % 2) == 0
	var x: float = randf_range(left_min, left_max) if choose_left else randf_range(right_min, right_max)
	_spawn_with_instance(x, zpos, scene, is_grass, smin, smax)

func _spawn_with_instance(x: float, zpos: float, scene: PackedScene, is_grass: bool, smin: float, smax: float) -> void:
	var inst = scene.instantiate()
	if inst is Node3D:
		var n = inst as Node3D
		n.position = Vector3(x, y_offset, zpos)
		# Random yaw
		if random_yaw:
			var r = n.rotation
			r.y = randf_range(-PI, PI)
			n.rotation = r
		# Random uniform scale
		var s = randf_range(smin, smax)
		n.scale = Vector3(s, s, s)
		# Disable collisions if present
		_disable_collisions(n)
		# Mark if grass for accounting
		n.set_meta("is_grass", is_grass)
		if is_grass:
			_grass_count += 1
		get_parent().add_child(n)
		_spawned.append(n)

func _disable_collisions(n: Node) -> void:
	# Walk subtree and disable collision layers/masks
	if n is CollisionObject3D:
		var co = n as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
	for child in n.get_children():
		_disable_collisions(child)

func _should_spawn_more(pz: float) -> bool:
	var limit = pz - spawn_ahead_max
	return _next_spawn_z >= limit
