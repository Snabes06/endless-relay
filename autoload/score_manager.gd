extends Node

# Subway Surfers inspired scoring (distance-based):
# Score = int(distance_meters * multiplier) + coins * multiplier
# Distance measured along forward travel. Multiplier can be upgraded or boosted by streak events.

var multiplier: int = 1
var coins: int = 0
var high_score: int = 0
var score: int = 0

# Persistent leaderboard entries: Array of dictionaries {"name": String, "score": int}
var leaderboard: Array = []
const LEADERBOARD_PATH := "user://leaderboard.json"
const LEADERBOARD_SIZE := 10

func reset_run():
	coins = 0
	# multiplier may persist across runs if desired; keep as-is.

func compute_score(distance_units: float) -> int:
	# Treat 1 world unit as 1 point by default; tweak with a scalar if desired.
	score = int(distance_units * multiplier) + coins * multiplier
	if score > high_score:
		high_score = score
	return score

func add_coin(count: int = 1):
	coins += count

func boost_multiplier(amount: int, max_multiplier: int = 50):
	multiplier = clamp(multiplier + amount, 1, max_multiplier)

func set_multiplier(value: int):
	multiplier = max(1, value)

func _ready():
	load_leaderboard()

func add_leaderboard_entry(player_name: String, value: int) -> void:
	var n := player_name.strip_edges()
	if n == "":
		n = "Player"
	leaderboard.append({"name": n, "score": int(value)})
	# Sort descending by score
	leaderboard.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	# Trim
	while leaderboard.size() > LEADERBOARD_SIZE:
		leaderboard.pop_back()
	save_leaderboard()

func get_top_entries(max_items: int = LEADERBOARD_SIZE) -> Array:
	return leaderboard.slice(0, min(max_items, leaderboard.size()))

func save_leaderboard() -> void:
	var data = {"leaderboard": leaderboard}
	var json := JSON.stringify(data)
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(json)
		f.close()

func load_leaderboard() -> void:
	leaderboard = []
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		return
	var f := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed := JSON.new()
	var err := parsed.parse(txt)
	if err != OK:
		return
	var obj = parsed.data
	if typeof(obj) == TYPE_DICTIONARY and obj.has("leaderboard") and typeof(obj["leaderboard"]) == TYPE_ARRAY:
		leaderboard = obj["leaderboard"]
