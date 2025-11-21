extends Area3D

@export var stamina_reward := 15.0
@export var momentum_reward := 12.0
@export var one_shot := true

func _ready():
    connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
    if body and body.has_method("apply_perfect_stride"):
        body.apply_perfect_stride(stamina_reward, momentum_reward)
        if one_shot:
            disable_temporarily()

func disable_temporarily():
    visible = false
    if has_method("set_monitoring"):
        set_deferred("monitoring", false)
    for child in get_children():
        if child is Timer:
            child.stop()

func reset():
    visible = true
    if has_method("set_monitoring"):
        set_deferred("monitoring", true)
    for child in get_children():
        if child is Timer:
            child.stop()
