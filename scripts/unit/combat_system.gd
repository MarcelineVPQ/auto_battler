class_name CombatSystem
extends Node

signal combat_ended(player_won: bool)
signal combat_draw()
signal summon_requested(data: UnitData, team: Unit.Team, pos: Vector2, summoner: Unit)
signal combat_event(text: String)
signal tick_completed()

const TICK_INTERVAL: float = 0.5
var MAX_COMBAT_TIME: float:
	get: return SettingsManager.combat_timer

# Class-colored ability effects
const ABILITY_COLORS: Dictionary = {
	"Grunt": Color(0.9, 0.3, 0.2),       # Red-orange
	"Tank": Color(0.4, 0.5, 0.7),         # Steel blue
	"Assassin": Color(0.6, 0.2, 0.8),     # Purple
	"Archer": Color(0.2, 0.8, 0.3),       # Green
	"Paladin": Color(1.0, 0.85, 0.3),     # Gold
	"Warlock": Color(0.5, 0.1, 0.6),      # Dark purple
	"Herbalist": Color(0.3, 0.75, 0.2),   # Nature green
	"Priest": Color(1.0, 1.0, 0.7),       # Holy white-yellow
	"Summoner": Color(0.3, 0.9, 0.8),     # Teal
}

const ABILITY_SOUND_MAP: Dictionary = {
	"Grunt": "ability_melee",
	"Tank": "ability_melee",
	"Assassin": "ability_stealth",
	"Archer": "ability_ranged",
	"Paladin": "ability_holy",
	"Warlock": "ability_dark",
	"Herbalist": "ability_nature",
	"Priest": "heal",
	"Summoner": "summon",
}

var board: Board
var is_fighting: bool = false
var tick_timer: float = 0.0
var combat_elapsed: float = 0.0
var survival_times: Dictionary = {}  # display_name -> seconds survived
var archer_data: UnitData = preload("res://resources/units/archer.tres")
var tank_data: UnitData = preload("res://resources/units/tank.tres")
var warlock_data: UnitData = preload("res://resources/units/warlock.tres")
var skeleton_archer_data: UnitData = preload("res://resources/units/skeleton_archer.tres")
var kill_bounty_gold: int = 0

func setup(b: Board) -> void:
	board = b

func start_combat() -> void:
	is_fighting = true
	tick_timer = 0.0
	combat_elapsed = 0.0
	kill_bounty_gold = 0
	survival_times.clear()
	for unit in board.all_units:
		unit.attack_timer = 0.0
		unit.ability_timer = 0.0
		if unit.primed:
			# Primed units start with full mana — ability fires immediately
			unit.current_mana = unit.max_mana
			unit._update_mana_bar()
		# Reset per-combat buffs
		unit.living_shield_hp = unit.living_shield_max
		unit.invincible_charges = unit.invincible_max
		unit.last_stand_active = false
		if unit.haymaker_counter > 0:
			unit.haymaker_counter = 4
		# Track survival time for player units
		if unit.team == Unit.Team.PLAYER:
			unit.died.connect(_on_player_unit_died, CONNECT_ONE_SHOT)

func stop_combat() -> void:
	is_fighting = false

func _on_player_unit_died(unit: Unit) -> void:
	if unit.display_name != "":
		survival_times[unit.display_name] = combat_elapsed

func _record_surviving_player_times() -> void:
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		if not unit.is_dead and unit.display_name != "":
			survival_times[unit.display_name] = combat_elapsed

func _award_kill_bounty(unit: Unit) -> void:
	if unit.team != Unit.Team.ENEMY:
		return
	var bounty: int = unit.unit_data.farm_cost
	kill_bounty_gold += bounty
	combat_event.emit("[color=yellow]+%dg bounty[/color]" % bounty)

func _process(delta: float) -> void:
	if not is_fighting:
		return

	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer -= TICK_INTERVAL
		_process_tick()

func _process_tick() -> void:
	combat_elapsed += TICK_INTERVAL

	var player_units := board.get_units_on_team(Unit.Team.PLAYER)
	var enemy_units := board.get_units_on_team(Unit.Team.ENEMY)

	# Win/lose check
	if player_units.is_empty():
		is_fighting = false
		_record_surviving_player_times()
		combat_ended.emit(false)
		return
	if enemy_units.is_empty():
		is_fighting = false
		_record_surviving_player_times()
		combat_ended.emit(true)
		return
	# Stalemate — if combat drags on too long, it's a draw (no life lost)
	if combat_elapsed >= MAX_COMBAT_TIME:
		is_fighting = false
		_record_surviving_player_times()
		combat_event.emit("[color=yellow]Draw! Combat timed out — no winner.[/color]")
		combat_draw.emit()
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

		# HP regen
		if unit.hp_regen_per_second > 0.0 and unit.current_hp < unit.max_hp:
			unit.current_hp = mini(
				unit.current_hp + int(unit.hp_regen_per_second * TICK_INTERVAL),
				unit.max_hp
			)
			unit.queue_redraw()

		# Corrosive DoT — shreds armor rating and deals direct HP damage
		if unit.corrosive_dot > 0:
			# Shred armor by 1 per stack (weakens damage reduction)
			if unit.armor > 0:
				unit.armor = maxi(unit.armor - unit.corrosive_dot, 0)
				unit._update_armor_bar()
			# Deal direct HP damage (bypasses armor reduction)
			unit.current_hp -= unit.corrosive_dot
			unit.current_hp = maxi(unit.current_hp, 0)
			unit.queue_redraw()
			if unit.current_hp <= 0:
				unit.die()
				_award_kill_bounty(unit)
				AudioManager.play("death")
				board.remove_unit(unit)
				continue

		# Poison DoT — pure HP damage, no armor shred
		if unit.poison_dot > 0:
			unit.current_hp -= unit.poison_dot
			unit.current_hp = maxi(unit.current_hp, 0)
			unit.queue_redraw()
			if unit.current_hp <= 0:
				unit.die()
				_award_kill_bounty(unit)
				AudioManager.play("death")
				board.remove_unit(unit)
				continue

		# Last Stand: activate bonuses when below 30% HP
		if unit.last_stand and not unit.last_stand_active:
			if float(unit.current_hp) / float(unit.max_hp) < 0.3:
				unit.last_stand_active = true
				unit.damage += 12
				unit.attacks_per_second += 0.4
				unit.evasion += 15.0
				var team_tag := "cyan" if unit.team == Unit.Team.PLAYER else "red"
				var u_name := unit.display_name if unit.display_name != "" else unit.unit_data.unit_name
				combat_event.emit("[color=%s]%s activates Last Stand![/color]" % [team_tag, u_name])

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

		# Summoner: spawn minions instead of attacking
		if unit.unit_data.unit_class == "Summoner":
			if unit.can_attack():
				unit.reset_attack_cooldown()
				var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
				var team_tag := "cyan" if unit.team == Unit.Team.PLAYER else "red"
				var s_name := unit.display_name if unit.display_name != "" else unit.unit_data.unit_name
				match unit.ability_key:
					"summoner_guardian":
						summon_requested.emit(skeleton_archer_data, unit.team, unit.position + offset, unit)
						combat_event.emit("[color=%s]%s raises a Skeleton Guardian[/color]" % [team_tag, s_name])
					"summoner_familiar":
						summon_requested.emit(skeleton_archer_data, unit.team, unit.position + offset, unit)
						combat_event.emit("[color=%s]%s raises a Revenant[/color]" % [team_tag, s_name])
					_:
						summon_requested.emit(skeleton_archer_data, unit.team, unit.position + offset, unit)
						combat_event.emit("[color=%s]%s raises a Skeleton Archer[/color]" % [team_tag, s_name])
				AudioManager.play("summon")
			continue

		if dist <= unit.attack_range:
			# In range — attack if ready
			if unit.can_attack():
				_attack(unit, target)
		else:
			# Out of range — move toward target, but only close enough to attack
			var desired_dist := maxf(unit.attack_range - 10.0, 50.0)
			# Check thorns slow aura from enemies
			var slowed := false
			var opposing := player_units if unit.team == Unit.Team.ENEMY else enemy_units
			for enemy in opposing:
				if not enemy.is_dead and enemy.thorns_slow and unit.position.distance_to(enemy.position) <= 120.0:
					slowed = true
					break
			var effective_speed := unit.move_speed * (0.5 if slowed else 1.0)
			var move_dist := minf(effective_speed, dist - desired_dist)
			if move_dist > 0:
				unit.move_toward_target(target.position, move_dist)

	# Push overlapping units apart
	_separate_units(living)

	# Redraw units so status icons update
	for unit in living:
		if not unit.is_dead:
			unit.queue_redraw()

	tick_completed.emit()

func _separate_units(units: Array[Unit]) -> void:
	const MIN_DIST := 32.0
	for i in range(units.size()):
		if units[i].is_dead:
			continue
		for j in range(i + 1, units.size()):
			if units[j].is_dead:
				continue
			var diff := units[i].position - units[j].position
			var dist := diff.length()
			if dist < MIN_DIST and dist > 0.01:
				var push := diff.normalized() * (MIN_DIST - dist) * 0.5
				units[i].position += push
				units[j].position -= push
			elif dist < 0.01:
				# Exactly overlapping — push apart randomly
				var nudge := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * MIN_DIST * 0.5
				units[i].position += nudge
				units[j].position -= nudge

func _attack(attacker: Unit, target: Unit) -> void:
	attacker.reset_attack_cooldown()

	# Spend mana on attack
	attacker.current_mana = mini(
		attacker.current_mana + attacker.mana_cost_per_attack,
		attacker.max_mana
	)
	attacker._update_mana_bar()

	# Invincible: target ignores the hit entirely
	if target.invincible_charges > 0:
		target.invincible_charges -= 1
		var atk_tag := "cyan" if attacker.team == Unit.Team.PLAYER else "red"
		var t_name := target.display_name if target.display_name != "" else target.unit_data.unit_name
		combat_event.emit("[color=%s]%s is Invincible! (%d charges left)[/color]" % [atk_tag, t_name, target.invincible_charges])
		AudioManager.play("miss", -6.0)
		_spawn_attack_effect(attacker, target)
		return

	# Calculate damage with crit (target vulnerability increases crit chance)
	var atk_damage := attacker.damage
	var effective_crit := attacker.crit_chance + target.crit_vulnerability
	var is_crit := randf() * 100.0 < effective_crit
	if is_crit:
		atk_damage *= 2

	# Haymaker: every 4th attack deals 3x damage
	if attacker.haymaker_counter > 0:
		attacker.haymaker_counter -= 1
		if attacker.haymaker_counter <= 0:
			attacker.haymaker_counter = 4
			atk_damage *= 3

	# Living Shield: absorb damage before it reaches the target
	if target.living_shield_hp > 0:
		if atk_damage <= target.living_shield_hp:
			target.living_shield_hp -= atk_damage
			var atk_tag := "cyan" if attacker.team == Unit.Team.PLAYER else "red"
			var t_name := target.display_name if target.display_name != "" else target.unit_data.unit_name
			combat_event.emit("[color=%s]%s's Living Shield absorbs %d dmg (%d remaining)[/color]" % [atk_tag, t_name, atk_damage, target.living_shield_hp])
			AudioManager.play("miss", -6.0)
			_spawn_attack_effect(attacker, target)
			var tween := attacker.create_tween()
			tween.tween_property(attacker, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(attacker, "scale", Vector2(1.0, 1.0), 0.1)
			return
		else:
			atk_damage -= target.living_shield_hp
			target.living_shield_hp = 0

	# Deal damage (armor/evasion handled inside target)
	var result := target.take_damage(atk_damage, attacker.armor_pen)

	# Combat log
	var atk_tag := "cyan" if attacker.team == Unit.Team.PLAYER else "red"
	var a_name := attacker.display_name if attacker.display_name != "" else attacker.unit_data.unit_name
	var t_name := target.display_name if target.display_name != "" else target.unit_data.unit_name
	if result.deflected:
		combat_event.emit("[color=%s]%s's armor deflects %s[/color]" % [atk_tag, t_name, a_name])
		AudioManager.play("miss", -6.0)
	elif result.evaded:
		combat_event.emit("[color=%s]%s evades %s[/color]" % [atk_tag, t_name, a_name])
		AudioManager.play("miss", -6.0)
	elif is_crit:
		combat_event.emit("[color=%s]%s CRITS %s for %d dmg![/color]" % [atk_tag, a_name, t_name, result.damage])
		AudioManager.play("crit")
	elif result.hit:
		combat_event.emit("[color=%s]%s hits %s for %d dmg[/color]" % [atk_tag, a_name, t_name, result.damage])
		AudioManager.play("hit", -8.0)

	# Lifesteal: heal attacker for percentage of damage dealt
	if result.hit and attacker.lifesteal_pct > 0.0:
		var heal := int(ceil(float(result.damage) * attacker.lifesteal_pct))
		attacker.current_hp = mini(attacker.current_hp + heal, attacker.max_hp)
		attacker.queue_redraw()

	# Apply corrosive stacks on hit
	if result.hit and attacker.corrosive_power > 0:
		target.corrosive_dot += attacker.corrosive_power

	# Apply poison stacks on hit
	if result.hit and attacker.poison_power > 0:
		target.poison_dot += attacker.poison_power

	# Sepsis: spread corrosive to enemies near target on hit
	if result.hit and attacker.sepsis_spread > 0:
		var nearby_team := board.get_units_on_team(target.team)
		for nearby in nearby_team:
			if nearby != target and not nearby.is_dead and target.position.distance_to(nearby.position) <= 100.0:
				nearby.corrosive_dot += attacker.sepsis_spread

	if target.is_dead:
		_award_kill_bounty(target)
		combat_event.emit("[color=%s]%s kills %s[/color]" % [atk_tag, a_name, t_name])
		AudioManager.play("death")
		# Relentless: on kill, gain permanent stats
		if attacker.relentless:
			attacker.damage += 2
			attacker.attacks_per_second += 0.1
			combat_event.emit("[color=%s]%s grows stronger! (Relentless)[/color]" % [atk_tag, a_name])

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
	"SkeletonArcher": "arrow",
	"Warlock": "magic",
	"Priest": "holy",
	"Herbalist": "poison",
}
const SLASH_MAP: Dictionary = {
	"Grunt": "slash",
	"Tank": "slash",
	"Assassin": "slash_assassin",
	"Paladin": "slash",
}

func _trigger_ability(unit: Unit) -> void:
	var team_tag := "cyan" if unit.team == Unit.Team.PLAYER else "red"
	var u_name := unit.display_name if unit.display_name != "" else unit.unit_data.unit_name
	var ab_name := unit.instance_ability_name if unit.instance_ability_name != "" else unit.unit_data.ability_name

	match unit.ability_key:
		# ── Priest ── (prioritizes poisoned allies)
		"priest_heal":
			var allies := board.get_units_on_team(unit.team)
			var heal_amount := int(unit.damage * 5.0)
			var healed := 0
			var cleansed := 0
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
				ally.queue_redraw()
				healed += 1
				if ally.poison_dot > 0:
					ally.poison_dot = 0
					cleansed += 1
			var msg := "[color=%s]%s casts %s — heals %d allies for %d!" % [team_tag, u_name, ab_name, healed, heal_amount]
			if cleansed > 0:
				msg += " Cleanses poison from %d!" % cleansed
			msg += "[/color]"
			combat_event.emit(msg)
		"priest_shield":
			var allies := board.get_units_on_team(unit.team)
			var target_ally: Unit = null
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				# Prioritize poisoned allies, then weakest HP
				if target_ally == null:
					target_ally = ally
				elif ally.poison_dot > 0 and target_ally.poison_dot <= 0:
					target_ally = ally
				elif ally.poison_dot > 0 and target_ally.poison_dot > 0 and ally.poison_dot > target_ally.poison_dot:
					target_ally = ally
				elif ally.poison_dot <= 0 and target_ally.poison_dot <= 0 and ally.current_hp < target_ally.current_hp:
					target_ally = ally
			if target_ally:
				var shield_amount := int(target_ally.max_hp * 0.5)
				target_ally.armor += shield_amount
				target_ally.max_armor = maxi(target_ally.max_armor, target_ally.armor)
				target_ally._update_armor_bar()
				var t_name := target_ally.display_name if target_ally.display_name != "" else target_ally.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s — +%d armor![/color]" % [team_tag, u_name, ab_name, t_name, shield_amount])
		"priest_purify":
			var allies := board.get_units_on_team(unit.team)
			var target_ally: Unit = null
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				# Prioritize poisoned allies, then weakest HP
				if target_ally == null:
					target_ally = ally
				elif ally.poison_dot > 0 and target_ally.poison_dot <= 0:
					target_ally = ally
				elif ally.poison_dot > 0 and target_ally.poison_dot > 0 and ally.poison_dot > target_ally.poison_dot:
					target_ally = ally
				elif ally.poison_dot <= 0 and target_ally.poison_dot <= 0 and ally.current_hp < target_ally.current_hp:
					target_ally = ally
			if target_ally:
				var heal_amount := int(unit.damage * 10.0)
				target_ally.current_hp = mini(target_ally.current_hp + heal_amount, target_ally.max_hp)
				target_ally.queue_redraw()
				target_ally.crit_vulnerability = 0.0
				var had_poison := target_ally.poison_dot > 0
				target_ally.poison_dot = 0
				var t_name := target_ally.display_name if target_ally.display_name != "" else target_ally.unit_data.unit_name
				var msg := "[color=%s]%s casts %s on %s — heals %d" % [team_tag, u_name, ab_name, t_name, heal_amount]
				if had_poison:
					msg += " & cleanses poison"
				msg += "![/color]"
				combat_event.emit(msg)

		# ── Warlock ──
		"warlock_soulfire":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var soulfire_dmg := int(unit.damage * 2.0)
			var hit_count := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= unit.ability_range:
					enemy.take_damage(soulfire_dmg)
					hit_count += 1
					if enemy.is_dead:
						_award_kill_bounty(enemy)
						board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s casts %s — hits %d enemies for %d![/color]" % [team_tag, u_name, ab_name, hit_count, soulfire_dmg])
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Warlock", Color.WHITE))
		"warlock_drain":
			var drain_target := board.find_nearest_enemy(unit)
			if drain_target and not drain_target.is_dead:
				var drain_dmg := int(unit.damage * 2.0)
				var result := drain_target.take_damage(drain_dmg)
				unit.current_hp = mini(unit.current_hp + drain_dmg, unit.max_hp)
				unit.queue_redraw()
				var t_name := drain_target.display_name if drain_target.display_name != "" else drain_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s — drains %d HP![/color]" % [team_tag, u_name, ab_name, t_name, drain_dmg])
				if drain_target.is_dead:
					_award_kill_bounty(drain_target)
					board.remove_unit(drain_target)
		"warlock_bolt":
			var bolt_target := board.find_nearest_enemy(unit)
			if bolt_target and not bolt_target.is_dead:
				var bolt_dmg := int(unit.damage * 4.0)
				var result := bolt_target.take_damage(bolt_dmg)
				var t_name := bolt_target.display_name if bolt_target.display_name != "" else bolt_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s for %d![/color]" % [team_tag, u_name, ab_name, t_name, result.damage])
				if bolt_target.is_dead:
					_award_kill_bounty(bolt_target)
					board.remove_unit(bolt_target)

	# Hellfire upgrade: Warlock AoE splash after Drain/Bolt abilities
	if unit.unit_data.unit_class == "Warlock" and unit.hellfire and unit.ability_key in ["warlock_drain", "warlock_bolt"]:
		var hf_enemies := board.get_units_on_team(
			Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
		)
		var splash_dmg := int(unit.damage * 0.5)
		var splash_hits := 0
		for enemy in hf_enemies:
			if enemy.is_dead:
				continue
			if unit.position.distance_to(enemy.position) <= unit.ability_range:
				enemy.take_damage(splash_dmg)
				splash_hits += 1
				if enemy.is_dead:
					_award_kill_bounty(enemy)
					board.remove_unit(enemy)
		if splash_hits > 0:
			combat_event.emit("[color=%s]%s's Hellfire blasts %d enemies for %d![/color]" % [team_tag, u_name, splash_hits, splash_dmg])
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Warlock", Color.WHITE))

	match unit.ability_key:
		# ── Herbalist ──
		"herbalist_poison":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var poison_dmg := int(unit.damage * 0.5)
			var poisoned := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) > unit.ability_range:
					continue
				enemy.take_damage(poison_dmg)
				poisoned += 1
				if enemy.is_dead:
					_award_kill_bounty(enemy)
					board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s casts %s — poisons %d enemies for %d![/color]" % [team_tag, u_name, ab_name, poisoned, poison_dmg])
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Herbalist", Color.WHITE))
		"herbalist_regen":
			var allies := board.get_units_on_team(unit.team)
			var heal_amount := int(unit.damage * 2.0)
			var healed := 0
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
				ally.queue_redraw()
				healed += 1
			combat_event.emit("[color=%s]%s casts %s — heals %d allies for %d![/color]" % [team_tag, u_name, ab_name, healed, heal_amount])
		"herbalist_burst":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var burst_dmg := int(unit.damage * 2.0)
			var hit_count := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= unit.ability_range:
					enemy.take_damage(burst_dmg)
					hit_count += 1
					if enemy.is_dead:
						_award_kill_bounty(enemy)
						board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s casts %s — hits %d enemies for %d![/color]" % [team_tag, u_name, ab_name, hit_count, burst_dmg])
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Herbalist", Color.WHITE))

		# ── Grunt ──
		"grunt_frenzy":
			unit.attacks_per_second *= 1.3
			var frenzy_allies: Array[Unit] = []
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.attacks_per_second *= 1.1
					frenzy_allies.append(ally)
			var msg := "[color=%s]%s enters %s — attack speed up!" % [team_tag, u_name, ab_name]
			if frenzy_allies.size() > 0:
				msg += " %d nearby allies gain +10%% atk speed." % frenzy_allies.size()
			msg += "[/color]"
			combat_event.emit(msg)
			# Revert after 3 seconds
			var frenzy_revert := unit.create_tween()
			frenzy_revert.tween_callback(func():
				if is_instance_valid(unit) and not unit.is_dead:
					unit.attacks_per_second /= 1.3
				for a in frenzy_allies:
					if is_instance_valid(a) and not a.is_dead:
						a.attacks_per_second /= 1.1
			).set_delay(3.0)
		"grunt_warcry":
			var warcry_allies: Array[Unit] = []
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.damage += 3
				warcry_allies.append(ally)
			combat_event.emit("[color=%s]%s uses %s — %d allies gain +3 damage![/color]" % [team_tag, u_name, ab_name, warcry_allies.size()])
			# Revert after 3 seconds
			var warcry_revert := unit.create_tween()
			warcry_revert.tween_callback(func():
				for a in warcry_allies:
					if is_instance_valid(a) and not a.is_dead:
						a.damage -= 3
			).set_delay(3.0)
		"grunt_cleave":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var cleave_dmg := int(unit.damage * 1.5)
			var hit_count := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= unit.ability_range:
					enemy.take_damage(cleave_dmg)
					hit_count += 1
					if enemy.is_dead:
						_award_kill_bounty(enemy)
						board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s uses %s — cleaves %d enemies for %d![/color]" % [team_tag, u_name, ab_name, hit_count, cleave_dmg])
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Grunt", Color.WHITE))

		# ── Tank ──
		"tank_bash":
			var bash_target := board.find_nearest_enemy(unit)
			if bash_target != null and not bash_target.is_dead:
				var bash_dmg := unit.armor + unit.damage
				var bash_result := bash_target.take_damage(bash_dmg)
				var t_name := bash_target.display_name if bash_target.display_name != "" else bash_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s uses %s on %s for %d![/color]" % [team_tag, u_name, ab_name, t_name, bash_result.damage])
				if bash_target.is_dead:
					_award_kill_bounty(bash_target)
					combat_event.emit("[color=%s]%s kills %s[/color]" % [team_tag, u_name, t_name])
					board.remove_unit(bash_target)
			else:
				combat_event.emit("[color=%s]%s uses %s — no target![/color]" % [team_tag, u_name, ab_name])
		"tank_taunt":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var taunted := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= unit.ability_range:
					# Move enemy closer to force targeting
					var dir := (unit.position - enemy.position).normalized()
					enemy.position += dir * 10.0
					taunted += 1
			unit.armor += 15
			unit.max_armor = maxi(unit.max_armor, unit.armor)
			unit._update_armor_bar()
			combat_event.emit("[color=%s]%s uses %s — taunts %d enemies, +15 armor![/color]" % [team_tag, u_name, ab_name, taunted])
		"tank_fortify":
			var fortify_armor := int(unit.max_hp * 0.5)
			unit.armor += fortify_armor
			unit.max_armor = maxi(unit.max_armor, unit.armor)
			unit._update_armor_bar()
			var saved_speed := unit.move_speed
			unit.move_speed = 0.0
			# Restore speed after 1 tick
			var speed_tween := unit.create_tween()
			speed_tween.tween_callback(func():
				if is_instance_valid(unit) and not unit.is_dead:
					unit.move_speed = saved_speed
			).set_delay(TICK_INTERVAL)
			var fortify_buffed := 0
			var ally_armor := int(fortify_armor * 0.25)
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.armor += ally_armor
					ally.max_armor = maxi(ally.max_armor, ally.armor)
					ally._update_armor_bar()
					fortify_buffed += 1
			var msg := "[color=%s]%s uses %s — +%d armor, rooted!" % [team_tag, u_name, ab_name, fortify_armor]
			if fortify_buffed > 0:
				msg += " %d nearby allies gain +%d armor." % [fortify_buffed, ally_armor]
			msg += "[/color]"
			combat_event.emit(msg)

		# ── Assassin ──
		"assassin_shadow":
			unit.crit_chance += 50.0
			var shadow_allies: Array[Unit] = []
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.crit_chance += 10.0
					shadow_allies.append(ally)
			var msg := "[color=%s]%s prepares %s — next hit is lethal!" % [team_tag, u_name, ab_name]
			if shadow_allies.size() > 0:
				msg += " %d nearby allies gain +10%% crit." % shadow_allies.size()
			msg += "[/color]"
			combat_event.emit(msg)
			# Revert after 3 seconds
			var shadow_revert := unit.create_tween()
			shadow_revert.tween_callback(func():
				if is_instance_valid(unit) and not unit.is_dead:
					unit.crit_chance -= 50.0
				for a in shadow_allies:
					if is_instance_valid(a) and not a.is_dead:
						a.crit_chance -= 10.0
			).set_delay(3.0)
		"assassin_poison":
			# Bonus damage for 3 seconds
			var bonus := int(unit.damage * 0.8)
			var self_bonus := bonus * 3
			unit.damage += self_bonus
			var half_bonus := int(bonus * 1.5)
			var poison_allies: Array[Unit] = []
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.damage += half_bonus
					poison_allies.append(ally)
			var msg := "[color=%s]%s coats %s — +%d bonus damage!" % [team_tag, u_name, ab_name, self_bonus]
			if poison_allies.size() > 0:
				msg += " %d nearby allies gain +%d damage." % [poison_allies.size(), half_bonus]
			msg += "[/color]"
			combat_event.emit(msg)
			# Revert after 3 seconds
			var poison_revert := unit.create_tween()
			poison_revert.tween_callback(func():
				if is_instance_valid(unit) and not unit.is_dead:
					unit.damage -= self_bonus
				for a in poison_allies:
					if is_instance_valid(a) and not a.is_dead:
						a.damage -= half_bonus
			).set_delay(3.0)
		"assassin_vanish":
			unit.evasion += 80.0
			unit.crit_chance += 100.0
			var vanish_allies: Array[Unit] = []
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.evasion += 20.0
					vanish_allies.append(ally)
			var msg := "[color=%s]%s uses %s — +80%% evasion & guaranteed crit!" % [team_tag, u_name, ab_name]
			if vanish_allies.size() > 0:
				msg += " %d nearby allies gain +20%% evasion." % vanish_allies.size()
			msg += "[/color]"
			combat_event.emit(msg)
			# Revert after 3 seconds
			var vanish_revert := unit.create_tween()
			vanish_revert.tween_callback(func():
				if is_instance_valid(unit) and not unit.is_dead:
					unit.evasion -= 80.0
					unit.crit_chance -= 100.0
				for a in vanish_allies:
					if is_instance_valid(a) and not a.is_dead:
						a.evasion -= 20.0
			).set_delay(3.0)

		# ── Paladin ── (cleanses corrosive)
		"paladin_aegis":
			var allies := board.get_units_on_team(unit.team)
			var aegis_allies: Array[Unit] = []
			var cleansed := 0
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.armor += 5
				ally.max_armor = maxi(ally.max_armor, ally.armor)
				ally.armor_effectiveness += 0.15
				ally._update_armor_bar()
				ally.damage += 2
				aegis_allies.append(ally)
				if ally.corrosive_dot > 0:
					ally.corrosive_dot = 0
					ally.restore_armor()
					ally._update_armor_bar()
					cleansed += 1
			var msg := "[color=%s]%s casts %s — +5 armor, +15%% armor power & +2 dmg to %d allies!" % [team_tag, u_name, ab_name, aegis_allies.size()]
			if cleansed > 0:
				msg += " Cleanses corrosive from %d!" % cleansed
			msg += "[/color]"
			combat_event.emit(msg)
			# Revert effectiveness and damage after 3 seconds (armor/cleanse stays)
			var aegis_revert := unit.create_tween()
			aegis_revert.tween_callback(func():
				for a in aegis_allies:
					if is_instance_valid(a) and not a.is_dead:
						a.armor_effectiveness -= 0.15
						a.damage -= 2
			).set_delay(3.0)
		"paladin_smite":
			var smite_target := board.find_nearest_enemy(unit)
			if smite_target and not smite_target.is_dead:
				var smite_dmg := int((unit.damage + unit.armor) * 2.0)
				var result := smite_target.take_damage(smite_dmg)
				var heal_amount := int(smite_dmg * 0.5)
				unit.current_hp = mini(unit.current_hp + heal_amount, unit.max_hp)
				unit.queue_redraw()
				var t_name := smite_target.display_name if smite_target.display_name != "" else smite_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s for %d, heals %d![/color]" % [team_tag, u_name, ab_name, t_name, result.damage, heal_amount])
				if smite_target.is_dead:
					_award_kill_bounty(smite_target)
					board.remove_unit(smite_target)
		"paladin_consecrate":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var allies := board.get_units_on_team(unit.team)
			var cons_dmg := int(unit.damage * 1.5)
			var heal_amount := int(unit.damage * 1.5)
			var hit_count := 0
			var cleansed := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= unit.ability_range:
					enemy.take_damage(cons_dmg)
					hit_count += 1
					if enemy.is_dead:
						_award_kill_bounty(enemy)
						board.remove_unit(enemy)
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
					ally.queue_redraw()
					if ally.corrosive_dot > 0:
						ally.corrosive_dot = 0
						ally.restore_armor()
						ally._update_armor_bar()
						cleansed += 1
			var msg := "[color=%s]%s casts %s — hits %d enemies for %d, heals nearby allies!" % [team_tag, u_name, ab_name, hit_count, cons_dmg]
			if cleansed > 0:
				msg += " Cleanses corrosive from %d!" % cleansed
			msg += "[/color]"
			combat_event.emit(msg)
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Paladin", Color.WHITE))

		# ── Archer ──
		"archer_volley":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var volley_dmg := int(unit.damage * 0.6)
			var volley_hit := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) > unit.ability_range:
					continue
				enemy.take_damage(volley_dmg)
				volley_hit += 1
				if enemy.is_dead:
					_award_kill_bounty(enemy)
					board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s fires %s — hits %d enemies for %d![/color]" % [team_tag, u_name, ab_name, volley_hit, volley_dmg])
			_spawn_aoe_ring(unit.position, unit.ability_range, ABILITY_COLORS.get("Archer", Color.WHITE))
		"archer_pierce":
			var pierce_target := board.find_nearest_enemy(unit)
			if pierce_target and not pierce_target.is_dead:
				var pierce_dmg := int(unit.damage * 3.0)
				# Ignore armor: deal directly to HP
				pierce_target.current_hp -= pierce_dmg
				pierce_target.current_hp = maxi(pierce_target.current_hp, 0)
				pierce_target.queue_redraw()
				var t_name := pierce_target.display_name if pierce_target.display_name != "" else pierce_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s fires %s at %s for %d (ignores armor)![/color]" % [team_tag, u_name, ab_name, t_name, pierce_dmg])
				if pierce_target.current_hp <= 0:
					pierce_target.die()
					_award_kill_bounty(pierce_target)
					board.remove_unit(pierce_target)
		"archer_mark":
			var mark_target := board.find_nearest_enemy(unit)
			if mark_target and not mark_target.is_dead:
				mark_target.crit_vulnerability += 30.0
				var t_name := mark_target.display_name if mark_target.display_name != "" else mark_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s uses %s on %s — takes +30%% more damage![/color]" % [team_tag, u_name, ab_name, t_name])
				# Revert after 5 seconds
				var mark_revert := unit.create_tween()
				var marked := mark_target
				mark_revert.tween_callback(func():
					if is_instance_valid(marked) and not marked.is_dead:
						marked.crit_vulnerability -= 30.0
				).set_delay(5.0)

		# ── Summoner (abilities fire via mana, summoning via attack) ──
		"summoner_archer", "summoner_guardian", "summoner_familiar":
			# Summoner abilities are handled in the attack phase; mana trigger does nothing extra
			return

	# Play class-colored VFX + class-specific SFX
	_play_ability_effects(unit)

func _play_ability_effects(unit: Unit) -> void:
	var unit_class: String = unit.unit_data.unit_class
	var ab_name: String = unit.instance_ability_name if unit.instance_ability_name != "" else unit.unit_data.ability_name
	var color: Color = ABILITY_COLORS.get(unit_class, Color(1.0, 1.0, 1.0))

	# Class-colored flash (replaces generic white flash)
	var bright := Color(
		minf(color.r + 0.5, 1.5),
		minf(color.g + 0.5, 1.5),
		minf(color.b + 0.5, 1.5),
		1.0
	)
	var tween := unit.create_tween()
	tween.tween_property(unit, "modulate", bright, 0.12)
	tween.tween_property(unit, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

	# Expanding ring VFX
	_spawn_ability_ring(unit.position, color)

	# Floating ability name label
	_spawn_ability_label(unit.position, ab_name, color)

	# Class-specific sound
	var sound_key: String = ABILITY_SOUND_MAP.get(unit_class, "ability")
	AudioManager.play(sound_key)

func _spawn_ability_ring(pos: Vector2, color: Color) -> void:
	var ring := Node2D.new()
	ring.position = pos
	ring.z_index = 1
	ring.set_meta("ring_radius", 15.0)
	ring.set_meta("ring_alpha", 0.8)
	ring.set_meta("ring_color", color)
	ring.draw.connect(func():
		var r: float = ring.get_meta("ring_radius")
		var a: float = ring.get_meta("ring_alpha")
		var c: Color = ring.get_meta("ring_color")
		c.a = a
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 32, c, 2.5)
	)
	board.add_child(ring)
	var ring_tween := board.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_method(func(r: float):
		if is_instance_valid(ring):
			ring.set_meta("ring_radius", r)
			ring.queue_redraw()
	, 15.0, 45.0, 0.35)
	ring_tween.tween_method(func(a: float):
		if is_instance_valid(ring):
			ring.set_meta("ring_alpha", a)
			ring.queue_redraw()
	, 0.8, 0.0, 0.35)
	ring_tween.set_parallel(false)
	ring_tween.tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)

func _spawn_aoe_ring(pos: Vector2, radius: float, color: Color) -> void:
	var ring := Node2D.new()
	ring.position = pos
	ring.z_index = 1
	ring.set_meta("ring_radius", 0.0)
	ring.set_meta("ring_alpha", 0.4)
	ring.set_meta("ring_color", color)
	ring.draw.connect(func():
		var r: float = ring.get_meta("ring_radius")
		var a: float = ring.get_meta("ring_alpha")
		var c: Color = ring.get_meta("ring_color")
		c.a = a * 0.3
		ring.draw_circle(Vector2.ZERO, r, c)
		c.a = a
		ring.draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 2.0)
	)
	board.add_child(ring)
	var ring_tween := board.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_method(func(r: float):
		if is_instance_valid(ring):
			ring.set_meta("ring_radius", r)
			ring.queue_redraw()
	, 0.0, radius, 0.25)
	ring_tween.tween_method(func(a: float):
		if is_instance_valid(ring):
			ring.set_meta("ring_alpha", a)
			ring.queue_redraw()
	, 0.4, 0.0, 0.4)
	ring_tween.set_parallel(false)
	ring_tween.tween_callback(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)

func _spawn_ability_label(pos: Vector2, text: String, color: Color) -> void:
	var label := Node2D.new()
	label.position = pos + Vector2(0, -20)
	label.z_index = 2
	label.set_meta("label_text", text)
	label.set_meta("label_color", color)
	label.set_meta("label_alpha", 1.0)
	label.draw.connect(func():
		var t: String = label.get_meta("label_text")
		var c: Color = label.get_meta("label_color")
		var a: float = label.get_meta("label_alpha")
		var font := ThemeDB.fallback_font
		var font_size := 11
		var text_size := font.get_string_size(t, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var offset := Vector2(-text_size.x * 0.5, 0)
		# Dark shadow for readability
		var shadow_col := Color(0, 0, 0, a * 0.8)
		label.draw_string(font, offset + Vector2(1, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow_col)
		# Colored text
		c.a = a
		label.draw_string(font, offset, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
	)
	board.add_child(label)
	var label_tween := board.create_tween()
	label_tween.set_parallel(true)
	label_tween.tween_property(label, "position:y", pos.y - 45, 0.6)
	label_tween.tween_method(func(a: float):
		if is_instance_valid(label):
			label.set_meta("label_alpha", a)
			label.queue_redraw()
	, 1.0, 0.0, 0.6)
	label_tween.set_parallel(false)
	label_tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)

func _spawn_attack_effect(attacker: Unit, target: Unit) -> void:
	var unit_class: String = attacker.unit_data.unit_class
	var parent: Node = board.get_node("Units")
	if PROJECTILE_MAP.has(unit_class):
		var dist := attacker.position.distance_to(target.position)
		var duration := clampf(dist / 600.0, 0.12, 0.4)
		AttackEffect.spawn_projectile(parent, PROJECTILE_MAP[unit_class], attacker.position, target.position, duration)
	elif SLASH_MAP.has(unit_class):
		AttackEffect.spawn_slash(parent, SLASH_MAP[unit_class], target.position)
