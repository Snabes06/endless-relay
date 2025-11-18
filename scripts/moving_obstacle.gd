extends Area3D

@export var amplitude := 1.5
@export var speed := 2.5
@export var stamina_damage := 18.0
@export var momentum_loss := 12.0
@export var one_shot := true

var _t := 0.0
var _start_x := 0.0

func _ready():
    _start_x = global_transform.origin.x
    connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta):
    _t += delta * speed
    var nx = _start_x + sin(_t) * amplitude
    var pos = global_transform.origin
    pos.x = nx
    global_transform = Transform3D(global_transform.basis, pos)

func _on_body_entered(body):
    if body and body.has_method("apply_obstacle_hit"):
        body.apply_obstacle_hit(stamina_damage, momentum_loss)
        if one_shot:
            disable_temporarily()

func disable_temporarily():
    set_monitoring(false)
    visible = false
    for c in get_children():
        if c is CollisionShape3D:
            c.disabled = true

func reset():
    set_monitoring(true)
    visible = true
    for c in get_children():
        if c is CollisionShape3D:
            c.disabled = false
