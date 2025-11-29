extends Area3D

@export var momentum_boost: float = 1000
@export var one_shot: bool = true

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if body and body.has_method("apply_perfect_stride"):
		body.apply_perfect_stride(0.0, momentum_boost)
		if one_shot:
			_disable_temporarily()

func _disable_temporarily() -> void:
	if has_method("set_monitoring"):
		set_deferred("monitoring", false)
	visible = false
	for c in get_children():
		if c is Timer:
			c.stop()

func reset():
	if has_method("set_monitoring"):
		set_deferred("monitoring", true)
	visible = true
	for c in get_children():
		if c is Timer:
			c.stop()
