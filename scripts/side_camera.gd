extends Camera3D

@export var target_path: NodePath = NodePath("../Player")
@export var offset: Vector3 = Vector3(14, 6, 0)
@export var look_ahead_z: float = -4.0
@export var enabled_follow: bool = true

var _target: Node3D

func _ready():
	_target = get_node_or_null(target_path)
	fov = 100.0

func _process(_delta):
	if not enabled_follow:
		return
	if _target == null:
		_target = get_node_or_null(target_path)
		if _target == null:
			return
	var tpos = _target.global_transform.origin
	var cam_pos = tpos + offset
	global_transform.origin = cam_pos
	var look_pos = Vector3(tpos.x, tpos.y, tpos.z + look_ahead_z)
	look_at(look_pos, Vector3.UP)
