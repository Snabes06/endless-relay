extends Node

var _resetting: bool = false
var chosen_model_path: String = "" # Path to selected player model scene (FBX/TSCN)

# Full level reset triggered by deadly spikes
func reset_level():
	if _resetting:
		return
	_resetting = true
	var tree := get_tree()
	if not tree:
		return
	var current := tree.current_scene
	var path := ""
	if current and current.scene_file_path != "":
		path = current.scene_file_path
	if path != "":
		# Defer the change so we don't conflict with physics or signal flush
		tree.call_deferred("change_scene_to_file", path)
	else:
		# Fallback if scene path unavailable
		tree.call_deferred("reload_current_scene")
	# Schedule clearing reset flag shortly after scene swap completes
	call_deferred("_schedule_reset_flag_clear")

func _schedule_reset_flag_clear():
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.1 # small delay to ensure new scene loaded
	add_child(timer)
	timer.connect("timeout", Callable(self, "_clear_resetting"))
	timer.start()

func _clear_resetting():
	_resetting = false

# --- Player model selection API ---
func set_chosen_model_path(path: String) -> void:
	chosen_model_path = path if path != null else ""

func get_chosen_model_path() -> String:
	return chosen_model_path
