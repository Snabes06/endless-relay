extends Area3D

@export var speed_mod := 0.9
@export var stamina_mult := 1.2

func _ready():
    connect("body_entered", Callable(self, "_on_body_entered"))
    connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
    if body and body.has_method("set_terrain_mod"):
        body.set_terrain_mod(speed_mod, stamina_mult)

func _on_body_exited(body):
    if body and body.has_method("reset_terrain_mod"):
        body.reset_terrain_mod()
