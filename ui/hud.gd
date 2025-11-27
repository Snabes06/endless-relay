extends CanvasLayer

var score_label: Label = null
var high_score_label: Label = null

var _start_z: float = 0.0
var _player: CharacterBody3D = null
var _score_manager: Node = null


func _ready():
	# fetch labels safely
	score_label = get_node_or_null("ScoreLabel")
	high_score_label = get_node_or_null("HighScoreLabel")
	if not score_label or not high_score_label:
		print("[HUD] Score labels missing; will skip score updates until present.")
	# locate player in scene (assumes HUD sibling or parent has Player)
	_player = get_tree().current_scene.get_node_or_null("Player")
	if _player:
		_start_z = _player.global_transform.origin.z
	else:
		print("[HUD] Player node not found for scoring")
	_score_manager = get_tree().root.get_node_or_null("ScoreManager")
	if _score_manager and _score_manager.has_method("reset_run"):
		_score_manager.reset_run()
	_update_score_display(0, _get_high_score())

## Deprecated external HUD APIs kept as no-ops for compatibility
func update_hud(_stamina: float, _pace: float, _momentum: float, _burst_ready: bool):
	pass

func show_perfect():
	pass

func show_obstacle():
	pass

func show_event(_event_name: String):
	pass

func _process(_delta):
	if not _player:
		return
	var _elapsed = _player.get_current_time_elapsed()
	# Distance along -Z since start (player moves toward negative Z)
	var current_z = _player.global_transform.origin.z
	var distance = (_start_z - current_z)
	if distance < 0:
		distance = 0
	var score = _compute_score(distance)
	_update_score_display(score, _get_high_score())

func _compute_score(distance: float) -> int:
	if _score_manager and _score_manager.has_method("compute_score"):
		return _score_manager.compute_score(distance)
	return int(distance) # fallback

func _get_high_score() -> int:
	# Autoload script defines high_score; direct access is safe if node exists.
	if _score_manager:
		return _score_manager.high_score
	return 0

func _update_score_display(score: int, high_score: int):
	if score_label:
		score_label.text = "Score: %d" % score
	if high_score_label:
		high_score_label.text = "High: %d" % high_score
