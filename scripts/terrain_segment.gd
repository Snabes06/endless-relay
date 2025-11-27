extends Node3D

@export var length_z: float = 40.0
@export var width_x: float = 6.0
@export var height_y: float = 0.5
@export var lane_count: int = 6
@export var lane_width: float = 2.0
@export var material: Material = null
@export var debug: bool = false

var start_z: float
var end_z: float

func _ready():
	# Compute bounds assuming segment centered at origin in X, Z spanning negative direction (player runs toward -Z)
	start_z = global_transform.origin.z
	end_z = start_z - length_z
	if debug:
		print("[TerrainSegment] ready at z=", start_z, " -> ", end_z)

func get_lane_x(lane_index: int) -> float:
	var center = float(lane_count - 1) / 2.0
	return (lane_index - center) * lane_width

func contains_z(z_val: float) -> bool:
	return z_val <= start_z and z_val >= end_z

func position_at(local_z: float, lane_index: int) -> Vector3:
	# local_z should be between 0 and -length_z
	var x = get_lane_x(lane_index)
	return Vector3(x, 0.0, global_transform.origin.z + local_z)

func set_origin_z(front_z: float):
	var t = global_transform
	t.origin.z = front_z
	global_transform = t
	start_z = front_z
	end_z = front_z - length_z
	if debug:
		print("[TerrainSegment] moved to z=", start_z, " -> ", end_z)
