extends StaticBody3D

@export var length_z: float = 2000.0
@export var recenter_threshold_ratio: float = 0.8
@export var debug: bool = true

var _player: Node3D = null

func _ready():
    _player = get_tree().get_current_scene().get_node_or_null("Player")
    set_physics_process(true)
    if debug:
        print("[InfiniteGround] ready length_z=", length_z, " threshold_ratio=", recenter_threshold_ratio)

func _physics_process(_delta):
    if _player == null:
        _player = get_tree().get_current_scene().get_node_or_null("Player")
        if _player == null:
            return
    # Player moves toward negative Z. Keep ground centered ahead so player never reaches edge.
    var ground_z = global_transform.origin.z
    var half_len = length_z * 0.5
    var _min_z = ground_z - half_len
    var threshold = ground_z - (length_z * recenter_threshold_ratio)
    if _player.global_transform.origin.z < threshold:
        # Shift ground so player stays near center: move center to player_z + half_len * 0.2 (slightly ahead)
        var new_z = _player.global_transform.origin.z + half_len * 0.2
        var x = global_transform.origin.x
        var y = global_transform.origin.y
        global_transform.origin = Vector3(x, y, new_z)
        if debug:
            print("[InfiniteGround] recentered ground to z=", new_z, " player_z=", _player.global_transform.origin.z)