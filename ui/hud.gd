extends CanvasLayer

var score_label: Label = null
var high_score_label: Label = null
@onready var leaderboard_list: VBoxContainer = $LeaderboardPanel/VBox/LeaderboardList
@onready var name_panel: Panel = $NameEntryPanel
@onready var name_line: LineEdit = $NameEntryPanel/VBox/NameLine
@onready var submit_button: Button = $NameEntryPanel/VBox/SubmitButton

var _start_z: float = 0.0
var _player: CharacterBody3D = null
var _score_manager: Node = null
var _game_manager: Node = null
var _pending_score: int = 0


func _ready():
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
	_update_leaderboard()
	_game_manager = get_tree().root.get_node_or_null("GameManager")
	if _game_manager and _game_manager.has_signal("player_died_signal"):
		_game_manager.connect("player_died_signal", Callable(self, "_on_player_died"))
	_update_score_display(0, _get_high_score())

func _process(_delta):
	if not _player:
		return
	var _elapsed = _player.get_current_time_elapsed()
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
	if _score_manager:
		return _score_manager.high_score
	return 0

func _update_score_display(score: int, high_score: int):
	if score_label:
		score_label.text = "Score: %d" % score
	if high_score_label:
		high_score_label.text = "High: %d" % high_score

func _update_leaderboard():
	if not leaderboard_list:
		return
	for c in leaderboard_list.get_children():
		c.queue_free()
	if _score_manager and _score_manager.has_method("get_top_entries"):
		var entries: Array = _score_manager.get_top_entries(10)
		var i := 1
		for e in entries:
			var lbl := Label.new()
			lbl.text = "%d. %s - %d" % [i, String(e.get("name", "Player")), int(e.get("score", 0))]
			leaderboard_list.add_child(lbl)
			i += 1

func _on_player_died(score: int) -> void:
	_pending_score = score
	if name_panel:
		name_panel.visible = true
		if name_line:
			name_line.text = ""
			name_line.grab_focus()
		if submit_button:
			if submit_button.is_connected("pressed", Callable(self, "_on_submit_pressed")):
				submit_button.disconnect("pressed", Callable(self, "_on_submit_pressed"))
			submit_button.connect("pressed", Callable(self, "_on_submit_pressed"))

func _on_submit_pressed() -> void:
	var user := name_line.text if name_line else "Player"
	if _game_manager and _game_manager.has_method("commit_and_reset"):
		_game_manager.commit_and_reset(user)
	if name_panel:
		name_panel.visible = false
