extends Area3D

# The turn mechanic is disabled. This trigger self-destructs on ready and does nothing.

func _ready():
	# Remove this trigger so no prompt or turn can occur.
	set_deferred("monitoring", false)
	queue_free()
