extends StaticBody3D

@export var player_path: NodePath = NodePath("../Player")
@export var length_z: float = 2000.0
@export var recenter_ratio: float = 0.6 # when player passes 60% toward negative end, recenter
@export var ahead_offset_ratio: float = 0.2 # place ground slightly ahead after recenter
@export var debug: bool = true

var _player: Node3D

func _ready():
    _player = get_node_or_null(player_path)
    if debug:
        print("[InfiniteGroundSimple] ready length_z=", length_z, " recenter_ratio=", recenter_ratio)

func _physics_process(_delta):
    if _player == null:
        _player = get_node_or_null(player_path)
        if _player == null:
            return
    var center_z = global_transform.origin.z
    var _half = length_z * 0.5 # unused; kept for clarity if extending logic later
    var player_z = _player.global_transform.origin.z
    # ground negative extent is center_z - half toward travel direction (-Z)
    var recenter_threshold = center_z - (length_z * recenter_ratio)
    if player_z < recenter_threshold:
        var new_center_z = player_z + length_z * ahead_offset_ratio
        var t = global_transform
        t.origin.z = new_center_z
        global_transform = t
        if debug:
            print("[InfiniteGroundSimple] recentered ground center_z=", new_center_z, " player_z=", player_z)
