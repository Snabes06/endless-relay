@tool
extends EditorScript

func _run():
    var actions = ["move_left", "move_right", "sprint", "use_momentum", "jump", "slide", "vault"]
    for action in actions:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
    # Note: this helper ensures actions exist. Bindings should be set inside the editor Input Map as preferred.
    print("Input actions registered (if missing).")
