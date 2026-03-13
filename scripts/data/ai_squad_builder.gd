class_name AiSquadBuilder extends RefCounted

# ── Tuning Constants ──────────────────────────────────────────
const AI_WIN_RATE := 0.75       # Fraction of rounds AI "won" (affects victory bonus)
const AI_EFFICIENCY := 0.85     # Fraction of gold actually spent (< 1.0 = some waste)
const AI_MERGE_RATE := 0.6      # Probability of merging when duplicate available

# Economy mirrors GameManager constants
const STARTING_GOLD := 25
const BASE_INCOME := 12
const INCOME_SCALE_ROUND := 5
const VICTORY_BONUS := 2
const INTEREST_RATE := 0.10
const MAX_INTEREST := 5
const BASE_FARM_COST := 1
const STARTING_FARMS := 5
const XP_TO_LEVEL := 4

# ── Entry Point ───────────────────────────────────────────────

static func build_squad(
	effective_round: int,
	budget_mult: float,
	seed_val: int,
	hero_pool: Array[UnitData],
	upgrade_pool: Array[Dictionary],
	strategies: Array[Dictionary]
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Pick 1 strategy based on seed
	var strat: Dictionary = strategies[rng.randi() % strategies.size()]
	var weights: Dictionary = strat.weights

	# ── Simulate economy from round 1 to effective_round ──
	var gold := STARTING_GOLD
	var farms := STARTING_FARMS
	var farm_purchases := 0
	# roster: Array of Dictionaries, each representing a unit being built up
	var roster: Array[Dictionary] = []

	for sim_round in range(1, effective_round + 1):
		# 1. Income
		var income := _calc_income(sim_round, gold, rng)
		gold += int(income * budget_mult)

		# Apply efficiency — AI doesn't spend perfectly
		var spending_budget := int(gold * AI_EFFICIENCY)

		# 2. Buy farms if needed
		var target_farms := mini(sim_round / 2 + 5, 14)
		var pop_used := _total_pop(roster)
		while farms < target_farms and spending_budget >= _farm_cost(farm_purchases):
			var cost := _farm_cost(farm_purchases)
			if spending_budget < cost:
				break
			spending_budget -= cost
			gold -= cost
			farms += 1
			farm_purchases += 1

		# 3. Buy heroes — pick from weighted pool based on strategy
		var weighted_pool := _build_weighted_pool(hero_pool, weights, sim_round)
		if weighted_pool.is_empty():
			continue
		var buy_attempts := 0
		pop_used = _total_pop(roster)
		while pop_used < farms and spending_budget > 0 and buy_attempts < 20:
			var data: UnitData = weighted_pool[rng.randi() % weighted_pool.size()]
			if pop_used + data.pop_cost > farms:
				buy_attempts += 1
				continue
			if spending_budget < data.farm_cost:
				buy_attempts += 1
				continue
			spending_budget -= data.farm_cost
			gold -= data.farm_cost
			roster.append(_new_roster_entry(data, rng))
			pop_used += data.pop_cost
			buy_attempts = 0  # Reset on success

		# 4. Merge duplicates
		_try_merges(roster, rng)

		# 5. Buy upgrades with remaining gold
		gold = _buy_upgrades(roster, upgrade_pool, sim_round, gold, rng)

	# ── Build output entries ──────────────────────────────────
	var enemies: Array[Dictionary] = []
	for entry in roster:
		enemies.append(_build_enemy_entry(entry))

	return {
		"name": strat.label,
		"strategy": "ai_simulated",
		"enemies": enemies,
		"total_units": enemies.size(),
		"total_farms": _total_pop(roster),
	}

# ── Economy Helpers ───────────────────────────────────────────

static func _calc_income(round_num: int, current_gold: int, rng: RandomNumberGenerator) -> int:
	var income := 0
	if round_num <= INCOME_SCALE_ROUND:
		income += BASE_INCOME
	else:
		income += BASE_INCOME + (round_num - INCOME_SCALE_ROUND)
	# Victory bonus (probabilistic)
	if rng.randf() < AI_WIN_RATE:
		income += VICTORY_BONUS
	# Interest
	var interest := mini(int(current_gold * INTEREST_RATE), MAX_INTEREST)
	income += interest
	return income

static func _farm_cost(purchases: int) -> int:
	return BASE_FARM_COST + int(float(purchases) / 3.0)

static func _total_pop(roster: Array[Dictionary]) -> int:
	var total := 0
	for entry in roster:
		total += entry.data.pop_cost
	return total

# ── Weighted Pool (simplified — no GameManager dependency) ───

static func _build_weighted_pool(hero_pool: Array[UnitData], weights: Dictionary, round_num: int) -> Array[UnitData]:
	var pool: Array[UnitData] = []
	for data in hero_pool:
		var w: int = weights.get(data.unit_class, 1)
		w = _apply_round_weight(w, data.pop_cost, round_num)
		for i in range(w):
			pool.append(data)
	return pool

static func _apply_round_weight(base_weight: int, pop_cost: int, round_num: int) -> int:
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

# ── Roster Entry ──────────────────────────────────────────────

static func _new_roster_entry(data: UnitData, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"data": data,
		"xp": 0,
		"level": 1,
		# Stats start from base UnitData values
		"damage": data.damage,
		"max_hp": data.max_hp,
		"attacks_per_second": data.attacks_per_second,
		"attack_range": data.attack_range,
		"ability_range": data.ability_range,
		"move_speed": data.move_speed,
		"armor": data.armor,
		"max_armor": data.armor,
		"evasion": data.evasion,
		"crit_chance": data.crit_chance,
		"skill_proc_chance": data.skill_proc_chance,
		"max_mana": data.max_mana,
		"mana_cost_per_attack": data.mana_cost_per_attack,
		"mana_regen_per_second": data.mana_regen_per_second,
		"hp_regen_per_second": data.hp_regen_per_second,
		"ability_cooldown": data.ability_cooldown,
		# Modifier flags
		"primed": false,
		"poison_power": 0,
		"thorns_slow": false,
		"lifesteal_pct": 0.0,
		"last_stand": false,
		"relentless": false,
		"sepsis_spread": 0,
		"living_shield_max": 0,
		"invincible_max": 0,
		"haymaker_counter": 0,
		"legion_master": false,
		"necromancy_stacks": 0,
		"hellfire": false,
		"corrosive_power": 0,
		"applied_upgrades": [] as Array[Dictionary],
		"display_name": HeroVariants.random_name(data.unit_class),
		"ability_key": "",
		"instance_ability_name": data.ability_name,
		"instance_ability_desc": data.ability_desc,
	}

# ── Merge Logic ───────────────────────────────────────────────

static func _try_merges(roster: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	# Group by class
	var by_class: Dictionary = {}
	for i in range(roster.size()):
		var cls: String = roster[i].data.unit_class
		if not by_class.has(cls):
			by_class[cls] = []
		by_class[cls].append(i)

	# For each class with 2+ units, try to merge
	var to_remove: Array[int] = []
	for cls in by_class:
		var indices: Array = by_class[cls]
		if indices.size() < 2:
			continue
		if rng.randf() >= AI_MERGE_RATE:
			continue
		# Merge second into first
		var target_idx: int = indices[0]
		var consumed_idx: int = indices[1]
		var consumed_xp: int = roster[consumed_idx].xp
		_grant_xp_to_entry(roster[target_idx], 1 + consumed_xp)
		to_remove.append(consumed_idx)

	# Remove consumed units (reverse order to preserve indices)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		roster.remove_at(idx)

# ── XP / Level-Up (mirrors _grant_xp in main.gd) ─────────────

static func _grant_xp_to_entry(entry: Dictionary, xp_gained: int) -> void:
	entry.xp += xp_gained

	# Per-XP boost (~12%)
	for i in range(xp_gained):
		entry.damage = maxi(entry.damage + 1, int(ceil(entry.damage * 1.12)))
		entry.max_hp = maxi(entry.max_hp + 5, int(ceil(entry.max_hp * 1.12)))
		entry.attacks_per_second *= 1.10
		entry.attack_range = maxf(entry.attack_range + 2.0, entry.attack_range * 1.05)
		entry.move_speed = maxf(entry.move_speed + 1.0, entry.move_speed * 1.05)
		if entry.max_armor > 0:
			entry.armor = maxi(entry.armor + 1, int(ceil(entry.armor * 1.12)))
			entry.max_armor = maxi(entry.max_armor + 1, int(ceil(entry.max_armor * 1.12)))
		entry.evasion += 1.0
		entry.crit_chance += 1.0
		entry.skill_proc_chance += 0.5
		entry.max_mana += 2

	# Level-up loop (~28%)
	while entry.xp >= XP_TO_LEVEL:
		entry.xp -= XP_TO_LEVEL
		entry.level += 1
		entry.damage = maxi(entry.damage + 2, int(ceil(entry.damage * 1.28)))
		entry.max_hp = maxi(entry.max_hp + 10, int(ceil(entry.max_hp * 1.28)))
		entry.attacks_per_second *= 1.20
		entry.attack_range *= 1.08
		entry.move_speed *= 1.08
		if entry.armor > 0:
			entry.armor = maxi(entry.armor + 2, int(ceil(entry.armor * 1.25)))
		entry.evasion += 3.0
		entry.crit_chance += 3.0
		entry.skill_proc_chance += 2.0
		entry.max_mana += 3

# ── Upgrade Buying ────────────────────────────────────────────

static func _buy_upgrades(roster: Array[Dictionary], upgrade_pool: Array[Dictionary], round_num: int, gold: int, rng: RandomNumberGenerator) -> int:
	if roster.is_empty() or gold <= 0:
		return gold

	# Filter available upgrades by round
	var available: Array[Dictionary] = []
	for u in upgrade_pool:
		if u.rarity == "Epic" and round_num < 10:
			continue
		if u.rarity == "Rare" and round_num < 5:
			continue
		available.append(u)

	if available.is_empty():
		return gold

	# Try to buy 1-3 upgrades
	var max_buys := mini(3, roster.size())
	for _attempt in range(max_buys):
		if gold <= 0:
			break
		# Pick a random unit from roster
		var unit_idx := rng.randi() % roster.size()
		var entry: Dictionary = roster[unit_idx]
		# Check upgrade slot limit (level + 1)
		if entry.applied_upgrades.size() >= entry.level + 1:
			continue
		# Pick a random affordable upgrade, prefer class-specific
		var candidates: Array[Dictionary] = []
		for u in available:
			if u.cost > gold:
				continue
			if u.has("class_req") and u.class_req != entry.data.unit_class:
				continue
			candidates.append(u)
		if candidates.is_empty():
			continue
		var upgrade: Dictionary = candidates[rng.randi() % candidates.size()]
		gold -= upgrade.cost
		_apply_upgrade_to_entry(entry, upgrade)
		entry.applied_upgrades.append(upgrade.duplicate())
	return gold

# ── Upgrade Application (mirrors _apply_stat_buff, pure data) ─

static func _apply_upgrade_to_entry(entry: Dictionary, upgrade: Dictionary) -> void:
	var stat_key: String = upgrade.stat
	var amount: float = upgrade.amount
	match stat_key:
		"damage":
			entry.damage += int(amount)
		"attacks_per_second":
			entry.attacks_per_second += amount
		"max_hp":
			entry.max_hp += int(amount)
		"max_mana":
			entry.max_mana += int(amount)
		"armor":
			entry.armor += int(amount)
			entry.max_armor += int(amount)
		"evasion":
			entry.evasion += amount
		"attack_range":
			entry.attack_range += amount
		"ability_range":
			entry.ability_range += amount
		"move_speed":
			entry.move_speed += amount
		"crit_chance":
			entry.crit_chance += amount
		"skill_proc_chance":
			entry.skill_proc_chance += amount
		"ability_cooldown":
			entry.ability_cooldown = maxf(entry.ability_cooldown + amount, 0.5)
		"necromancy":
			entry.necromancy_stacks += int(amount)
		"primed":
			entry.primed = true
		"corrosive":
			entry.corrosive_power += int(amount)
		"thorns_slow":
			entry.thorns_slow = true
		"lifesteal":
			entry.lifesteal_pct += amount
		"berserk":
			var hp_loss := int(entry.max_hp * 0.3)
			entry.max_hp -= hp_loss
			entry.damage += 6
			entry.attacks_per_second += 0.4
		"last_stand":
			entry.last_stand = true
		"relentless":
			entry.relentless = true
		"sepsis":
			entry.sepsis_spread += int(amount)
		"living_shield":
			entry.living_shield_max += int(amount)
		"invincible":
			entry.invincible_max += int(amount)
			entry.evasion += 5.0
		"haymaker":
			entry.haymaker_counter = int(amount)
		"venom_arrow":
			entry.poison_power += int(amount)
		"war_paint":
			entry.damage += 3
			entry.max_hp += 10
		"shadow_cloak":
			entry.evasion += 5.0
			entry.crit_chance += 3.0
		"thick_plate":
			entry.armor += 10
			entry.max_armor += 10
			entry.max_hp += 15
		"dark_sigil":
			entry.damage += 3
			entry.max_mana += 2
		"sacred_blessing":
			entry.max_hp += 15
			entry.max_mana += 2
		"herbal_brew":
			entry.damage += 3
			entry.skill_proc_chance += 3.0
		"shield_of_faith":
			entry.armor += 8
			entry.max_armor += 8
		"soul_binding":
			entry.necromancy_stacks += 1
			entry.max_hp += 10
		"blood_rage":
			entry.damage += 5
			entry.attacks_per_second += 0.2
		"deadeye":
			entry.damage += 8
			entry.attack_range += 80
		"phantom_step":
			entry.evasion += 10
			entry.crit_chance += 10
		"fortress":
			entry.armor += 25
			entry.max_armor += 25
			entry.max_hp += 40
		"soul_rend":
			entry.damage += 8
			entry.max_mana += 3
		"hellfire":
			entry.hellfire = true
		"divine_covenant":
			entry.max_hp += 30
			entry.max_mana += 3
		"toxic_mastery":
			entry.damage += 5
			entry.skill_proc_chance += 5
		"holy_vanguard":
			entry.armor += 15
			entry.max_armor += 15
			entry.damage += 3
		"rampage":
			entry.damage += 10
			entry.attacks_per_second += 0.3
			entry.max_hp += 20
		"hawkeye":
			entry.damage += 12
			entry.attack_range += 120
			entry.crit_chance += 8
		"deaths_embrace":
			entry.evasion += 15
			entry.crit_chance += 15
			entry.damage += 5
		"bastion":
			entry.armor += 40
			entry.max_armor += 40
			entry.max_hp += 60
			entry.damage += 2
		"dark_pact":
			entry.damage += 15
			entry.max_mana += 5
		"ascension":
			entry.max_hp += 50
			entry.max_mana += 5
			entry.damage += 5
		"plague_lord":
			entry.damage += 10
			entry.skill_proc_chance += 8
			entry.armor += 15
			entry.max_armor += 15
		"divine_bulwark":
			entry.armor += 25
			entry.max_armor += 25
			entry.max_hp += 40
			entry.damage += 5
		"legion_master":
			entry.legion_master = true
			entry.necromancy_stacks += 2
			entry.max_hp += 30

# ── Output Builder ────────────────────────────────────────────

static func _build_enemy_entry(entry: Dictionary) -> Dictionary:
	return {
		"data": entry.data,
		"xp": entry.xp,
		"level": entry.level,
		"display_name": entry.display_name,
		"ability_key": entry.ability_key,
		"instance_ability_name": entry.instance_ability_name,
		"instance_ability_desc": entry.instance_ability_desc,
		"applied_upgrades": entry.applied_upgrades.duplicate(),
		"primed": entry.primed,
		"poison_power": entry.poison_power,
		"thorns_slow": entry.thorns_slow,
		"lifesteal_pct": entry.lifesteal_pct,
		"last_stand": entry.last_stand,
		"relentless": entry.relentless,
		"sepsis_spread": entry.sepsis_spread,
		"living_shield_max": entry.living_shield_max,
		"invincible_max": entry.invincible_max,
		"haymaker_counter": entry.haymaker_counter,
		"legion_master": entry.legion_master,
		"necromancy_stacks": entry.necromancy_stacks,
		"hellfire": entry.hellfire,
		"corrosive_power": entry.corrosive_power,
		"stats": {
			"damage": entry.damage,
			"max_hp": entry.max_hp,
			"attacks_per_second": entry.attacks_per_second,
			"attack_range": entry.attack_range,
			"ability_range": entry.ability_range,
			"move_speed": entry.move_speed,
			"armor": entry.armor,
			"max_armor": entry.max_armor,
			"evasion": entry.evasion,
			"crit_chance": entry.crit_chance,
			"skill_proc_chance": entry.skill_proc_chance,
			"max_mana": entry.max_mana,
			"mana_cost_per_attack": entry.mana_cost_per_attack,
			"ability_cooldown": entry.ability_cooldown,
			"mana_regen_per_second": entry.mana_regen_per_second,
			"hp_regen_per_second": entry.hp_regen_per_second,
		},
	}
