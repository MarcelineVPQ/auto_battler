class_name EloCalculator
extends RefCounted

## Standard ELO rating calculator.
## K=32, Floor=100, Default=1000.

const K_FACTOR: int = 32
const RATING_FLOOR: int = 100
const DEFAULT_RATING: int = 1000


## Calculate expected win probability for player_rating vs opponent_rating.
static func expected_score(player_rating: int, opponent_rating: int) -> float:
	return 1.0 / (1.0 + pow(10.0, float(opponent_rating - player_rating) / 400.0))


## Calculate rating change after a match.
## actual: 1.0 for win, 0.0 for loss.
## Returns signed integer change (positive = gain, negative = loss).
static func calculate_change(player_rating: int, opponent_rating: int, actual: float) -> int:
	var expected := expected_score(player_rating, opponent_rating)
	return int(round(K_FACTOR * (actual - expected)))


## Calculate new rating after a match, clamped to floor.
static func new_rating(player_rating: int, opponent_rating: int, won: bool) -> int:
	var actual := 1.0 if won else 0.0
	var change := calculate_change(player_rating, opponent_rating, actual)
	return maxi(player_rating + change, RATING_FLOOR)


## Get the signed change for display purposes (e.g., "+16" or "-8").
static func rating_change_text(player_rating: int, opponent_rating: int, won: bool) -> String:
	var actual := 1.0 if won else 0.0
	var change := calculate_change(player_rating, opponent_rating, actual)
	if change >= 0:
		return "+%d" % change
	return "%d" % change
