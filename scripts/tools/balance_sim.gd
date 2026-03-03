extends Node
## Balance Simulation Tool
## Run as main scene (res://scenes/tools/balance_sim.tscn) or press F9 in-game.
## Prints a per-round balance report comparing player vs enemy army strength.

const NUM_SIMULATIONS := 50
const MAX_ROUNDS := 20

# --- Game constants (mirrors game_manager.gd) ---
const STARTING_GOLD := 25
const STARTING_FARMS := 5
const BASE_FARM_COST := 1
const BASE_INCOME := 12
const INCOME_SCALE_ROUND := 7
const VICTORY_BONUS := 2
const INTEREST_RATE := 0.10
const MAX_INTEREST := 5
const XP_TO_LEVEL := 4

# --- Balance thresholds ---
const RATIO_TOO_EASY := 1.5
const RATIO_BALANCED_LOW := 0.8
const RATIO_BALANCED_HIGH := 1.3

# --- Unit base stats [name, hp, dmg, as, armor, evasion, crit, pop_cost, farm_cost, ability] ---
enum Ability { NONE, FRENZY, HOLY_ARMOR, SHIELD_BASH, VOLLEY, VULNERABLE_CURSE, SHADOWSTRIKE, MAGIC_POTIONS, SUMMON_ARCHER }

class UnitStats:
	var unit_name: String
	var hp: float
	var dmg: float
	var atk_speed: float
	var armor: float
	var evasion: float
	var crit: float
	var pop_cost: int
	var farm_cost: int
	var ability: int  # Ability enum
	var max_mana: float
	var mana_regen: float
	var mana_per_attack: float
	var ability_cd: float
	var level: int = 1
	var xp: int = 0

	func duplicate_stats() -> UnitStats:
		var u := UnitStats.new()
		u.unit_name = unit_name; u.hp = hp; u.dmg = dmg; u.atk_speed = atk_speed
		u.armor = armor; u.evasion = evasion; u.crit = crit
		u.pop_cost = pop_cost; u.farm_cost = farm_cost; u.ability = ability
		u.max_mana = max_mana; u.mana_regen = mana_regen
		u.mana_per_attack = mana_per_attack; u.ability_cd = ability_cd
		u.level = level; u.xp = xp
		return u

var BASE_UNITS: Array[UnitStats] = []

func _init_base_units() -> void:
	BASE_UNITS = []
	var defs := [
		# [name, hp, dmg, as, armor, evasion, crit, pop, gold, ability, max_mana, mana_regen, mana_per_atk, cd]
		["Grunt",     130, 7,  1.1, 3, 0.0,  5.0,  1, 1, Ability.FRENZY,           15, 1.0, 4, 6.0],
		["Priest",     65, 4,  1.0, 0, 5.0,  2.0,  1, 1, Ability.HOLY_ARMOR,       25, 2.5, 6, 4.0],
		["Tank",      200, 8,  0.6, 8, 0.0,  3.0,  2, 2, Ability.SHIELD_BASH,      18, 1.0, 4, 7.36],
		["Archer",     55, 11, 0.8, 0, 0.0,  8.0,  3, 2, Ability.VOLLEY,           16, 1.5, 4, 7.0],
		["Warlock",    50, 12, 0.5, 0, 0.0,  5.0,  2, 2, Ability.VULNERABLE_CURSE, 20, 2.0, 8, 5.76],
		["Assassin",   60, 12, 0.9, 0, 15.0, 12.0, 3, 3, Ability.SHADOWSTRIKE,     14, 1.0, 5, 5.0],
		["Herbalist",  90, 10, 0.7, 1, 0.0,  8.0,  1, 3, Ability.MAGIC_POTIONS,    22, 2.0, 5, 6.0],
		["Summoner",   50, 0,  0.2, 0, 0.0,  0.0,  4, 4, Ability.SUMMON_ARCHER,    20, 1.5, 0, 5.0],
	]
	for d in defs:
		var u := UnitStats.new()
		u.unit_name = d[0]; u.hp = d[1]; u.dmg = d[2]; u.atk_speed = d[3]
		u.armor = d[4]; u.evasion = d[5]; u.crit = d[6]
		u.pop_cost = d[7]; u.farm_cost = d[8]; u.ability = d[9]
		u.max_mana = d[10]; u.mana_regen = d[11]; u.mana_per_attack = d[12]
		u.ability_cd = d[13]
		BASE_UNITS.append(u)

func _get_base(unit_name: String) -> UnitStats:
	for u in BASE_UNITS:
		if u.unit_name == unit_name:
			return u
	return BASE_UNITS[0]

# --- Unit strength calculation ---

func _unit_strength(u: UnitStats) -> float:
	var effective_dps := u.dmg * u.atk_speed * (1.0 + u.crit / 100.0)
	var effective_hp := u.hp / maxf(1.0 - u.evasion / 100.0, 0.01) + u.armor * 10.0
	var base_str := effective_dps * effective_hp

	# Utility value from abilities (estimated contribution over a 15-second fight)
	var util := _estimate_ability_value(u)
	return base_str + util

func _estimate_ability_value(u: UnitStats) -> float:
	# Estimate how many times ability fires in a ~15 sec fight
	var fight_duration := 15.0
	# Mana fill time: max_mana / (mana_regen + mana_per_attack * atk_speed)
	var mana_income := u.mana_regen + u.mana_per_attack * u.atk_speed
	var fill_time := u.max_mana / maxf(mana_income, 0.01)
	var casts := maxf(floorf(fight_duration / maxf(fill_time, 0.5)), 1.0)

	match u.ability:
		Ability.FRENZY:
			# +30% AS compounding per cast. Value = extra DPS over remaining fight.
			var bonus_dps := u.dmg * u.atk_speed * 0.3 * casts
			return bonus_dps * (fight_duration * 0.5)
		Ability.HOLY_ARMOR:
			# Heals all allies for dmg*2.5. Assume 3 allies benefit.
			return u.dmg * 2.5 * 3.0 * casts
		Ability.SHIELD_BASH:
			# +2 armor per cast
			return casts * 2.0 * 10.0
		Ability.VOLLEY:
			# dmg*0.4 AoE to all enemies, assume hits 3
			return u.dmg * 0.4 * 3.0 * casts
		Ability.VULNERABLE_CURSE:
			# 1.5x dmg compounding. Value = extra DPS over remaining fight.
			var bonus_dps := u.dmg * u.atk_speed * 0.5 * casts
			return bonus_dps * (fight_duration * 0.5)
		Ability.SHADOWSTRIKE:
			# +50% crit per cast
			var extra_crit_dps := u.dmg * u.atk_speed * 0.50 * casts / 100.0
			return extra_crit_dps * fight_duration
		Ability.MAGIC_POTIONS:
			# dmg*0.5 AoE, assume hits 3 enemies
			return u.dmg * 0.5 * 3.0 * casts
		Ability.SUMMON_ARCHER:
			# Spawns a 60% stat archer, scaling with summoner power
			var archer_base := _get_base("Archer")
			var a_dmg := archer_base.dmg * 0.6
			var a_hp := archer_base.hp * 0.6
			var a_as := archer_base.atk_speed * 0.8
			return a_dmg * a_as * a_hp * 0.1 * casts
		_:
			return 0.0

# --- XP / Level scaling (mirrors main.gd _grant_xp) ---

func _apply_xp(u: UnitStats, xp_gained: int) -> void:
	u.xp += xp_gained
	for i in range(xp_gained):
		u.dmg += 1
		u.hp += 8
		u.atk_speed += 0.02
		if u.armor > 0:
			u.armor += 1
		u.evasion += 0.5
		u.crit += 0.5
		u.max_mana += 1

	while u.xp >= XP_TO_LEVEL:
		u.xp -= XP_TO_LEVEL
		u.level += 1
		u.dmg = ceilf(u.dmg * 1.08)
		u.hp = ceilf(u.hp * 1.08)
		u.atk_speed *= 1.02
		if u.armor > 0:
			u.armor += 2
		u.evasion += 2.0
		u.crit += 2.0
		u.max_mana += 2

# --- Enemy stat scaling (mirrors main.gd spawn logic) ---

func _apply_enemy_level(u: UnitStats, lvl: int) -> void:
	u.level = lvl
	if lvl > 1:
		var scale := 1.0 + (lvl - 1) * 0.45
		u.dmg = ceilf(u.dmg * scale)
		u.hp = ceilf(u.hp * scale)
		if u.armor > 0:
			u.armor = ceilf(u.armor * scale)
		u.atk_speed *= 1.0 + (lvl - 1) * 0.18

# --- Simulation ---

class RoundResult:
	var gold: int
	var farms: int
	var unit_count: int
	var player_strength: float
	var enemy_strength: float

func _run_single_simulation() -> Array[RoundResult]:
	var results: Array[RoundResult] = []
	var gold := STARTING_GOLD
	var farms := STARTING_FARMS
	var farm_purchases := 0
	var player_units: Array[UnitStats] = []
	var last_won := false

	# Cheap units the sim-player prefers to buy
	var buy_priority := ["Grunt", "Priest", "Tank"]

	for round_num in range(1, MAX_ROUNDS + 1):
		# --- Income ---
		if round_num > 1:
			var income := BASE_INCOME
			if round_num > INCOME_SCALE_ROUND:
				income += round_num - INCOME_SCALE_ROUND
			if last_won:
				income += VICTORY_BONUS
			income += mini(int(gold * INTEREST_RATE), MAX_INTEREST)
			gold += income

		# --- Buy farms (target: round/2 + 5, capped at 12) ---
		var farm_target := mini(round_num / 2 + 5, 12)
		while farms < farm_target:
			var cost := BASE_FARM_COST + farm_purchases / 3
			if gold >= cost:
				gold -= cost
				farms += 1
				farm_purchases += 1
			else:
				break

		# --- Calculate used pop ---
		var pop_used := 0
		for u in player_units:
			pop_used += u.pop_cost

		# --- Fill empty slots with cheap units (max 2 per round, matching shop) ---
		var hero_buys := 0
		for prio_name in buy_priority:
			var base := _get_base(prio_name)
			while pop_used + base.pop_cost <= farms and hero_buys < 2:
				if gold < base.farm_cost:
					break
				gold -= base.farm_cost
				var new_unit := base.duplicate_stats()
				player_units.append(new_unit)
				pop_used += new_unit.pop_cost
				hero_buys += 1
			if pop_used >= farms or hero_buys >= 2:
				break

		# --- Feed XP via duplicate purchases (1-2 per round) ---
		var xp_purchases := 1 if round_num <= 5 else 2
		for i in range(xp_purchases):
			if player_units.is_empty():
				break
			# Buy cheapest dupe to merge
			var cheapest_owned: UnitStats = player_units[0]
			for u in player_units:
				if _get_base(u.unit_name).farm_cost < _get_base(cheapest_owned.unit_name).farm_cost:
					cheapest_owned = u
			var merge_cost := _get_base(cheapest_owned.unit_name).farm_cost
			if gold >= merge_cost:
				gold -= merge_cost
				_apply_xp(cheapest_owned, 1)

		# --- Spend remaining gold on stat upgrades (simple: +dmg to strongest) ---
		# Approximate: 1g per purchase, buy damage for the highest-level unit
		if not player_units.is_empty():
			var best: UnitStats = player_units[0]
			for u in player_units:
				if u.level > best.level or (u.level == best.level and u.dmg > best.dmg):
					best = u
			var upgrade_budget := mini(gold / 2, 5)  # spend up to half gold, max 5 upgrades
			for j in range(upgrade_budget):
				if gold >= 1:
					gold -= 1
					best.dmg += 1

		# --- Calculate player army strength ---
		var player_str := 0.0
		for u in player_units:
			player_str += _unit_strength(u)

		# --- Generate enemy army (mirrors _generate_single_wave) ---
		var enemy_budget := round_num + 2 + randi_range(0, maxi(round_num / 3, 1))
		var enemy_base_level := clampi(ceili(float(round_num) / 2.0), 1, 10)

		# Enemy unit pool: pick from all 8 with round-weighted bias
		var enemy_units: Array[UnitStats] = []
		var enemy_budget_used := 0
		var attempts := 0
		while enemy_budget_used < enemy_budget and attempts < 50:
			attempts += 1
			var pick := _pick_weighted_enemy_unit(round_num)
			if enemy_budget_used + pick.pop_cost <= enemy_budget:
				var eu := pick.duplicate_stats()
				var lvl := clampi(enemy_base_level + randi_range(-1, 1), 1, 10)
				_apply_enemy_level(eu, lvl)
				enemy_units.append(eu)
				enemy_budget_used += eu.pop_cost

		var enemy_str := 0.0
		for eu in enemy_units:
			enemy_str += _unit_strength(eu)

		# --- Determine outcome ---
		last_won = player_str >= enemy_str

		var rr := RoundResult.new()
		rr.gold = gold
		rr.farms = farms
		rr.unit_count = player_units.size()
		rr.player_strength = player_str
		rr.enemy_strength = enemy_str
		results.append(rr)

	return results

func _pick_weighted_enemy_unit(round_num: int) -> UnitStats:
	# Build weighted pool based on round
	var pool: Array[UnitStats] = []
	# Base weights roughly matching wave_strategies "Balanced Army"
	var base_weights := {
		"Grunt": 3, "Priest": 3, "Tank": 3, "Archer": 3,
		"Warlock": 3, "Assassin": 3, "Herbalist": 3, "Summoner": 1
	}
	for u in BASE_UNITS:
		var w := base_weights.get(u.unit_name, 1) as int
		w = _apply_round_weight(w, u.pop_cost, round_num)
		for k in range(w):
			pool.append(u)
	if pool.is_empty():
		return BASE_UNITS[0]
	return pool[randi() % pool.size()]

func _apply_round_weight(base_weight: int, pop_cost: int, round_num: int) -> int:
	if pop_cost <= 1:
		return base_weight + maxi(4 - round_num / 2, 0)
	elif pop_cost == 2:
		return base_weight + maxi(2 - round_num / 3, 0)
	else:
		if round_num < 3:
			return maxi(base_weight / 3, 1) if base_weight > 0 else 0
		elif round_num < 6:
			return maxi(base_weight / 2, 1) if base_weight > 0 else 0
		return base_weight

# --- Aggregation and output ---

func _run_all_simulations() -> void:
	_init_base_units()

	# Accumulate per-round averages
	var avg_gold: Array[float] = []
	var avg_farms: Array[float] = []
	var avg_units: Array[float] = []
	var avg_player_str: Array[float] = []
	var avg_enemy_str: Array[float] = []
	avg_gold.resize(MAX_ROUNDS); avg_gold.fill(0.0)
	avg_farms.resize(MAX_ROUNDS); avg_farms.fill(0.0)
	avg_units.resize(MAX_ROUNDS); avg_units.fill(0.0)
	avg_player_str.resize(MAX_ROUNDS); avg_player_str.fill(0.0)
	avg_enemy_str.resize(MAX_ROUNDS); avg_enemy_str.fill(0.0)

	for sim in range(NUM_SIMULATIONS):
		var results := _run_single_simulation()
		for r in range(MAX_ROUNDS):
			avg_gold[r] += results[r].gold
			avg_farms[r] += results[r].farms
			avg_units[r] += results[r].unit_count
			avg_player_str[r] += results[r].player_strength
			avg_enemy_str[r] += results[r].enemy_strength

	for r in range(MAX_ROUNDS):
		avg_gold[r] /= NUM_SIMULATIONS
		avg_farms[r] /= NUM_SIMULATIONS
		avg_units[r] /= NUM_SIMULATIONS
		avg_player_str[r] /= NUM_SIMULATIONS
		avg_enemy_str[r] /= NUM_SIMULATIONS

	_print_report(avg_gold, avg_farms, avg_units, avg_player_str, avg_enemy_str)

func _print_report(gold: Array[float], farms: Array[float], units: Array[float],
		player_str: Array[float], enemy_str: Array[float]) -> void:
	print("")
	print("=== AUTO BATTLER BALANCE REPORT (avg of %d simulations) ===" % NUM_SIMULATIONS)
	print("")
	print(" Rnd | Gold | Farms | Units | Player Str | Enemy Str  | Ratio  | Result")
	print("-----|------|-------|-------|------------|------------|--------|--------")

	var band_ratios: Array[Array] = [[], [], [], []]  # 1-5, 6-10, 11-15, 16-20

	for r in range(MAX_ROUNDS):
		var round_num := r + 1
		var ratio := player_str[r] / maxf(enemy_str[r], 1.0)
		var result_str := "WIN" if ratio >= 1.0 else "LOSS"
		var flag := ""
		if ratio > RATIO_TOO_EASY:
			flag = " <<<"
		elif ratio < RATIO_BALANCED_LOW:
			flag = " !!!"

		print(" %3d | %4d | %5d | %5d | %10s | %10s | %5.2fx | %s%s" % [
			round_num,
			roundi(gold[r]),
			roundi(farms[r]),
			roundi(units[r]),
			_format_num(player_str[r]),
			_format_num(enemy_str[r]),
			ratio,
			result_str,
			flag
		])

		var band := clampi((round_num - 1) / 5, 0, 3)
		band_ratios[band].append(ratio)

	# Difficulty curve
	print("")
	print("=== DIFFICULTY CURVE ===")
	var band_labels := ["Rounds  1-5 ", "Rounds  6-10", "Rounds 11-15", "Rounds 16-20"]
	for i in range(4):
		var avg_ratio := 0.0
		for v in band_ratios[i]:
			avg_ratio += v
		avg_ratio /= maxf(band_ratios[i].size(), 1.0)
		var assessment := _assess_ratio(avg_ratio)
		print("%s:  avg ratio %.2fx  (%s)" % [band_labels[i], avg_ratio, assessment])

	# Suggested fixes
	print("")
	print("=== SUGGESTED FIXES ===")
	var has_fix := false

	for i in range(4):
		var avg_ratio := 0.0
		for v in band_ratios[i]:
			avg_ratio += v
		avg_ratio /= maxf(band_ratios[i].size(), 1.0)

		if avg_ratio > RATIO_TOO_EASY:
			has_fix = true
			var start_round := i * 5 + 1
			var end_round := i * 5 + 5
			print("- Rounds %d-%d too easy (%.2fx). Consider:" % [start_round, end_round, avg_ratio])
			if i <= 1:
				print("    * Increase enemy farm budget by +%d in early rounds" % ceili((avg_ratio - 1.3) * 3))
				print("    * Raise enemy base level formula (e.g. ceil(round/2.5) instead of ceil(round/3))")
			else:
				print("    * Increase enemy stat scaling (e.g. 0.35 per level instead of 0.25)")
				print("    * Reduce player XP-per-point multiplier (e.g. 1.07x instead of 1.10x)")
		elif avg_ratio < RATIO_BALANCED_LOW:
			has_fix = true
			var start_round := i * 5 + 1
			var end_round := i * 5 + 5
			print("- Rounds %d-%d too hard (%.2fx). Consider:" % [start_round, end_round, avg_ratio])
			print("    * Reduce enemy farm budget or stat scaling in this range")
			print("    * Increase player income or upgrade availability")

	if not has_fix:
		print("No major imbalances detected. All bands within %.1fx-%.1fx range." % [
			RATIO_BALANCED_LOW, RATIO_TOO_EASY])

	print("")
	print("=== THRESHOLD KEY ===")
	print("> %.1fx = too easy (player stomps)    <<< marker" % RATIO_TOO_EASY)
	print("%.1fx-%.1fx = balanced range" % [RATIO_BALANCED_LOW, RATIO_BALANCED_HIGH])
	print("< %.1fx = too hard                    !!! marker" % RATIO_BALANCED_LOW)
	print("")

func _format_num(val: float) -> String:
	var n := roundi(val)
	if n >= 1_000_000:
		return "%d,%03d,%03d" % [n / 1_000_000, (n / 1_000) % 1_000, n % 1_000]
	elif n >= 1_000:
		return "%d,%03d" % [n / 1_000, n % 1_000]
	else:
		return str(n)

func _assess_ratio(ratio: float) -> String:
	if ratio > 2.0:
		return "Way too easy - PROBLEM"
	elif ratio > RATIO_TOO_EASY:
		return "Too easy - PROBLEM"
	elif ratio > RATIO_BALANCED_HIGH:
		return "Slightly easy"
	elif ratio >= RATIO_BALANCED_LOW:
		return "Balanced"
	elif ratio >= 0.6:
		return "Hard"
	else:
		return "Too hard - PROBLEM"

# --- Entry point ---

func _ready() -> void:
	print("Starting balance simulation...")
	_run_all_simulations()
	print("Simulation complete.")
