extends Node

# Subway Surfers inspired scoring:
# Score = int(distance * multiplier) + coins * multiplier
# Distance measured in world units (convert as needed). Multiplier can be
# upgraded or boosted by streak events. Coins currently unused (keep 0 until implemented).

var multiplier: int = 1
var coins: int = 0
var high_score: int = 0
var score: int = 0

func reset_run():
	coins = 0
	# multiplier may persist across runs if desired; keep as-is.

func compute_score(time: float) -> int:
	score = int(time * multiplier) + coins * multiplier
	if score > high_score:
		high_score = score
	return score

func add_coin(count: int = 1):
	coins += count

func boost_multiplier(amount: int, max_multiplier: int = 50):
	multiplier = clamp(multiplier + amount, 1, max_multiplier)

func set_multiplier(value: int):
	multiplier = max(1, value)
