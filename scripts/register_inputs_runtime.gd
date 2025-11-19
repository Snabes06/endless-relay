extends Node

# Ensures all required InputMap actions exist at runtime, with default bindings if missing.
func _ready():
	var actions = [
		{"name": "move_left", "key": KEY_A},
		{"name": "move_right", "key": KEY_D},
		{"name": "sprint", "key": KEY_SHIFT},
		{"name": "use_momentum", "key": KEY_SPACE},
		{"name": "jump", "key": KEY_W},
		{"name": "slide", "key": KEY_S},
		{"name": "vault", "key": KEY_V},
		{"name": "toggle_side_cam", "key": KEY_F2}
	]
	for action in actions:
		if not InputMap.has_action(action.name):
			InputMap.add_action(action.name)
			var ev := InputEventKey.new()
			ev.keycode = action.key
			InputMap.action_add_event(action.name, ev)
	print("[register_inputs_runtime] Input actions ensured.")
