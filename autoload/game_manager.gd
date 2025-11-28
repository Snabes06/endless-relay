extends Node

signal player_died_signal(score: int)

var _resetting: bool = false
var chosen_model_path: String = ""

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

# Called when player death occurs
func notify_player_died():
	var tree := get_tree()
	var sm := tree.root.get_node_or_null("ScoreManager")
	var s := 0
	if sm:
		s = sm.score
	tree.paused = true
	emit_signal("player_died_signal", s)

func commit_and_reset(player_name: String) -> void:
	var tree := get_tree()
	var sm := tree.root.get_node_or_null("ScoreManager")
	if sm and sm.has_method("add_leaderboard_entry"):
		sm.add_leaderboard_entry(player_name, sm.score)
	tree.paused = false
	reset_level()

# Player model selection; set
func set_chosen_model_path(path: String) -> void:
	chosen_model_path = path if path != null else ""

# Player model selection; get
func get_chosen_model_path() -> String:
	return chosen_model_path
