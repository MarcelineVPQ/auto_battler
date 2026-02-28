class_name CombatSystem
extends Node

signal combat_ended(player_won: bool)
signal summon_requested(data: UnitData, team: Unit.Team, pos: Vector2, summoner: Unit)
signal combat_event(text: String)
signal tick_completed()

const TICK_INTERVAL: float = 0.5

var board: Board
var is_fighting: bool = false
var tick_timer: float = 0.0
var archer_data: UnitData = preload("res://resources/units/archer.tres")

func setup(b: Board) -> void:
	board = b

func start_combat() -> void:
	is_fighting = true
	tick_timer = 0.0
	for unit in board.all_units:
		unit.attack_timer = 0.0
		unit.ability_timer = 0.0
		if unit.primed:
			# Primed units start with full mana — ability fires immediately
			unit.current_mana = unit.max_mana
			unit._update_mana_bar()

func stop_combat() -> void:
	is_fighting = false

func _process(delta: float) -> void:
	if not is_fighting:
		return

	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer -= TICK_INTERVAL
		_process_tick()

func _process_tick() -> void:
	var player_units := board.get_units_on_team(Unit.Team.PLAYER)
	var enemy_units := board.get_units_on_team(Unit.Team.ENEMY)

	# Win/lose check
	if player_units.is_empty():
		is_fighting = false
		combat_ended.emit(false)
		return
	if enemy_units.is_empty():
		is_fighting = false
		combat_ended.emit(true)
		return

	# Process all living units
	var living: Array[Unit] = []
	living.append_array(player_units)
	living.append_array(enemy_units)

	for unit in living:
		if unit.is_dead:
			continue

		# Reduce attack cooldown
		unit.attack_timer -= TICK_INTERVAL

		# Mana regen
		unit.current_mana = mini(
			unit.current_mana + int(unit.mana_regen_per_second * TICK_INTERVAL),
			unit.max_mana
		)
		unit._update_mana_bar()

		# Ability trigger: when mana is full, fire ability and reset
		if unit.current_mana >= unit.max_mana:
			_trigger_ability(unit)
			unit.current_mana = 0
			unit._update_mana_bar()

		# Find target
		var target := board.find_nearest_enemy(unit)
		if target == null:
			continue

		var dist := unit.position.distance_to(target.position)

		# Summoner: spawn archers instead of attacking
		if unit.unit_data.unit_class == "Summoner":
			if unit.can_attack():
				unit.reset_attack_cooldown()
				var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
				summon_requested.emit(archer_data, unit.team, unit.position + offset, unit)
				var team_tag := "cyan" if unit.team == Unit.Team.PLAYER else "red"
				combat_event.emit("[color=%s]%s summons an Archer[/color]" % [team_tag, unit.unit_data.unit_name])
			continue

		if dist <= unit.attack_range:
			# In range — attack if ready
			if unit.can_attack():
				_attack(unit, target)
		else:
			# Out of range — move toward target, but only close enough to attack
			var desired_dist := maxf(unit.attack_range - 10.0, 50.0)
			var move_dist := minf(unit.move_speed, dist - desired_dist)
			if move_dist > 0:
				unit.move_toward_target(target.position, move_dist)

	tick_completed.emit()

func _attack(attacker: Unit, target: Unit) -> void:
	attacker.reset_attack_cooldown()

	# Spend mana on attack
	attacker.current_mana = mini(
		attacker.current_mana + attacker.mana_cost_per_attack,
		attacker.max_mana
	)
	attacker._update_mana_bar()

	# Calculate damage with crit (target vulnerability increases crit chance)
	var atk_damage := attacker.damage
	var effective_crit := attacker.crit_chance + target.crit_vulnerability
	var is_crit := randf() * 100.0 < effective_crit
	if is_crit:
		atk_damage *= 2

	# Deal damage (armor/evasion handled inside target)
	var result := target.take_damage(atk_damage)

	# Combat log
	var atk_tag := "cyan" if attacker.team == Unit.Team.PLAYER else "red"
	var a_name := attacker.unit_data.unit_name
	var t_name := target.unit_data.unit_name
	if result.evaded:
		combat_event.emit("[color=%s]%s evades %s[/color]" % [atk_tag, t_name, a_name])
	elif is_crit:
		combat_event.emit("[color=%s]%s CRITS %s for %d dmg![/color]" % [atk_tag, a_name, t_name, result.damage])
	elif result.hit:
		combat_event.emit("[color=%s]%s hits %s for %d dmg[/color]" % [atk_tag, a_name, t_name, result.damage])

	if target.is_dead:
		combat_event.emit("[color=%s]%s kills %s[/color]" % [atk_tag, a_name, t_name])

	# Visual feedback — attacker "punch" scale
	var tween := attacker.create_tween()
	tween.tween_property(attacker, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(attacker, "scale", Vector2(1.0, 1.0), 0.1)

	# Attack effect (projectile or melee slash)
	_spawn_attack_effect(attacker, target)

	# Clean up dead target
	if target.is_dead:
		board.remove_unit(target)

# Class-to-effect mapping
const PROJECTILE_MAP: Dictionary = {
	"Archer": "arrow",
	"Warlock": "magic",
	"Priest": "holy",
	"Herbalist": "poison",
}
const SLASH_MAP: Dictionary = {
	"Grunt": "slash",
	"Tank": "slash",
	"Assassin": "slash_assassin",
}

func _trigger_ability(unit: Unit) -> void:
	var unit_class: String = unit.unit_data.unit_class
	var team_tag := "cyan" if unit.team == Unit.Team.PLAYER else "red"
	var u_name := unit.unit_data.unit_name

	match unit_class:
		"Priest":
			# Heal all allied units
			var allies := board.get_units_on_team(unit.team)
			var heal_amount := int(unit.damage * 4.0)
			for ally in allies:
				if ally.is_dead:
					continue
				ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
				ally.health_bar.value = ally.current_hp
			combat_event.emit("[color=%s]%s casts %s — heals all allies for %d![/color]" % [team_tag, u_name, unit.unit_data.ability_name, heal_amount])
		"Warlock":
			# Vulnerable Curse: enemies within 200px get +20 crit vulnerability
			var curse_range := 200.0
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var cursed := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= curse_range:
					enemy.crit_vulnerability += 20.0
					cursed += 1
			combat_event.emit("[color=%s]%s casts %s — %d enemies take +20%% crit![/color]" % [team_tag, u_name, unit.unit_data.ability_name, cursed])
		"Herbalist":
			# Poison all enemies (deal damage over time simulated as instant AoE)
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var poison_dmg := int(unit.damage * 0.5)
			for enemy in enemies:
				if enemy.is_dead:
					continue
				enemy.take_damage(poison_dmg)
				if enemy.is_dead:
					board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s casts %s — poisons all enemies for %d![/color]" % [team_tag, u_name, unit.unit_data.ability_name, poison_dmg])
		"Grunt":
			# Frenzy: temporary attack speed boost
			unit.attacks_per_second *= 1.3
			combat_event.emit("[color=%s]%s enters Frenzy — attack speed up![/color]" % [team_tag, u_name])
		"Tank":
			# Shield Bash: deal (3 * armor + damage) to nearest enemy
			var bash_target := board.find_nearest_enemy(unit)
			if bash_target != null and not bash_target.is_dead:
				var bash_dmg := unit.armor * 3 + unit.damage
				var bash_result := bash_target.take_damage(bash_dmg)
				var t_name := bash_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s uses Shield Bash on %s for %d![/color]" % [team_tag, u_name, t_name, bash_result.damage])
				if bash_target.is_dead:
					combat_event.emit("[color=%s]%s kills %s[/color]" % [team_tag, u_name, t_name])
					board.remove_unit(bash_target)
			else:
				combat_event.emit("[color=%s]%s uses Shield Bash — no target![/color]" % [team_tag, u_name])
		"Assassin":
			# Shadowstrike: guaranteed crit on next hit
			unit.crit_chance += 50.0
			combat_event.emit("[color=%s]%s prepares Shadowstrike — next hit is lethal![/color]" % [team_tag, u_name])
		"Archer":
			# Volley: hit all enemies for reduced damage
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var volley_dmg := int(unit.damage * 0.4)
			for enemy in enemies:
				if enemy.is_dead:
					continue
				enemy.take_damage(volley_dmg)
				if enemy.is_dead:
					board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s fires Volley — hits all enemies for %d![/color]" % [team_tag, u_name, volley_dmg])

	# Visual pulse for ability cast
	var tween := unit.create_tween()
	tween.tween_property(unit, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.15)
	tween.tween_property(unit, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

func _spawn_attack_effect(attacker: Unit, target: Unit) -> void:
	var unit_class: String = attacker.unit_data.unit_class
	var parent: Node = board.get_node("Units")
	if PROJECTILE_MAP.has(unit_class):
		var dist := attacker.position.distance_to(target.position)
		var duration := clampf(dist / 600.0, 0.12, 0.4)
		AttackEffect.spawn_projectile(parent, PROJECTILE_MAP[unit_class], attacker.position, target.position, duration)
	elif SLASH_MAP.has(unit_class):
		AttackEffect.spawn_slash(parent, SLASH_MAP[unit_class], target.position)
