extends StaticBody3D

@export var player_path: NodePath = NodePath("../Player")
@export var length_z: float = 2000.0
@export var axis: String = "Z" # "Z" or "X"
@export var direction_sign: int = -1 # -1 forward toward negative axis, +1 toward positive
@export var enabled: bool = true # allow toggling recenter logic on/off
# Deprecated: using ratio > 0.5 creates a gap before recenter. Kept for backward compat but ignored if front_margin set.
@export var recenter_ratio: float = 0.6
@export var ahead_offset_ratio: float = 0.35 # portion of length to keep ahead after recenter
@export var front_margin: float = 120.0 # recenter when player is this close to front (negative) edge
@export var debug: bool = false

var _player: Node3D

func _ready():
    _player = get_node_or_null(player_path)
    if debug:
        print("[InfiniteGroundSimple] ready length_z=", length_z, " recenter_ratio=", recenter_ratio)

func _physics_process(_delta):
    if not enabled:
        return
    if _player == null:
        _player = get_node_or_null(player_path)
        if _player == null:
            return
    var half = length_z * 0.5
    var t = global_transform
    if axis == "Z":
        var center = t.origin.z
        var p = _player.global_transform.origin.z
        var front_edge = center + direction_sign * half
        var should_recenter := false
        if direction_sign < 0:
            should_recenter = p < front_edge + front_margin
        else:
            should_recenter = p > front_edge - front_margin
        if should_recenter:
            var new_center = p + direction_sign * length_z * ahead_offset_ratio
            t.origin.z = new_center
            global_transform = t
            if debug:
                print("[InfiniteGroundSimple] recentered Z. p=", p, " new_center=", new_center)
    else:
        var centerx = t.origin.x
        var px = _player.global_transform.origin.x
        var front_edge_x = centerx + direction_sign * half
        var recenter := false
        if direction_sign < 0:
            recenter = px < front_edge_x + front_margin
        else:
            recenter = px > front_edge_x - front_margin
        if recenter:
            var new_cx = px + direction_sign * length_z * ahead_offset_ratio
            t.origin.x = new_cx
            global_transform = t
            if debug:
                print("[InfiniteGroundSimple] recentered X. px=", px, " new_center=", new_cx)
