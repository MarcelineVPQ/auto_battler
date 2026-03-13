extends Node

enum Phase { MAP, WAVE_SELECT, PREP, BATTLE, RESULT }

signal phase_changed(new_phase: Phase)
signal round_ended(player_won: bool)
signal gold_changed(new_amount: int)
signal lives_changed(new_lives: int)
signal farms_changed
signal game_over

const MAX_ROUNDS: int = 20
const STARTING_GOLD: int = 25
const STARTING_LIVES: int = 5
const STARTING_FARMS: int = 5
const BASE_FARM_COST: int = 1
const BASE_INCOME: int = 12
const INCOME_SCALE_ROUND: int = 5
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

# Map mode state
var run_map: Dictionary = {}
var current_act: int = 1
var map_node_id: int = -1
var is_map_mode: bool = false
var encountered_ids: Array = []

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
		elif not is_map_mode:
			# Only restore gold snapshot in ranked/non-map mode
			gold = gold_snapshot
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

func advance_to_map() -> void:
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
	change_phase(Phase.MAP)

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

func calculate_hero_income(squad: Array) -> int:
	var income := 0
	for entry in squad:
		var lvl: int = entry.get("level", 1)
		income += maxi(0, lvl - 1)
	return income

func reset() -> void:
	current_phase = Phase.WAVE_SELECT
	current_round = 0
	gold = STARTING_GOLD
	lives = STARTING_LIVES
	farms = STARTING_FARMS
	farm_purchases = 0
	last_round_won = false
	gold_snapshot = 0
	run_map = {}
	current_act = 1
	map_node_id = -1
	is_map_mode = false
	encountered_ids = []
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	farms_changed.emit()

# ── Save System ──────────────────────────────────────────────

var save_path: String:
	get: return ProfileManager.get_profile_path("savegame.json")

func save_game(squad_json: Array, ranked: bool) -> void:
	var data := {
		"version": 1,
		"ranked_mode": ranked,
		"current_round": current_round,
		"gold": gold,
		"lives": lives,
		"farms": farms,
		"farm_purchases": farm_purchases,
		"gold_snapshot": gold_snapshot,
		"last_round_won": last_round_won,
		"player_squad": squad_json,
		"run_map": run_map,
		"current_act": current_act,
		"map_node_id": map_node_id,
		"is_map_mode": is_map_mode,
		"encountered_ids": encountered_ids,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func has_save_for_mode(ranked: bool) -> bool:
	if not has_save():
		return false
	var data := load_game()
	return data.get("ranked_mode", false) == ranked

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

func restore_from_save(data: Dictionary) -> void:
	current_round = data.get("current_round", 1)
	gold = data.get("gold", STARTING_GOLD)
	lives = data.get("lives", STARTING_LIVES)
	farms = data.get("farms", STARTING_FARMS)
	farm_purchases = data.get("farm_purchases", 0)
	gold_snapshot = data.get("gold_snapshot", 0)
	last_round_won = data.get("last_round_won", false)
	run_map = data.get("run_map", {})
	if not run_map.is_empty():
		MapGenerator.sanitize_after_json(run_map)
	current_act = int(data.get("current_act", 1))
	map_node_id = int(data.get("map_node_id", -1))
	is_map_mode = data.get("is_map_mode", false)
	encountered_ids = data.get("encountered_ids", [])
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	farms_changed.emit()
