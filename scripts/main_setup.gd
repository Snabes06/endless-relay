extends Node3D

func _ready():
    var cam: Camera3D = get_node_or_null("Player/Camera3D")
    if cam == null:
        cam = get_node_or_null("Camera3D")
    if cam:
        cam.current = true
    else:
        push_warning("MainSetup: Camera3D not found (checked Player/Camera3D and root)")