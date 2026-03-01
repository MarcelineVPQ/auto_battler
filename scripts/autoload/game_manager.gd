extends Node

enum Phase { WAVE_SELECT, PREP, BATTLE, RESULT }

signal phase_changed(new_phase: Phase)
signal round_ended(player_won: bool)
signal gold_changed(new_amount: int)
signal lives_changed(new_lives: int)
signal farms_changed
signal game_over

const MAX_ROUNDS: int = 20
const STARTING_GOLD: int = 10
const STARTING_LIVES: int = 5
const STARTING_FARMS: int = 5
const BASE_FARM_COST: int = 1
const BASE_INCOME: int = 12
const INCOME_SCALE_ROUND: int = 7
const VICTORY_BONUS: int = 2
const INTEREST_RATE: float = 0.10
const MAX_INTEREST: int = 5
const REROLL_COST: int = 2

var current_phase: Phase = Phase.WAVE_SELECT
var current_round: int = 0
var gold: int = STARTING_GOLD
var lives: int = STARTING_LIVES
var farms: int = STARTING_FARMS
var farm_purchases: int = 0
var last_round_won: bool = false
var gold_snapshot: int = 0
var first_loss_given: bool = false

func change_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)

func start_battle() -> void:
	change_phase(Phase.BATTLE)

func end_battle(player_won: bool) -> void:
	last_round_won = player_won
	change_phase(Phase.RESULT)
	if not player_won:
		lives -= 1
		lives_changed.emit(lives)
		if lives <= 0:
			game_over.emit()
		else:
			gold = gold_snapshot
			if not first_loss_given:
				first_loss_given = true
				gold += 50
			gold_changed.emit(gold)
	round_ended.emit(player_won)

func calculate_income() -> int:
	var income: int = 0
	if current_round <= INCOME_SCALE_ROUND:
		income += BASE_INCOME
	else:
		income += BASE_INCOME + (current_round - INCOME_SCALE_ROUND)
	if last_round_won:
		income += VICTORY_BONUS
	var interest: int = mini(int(gold * INTEREST_RATE), MAX_INTEREST)
	income += interest
	return income

func advance_round() -> void:
	if current_round > 0:
		var income := calculate_income()
		gold += income
		gold_changed.emit(gold)
	current_round += 1
	gold_snapshot = gold
	# Life regen every 5 rounds
	if current_round % 5 == 0:
		lives += 1
		lives_changed.emit(lives)
	change_phase(Phase.WAVE_SELECT)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func get_farm_cost() -> int:
	return BASE_FARM_COST + int(float(farm_purchases) / 3.0)

func buy_farm() -> bool:
	var cost := get_farm_cost()
	if not spend_gold(cost):
		return false
	farms += 1
	farm_purchases += 1
	farms_changed.emit()
	return true

func reset() -> void:
	current_phase = Phase.WAVE_SELECT
	current_round = 0
	gold = STARTING_GOLD
	lives = STARTING_LIVES
	farms = STARTING_FARMS
	farm_purchases = 0
	last_round_won = false
	gold_snapshot = 0
	first_loss_given = false
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	farms_changed.emit()
