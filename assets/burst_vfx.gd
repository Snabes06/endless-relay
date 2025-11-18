extends Node3D

@onready var t := $Timer

func _ready():
    if t:
        t.connect("timeout", Callable(self, "_on_Timer_timeout"))
    visible = false

func play():
    visible = true
    if t:
        t.start()

func reset():
    visible = false
    if t:
        t.stop()

func _on_Timer_timeout():
    visible = false
