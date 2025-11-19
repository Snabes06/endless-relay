extends Node3D

@export var segment_scene: PackedScene
@export var initial_segments: int = 6
@export var segment_length: float = 40.0
@export var lane_count: int = 3
@export var recycle_buffer: float = 20.0
@export var player_path: NodePath = NodePath("../Player")
@export var spawn_front_offset: float = 5.0
@export var debug: bool = true

var _player: Node3D
var _segments: Array = []

func _ready():
	_player = get_node_or_null(player_path)
	if segment_scene == null:
		push_warning("SegmentManager: segment_scene not set")
		return
	var front_z = spawn_front_offset
	if _player != null:
		front_z = _player.global_transform.origin.z + spawn_front_offset
	for i in range(initial_segments):
		var seg = segment_scene.instantiate()
		add_child(seg)
		if seg.has_method("initialize_at"):
			seg.initialize_at(front_z)
		elif seg.has_method("set_origin_z"):
			seg.set_origin_z(front_z)
		_segments.append(seg)
		front_z -= segment_length
	if debug:
		print("[SegmentManager] spawned ", initial_segments, " segments")
	set_physics_process(true)

func _physics_process(_delta):
	if _player == null:
		_player = get_node_or_null(player_path)
		if _player == null:
			return
	# Player moves toward negative Z; recycle segments behind player beyond buffer
	var player_z = _player.global_transform.origin.z
	# Debug: verify a segment actually covers the player's Z
	var covering = null
	for s in _segments:
		if s.contains_z(player_z):
			covering = s
			break
	if covering == null and debug:
		var ranges := []
		for s2 in _segments:
			ranges.append("[" + str(s2.start_z) + ", " + str(s2.end_z) + "]")
		print("[SegmentManager DBG] No segment covers player_z=", player_z, " segment ranges=", ", ".join(ranges))
	for seg in _segments:
		# When the player is beyond this segment's end (more negative by buffer), recycle it ahead
		if player_z < seg.end_z - recycle_buffer:
			var front_end = _find_frontmost_end_z()
			var new_start = front_end
			if seg.has_method("set_origin_z"):
				seg.set_origin_z(new_start)
			if debug:
				print("[SegmentManager] recycled segment start_z=", new_start, " (front_end=", front_end, ")")

func _find_frontmost_end_z() -> float:
	# Most negative end_z among segments (furthest ahead in travel direction)
	var min_end = 0.0
	var first = true
	for seg in _segments:
		if first:
			min_end = seg.end_z
			first = false
		else:
			if seg.end_z < min_end:
				min_end = seg.end_z
	return min_end
