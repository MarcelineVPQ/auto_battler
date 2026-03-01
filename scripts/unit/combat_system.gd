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
var combat_elapsed: float = 0.0
var survival_times: Dictionary = {}  # display_name -> seconds survived
var archer_data: UnitData = preload("res://resources/units/archer.tres")
var tank_data: UnitData = preload("res://resources/units/tank.tres")
var warlock_data: UnitData = preload("res://resources/units/warlock.tres")
var skeleton_archer_data: UnitData = preload("res://resources/units/skeleton_archer.tres")

func setup(b: Board) -> void:
	board = b

func start_combat() -> void:
	is_fighting = true
	tick_timer = 0.0
	combat_elapsed = 0.0
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
			unit.health_bar.value = unit.current_hp

		# Corrosive DoT — shreds armor rating and deals direct HP damage
		if unit.corrosive_dot > 0:
			# Shred armor by 1 per stack (weakens damage reduction)
			if unit.armor > 0:
				unit.armor = maxi(unit.armor - unit.corrosive_dot, 0)
				unit._update_armor_bar()
			# Deal direct HP damage (bypasses armor reduction)
			unit.current_hp -= unit.corrosive_dot
			unit.current_hp = maxi(unit.current_hp, 0)
			unit.health_bar.value = unit.current_hp
			if unit.current_hp <= 0:
				unit.die()
				board.remove_unit(unit)
				continue

		# Poison DoT — pure HP damage, no armor shred
		if unit.poison_dot > 0:
			unit.current_hp -= unit.poison_dot
			unit.current_hp = maxi(unit.current_hp, 0)
			unit.health_bar.value = unit.current_hp
			if unit.current_hp <= 0:
				unit.die()
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
	var result := target.take_damage(atk_damage)

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
		attacker.health_bar.value = attacker.current_hp

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
			var heal_amount := int(unit.damage * 4.0)
			var healed := 0
			var cleansed := 0
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
				ally.health_bar.value = ally.current_hp
				healed += 1
				if ally.poison_dot > 0:
					ally.poison_dot = 0
					cleansed += 1
			var msg := "[color=%s]%s casts %s — heals %d allies for %d!" % [team_tag, u_name, ab_name, healed, heal_amount]
			if cleansed > 0:
				msg += " Cleanses poison from %d!" % cleansed
			msg += "[/color]"
			combat_event.emit(msg)
			AudioManager.play("heal")
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
			AudioManager.play("heal")
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
				var heal_amount := int(unit.damage * 8.0)
				target_ally.current_hp = mini(target_ally.current_hp + heal_amount, target_ally.max_hp)
				target_ally.health_bar.value = target_ally.current_hp
				target_ally.crit_vulnerability = 0.0
				var had_poison := target_ally.poison_dot > 0
				target_ally.poison_dot = 0
				var t_name := target_ally.display_name if target_ally.display_name != "" else target_ally.unit_data.unit_name
				var msg := "[color=%s]%s casts %s on %s — heals %d" % [team_tag, u_name, ab_name, t_name, heal_amount]
				if had_poison:
					msg += " & cleanses poison"
				msg += "![/color]"
				combat_event.emit(msg)
			AudioManager.play("heal")

		# ── Warlock ──
		"warlock_curse":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var cursed := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) <= unit.ability_range:
					enemy.crit_vulnerability += 20.0
					cursed += 1
			combat_event.emit("[color=%s]%s casts %s — %d enemies take +20%% crit![/color]" % [team_tag, u_name, ab_name, cursed])
			AudioManager.play("curse")
		"warlock_drain":
			var drain_target := board.find_nearest_enemy(unit)
			if drain_target and not drain_target.is_dead:
				var drain_dmg := int(unit.damage * 2.0)
				var result := drain_target.take_damage(drain_dmg)
				unit.current_hp = mini(unit.current_hp + drain_dmg, unit.max_hp)
				unit.health_bar.value = unit.current_hp
				var t_name := drain_target.display_name if drain_target.display_name != "" else drain_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s — drains %d HP![/color]" % [team_tag, u_name, ab_name, t_name, drain_dmg])
				if drain_target.is_dead:
					board.remove_unit(drain_target)
			AudioManager.play("curse")
		"warlock_bolt":
			var bolt_target := board.find_nearest_enemy(unit)
			if bolt_target and not bolt_target.is_dead:
				var bolt_dmg := int(unit.damage * 4.0)
				var result := bolt_target.take_damage(bolt_dmg)
				var t_name := bolt_target.display_name if bolt_target.display_name != "" else bolt_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s for %d![/color]" % [team_tag, u_name, ab_name, t_name, result.damage])
				if bolt_target.is_dead:
					board.remove_unit(bolt_target)
			AudioManager.play("curse")

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
					board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s casts %s — poisons %d enemies for %d![/color]" % [team_tag, u_name, ab_name, poisoned, poison_dmg])
			AudioManager.play("poison")
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
				ally.health_bar.value = ally.current_hp
				healed += 1
			combat_event.emit("[color=%s]%s casts %s — heals %d allies for %d![/color]" % [team_tag, u_name, ab_name, healed, heal_amount])
			AudioManager.play("heal")
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
						board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s casts %s — hits %d enemies for %d![/color]" % [team_tag, u_name, ab_name, hit_count, burst_dmg])
			AudioManager.play("poison")

		# ── Grunt ──
		"grunt_frenzy":
			unit.attacks_per_second *= 1.3
			var frenzy_buffed := 0
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.attacks_per_second *= 1.1
					frenzy_buffed += 1
			var msg := "[color=%s]%s enters %s — attack speed up!" % [team_tag, u_name, ab_name]
			if frenzy_buffed > 0:
				msg += " %d nearby allies gain +10%% atk speed." % frenzy_buffed
			msg += "[/color]"
			combat_event.emit(msg)
			AudioManager.play("ability")
		"grunt_warcry":
			var allies := board.get_units_on_team(unit.team)
			var buffed := 0
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.damage += 3
				buffed += 1
			combat_event.emit("[color=%s]%s uses %s — %d allies gain +3 damage![/color]" % [team_tag, u_name, ab_name, buffed])
			AudioManager.play("ability")
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
						board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s uses %s — cleaves %d enemies for %d![/color]" % [team_tag, u_name, ab_name, hit_count, cleave_dmg])
			AudioManager.play("ability")

		# ── Tank ──
		"tank_bash":
			var bash_target := board.find_nearest_enemy(unit)
			if bash_target != null and not bash_target.is_dead:
				var bash_dmg := unit.armor + unit.damage
				var bash_result := bash_target.take_damage(bash_dmg)
				var t_name := bash_target.display_name if bash_target.display_name != "" else bash_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s uses %s on %s for %d![/color]" % [team_tag, u_name, ab_name, t_name, bash_result.damage])
				AudioManager.play("ability")
				if bash_target.is_dead:
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
			AudioManager.play("ability")
		"tank_fortify":
			var fortify_armor := int(unit.max_hp * 0.5)
			unit.armor += fortify_armor
			unit.max_armor = maxi(unit.max_armor, unit.armor)
			unit._update_armor_bar()
			unit.move_speed = 0.0
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
			AudioManager.play("ability")

		# ── Assassin ──
		"assassin_shadow":
			unit.crit_chance += 50.0
			var shadow_buffed := 0
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.crit_chance += 10.0
					shadow_buffed += 1
			var msg := "[color=%s]%s prepares %s — next hit is lethal!" % [team_tag, u_name, ab_name]
			if shadow_buffed > 0:
				msg += " %d nearby allies gain +10%% crit." % shadow_buffed
			msg += "[/color]"
			combat_event.emit(msg)
			AudioManager.play("ability")
		"assassin_poison":
			# Bonus damage on next 3 attacks simulated as +damage buff
			var bonus := int(unit.damage * 0.8)
			unit.damage += bonus * 3
			var half_bonus := int(bonus * 1.5)  # half of (bonus * 3)
			var poison_buffed := 0
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.damage += half_bonus
					poison_buffed += 1
			var msg := "[color=%s]%s coats %s — +%d bonus damage!" % [team_tag, u_name, ab_name, bonus * 3]
			if poison_buffed > 0:
				msg += " %d nearby allies gain +%d damage." % [poison_buffed, half_bonus]
			msg += "[/color]"
			combat_event.emit(msg)
			AudioManager.play("ability")
		"assassin_vanish":
			unit.evasion += 80.0
			unit.crit_chance += 100.0
			var vanish_buffed := 0
			for ally in board.get_units_on_team(unit.team):
				if ally.is_dead or ally == unit:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.evasion += 20.0
					vanish_buffed += 1
			var msg := "[color=%s]%s uses %s — +80%% evasion & guaranteed crit!" % [team_tag, u_name, ab_name]
			if vanish_buffed > 0:
				msg += " %d nearby allies gain +20%% evasion." % vanish_buffed
			msg += "[/color]"
			combat_event.emit(msg)
			AudioManager.play("ability")

		# ── Paladin ── (cleanses corrosive)
		"paladin_aegis":
			var allies := board.get_units_on_team(unit.team)
			var buffed := 0
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
				buffed += 1
				if ally.corrosive_dot > 0:
					ally.corrosive_dot = 0
					ally.restore_armor()
					ally._update_armor_bar()
					cleansed += 1
			var msg := "[color=%s]%s casts %s — +5 armor, +15%% armor power & +2 dmg to %d allies!" % [team_tag, u_name, ab_name, buffed]
			if cleansed > 0:
				msg += " Cleanses corrosive from %d!" % cleansed
			msg += "[/color]"
			combat_event.emit(msg)
			AudioManager.play("heal")
		"paladin_smite":
			var smite_target := board.find_nearest_enemy(unit)
			if smite_target and not smite_target.is_dead:
				var smite_dmg := int((unit.damage + unit.armor) * 2.0)
				var result := smite_target.take_damage(smite_dmg)
				var heal_amount := int(smite_dmg * 0.5)
				unit.current_hp = mini(unit.current_hp + heal_amount, unit.max_hp)
				unit.health_bar.value = unit.current_hp
				var t_name := smite_target.display_name if smite_target.display_name != "" else smite_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s for %d, heals %d![/color]" % [team_tag, u_name, ab_name, t_name, result.damage, heal_amount])
				if smite_target.is_dead:
					board.remove_unit(smite_target)
			AudioManager.play("ability")
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
						board.remove_unit(enemy)
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) <= unit.ability_range:
					ally.current_hp = mini(ally.current_hp + heal_amount, ally.max_hp)
					ally.health_bar.value = ally.current_hp
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
			AudioManager.play("heal")

		# ── Archer ──
		"archer_volley":
			var enemies := board.get_units_on_team(
				Unit.Team.ENEMY if unit.team == Unit.Team.PLAYER else Unit.Team.PLAYER
			)
			var volley_dmg := int(unit.damage * 0.4)
			var volley_hit := 0
			for enemy in enemies:
				if enemy.is_dead:
					continue
				if unit.position.distance_to(enemy.position) > unit.ability_range:
					continue
				enemy.take_damage(volley_dmg)
				volley_hit += 1
				if enemy.is_dead:
					board.remove_unit(enemy)
			combat_event.emit("[color=%s]%s fires %s — hits %d enemies for %d![/color]" % [team_tag, u_name, ab_name, volley_hit, volley_dmg])
			AudioManager.play("ability")
		"archer_pierce":
			var pierce_target := board.find_nearest_enemy(unit)
			if pierce_target and not pierce_target.is_dead:
				var pierce_dmg := int(unit.damage * 3.0)
				# Ignore armor: deal directly to HP
				pierce_target.current_hp -= pierce_dmg
				pierce_target.current_hp = maxi(pierce_target.current_hp, 0)
				pierce_target.health_bar.value = pierce_target.current_hp
				var t_name := pierce_target.display_name if pierce_target.display_name != "" else pierce_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s fires %s at %s for %d (ignores armor)![/color]" % [team_tag, u_name, ab_name, t_name, pierce_dmg])
				if pierce_target.current_hp <= 0:
					pierce_target.die()
					board.remove_unit(pierce_target)
			AudioManager.play("ability")
		"archer_mark":
			var mark_target := board.find_nearest_enemy(unit)
			if mark_target and not mark_target.is_dead:
				mark_target.crit_vulnerability += 30.0
				var t_name := mark_target.display_name if mark_target.display_name != "" else mark_target.unit_data.unit_name
				combat_event.emit("[color=%s]%s uses %s on %s — takes +30%% more damage![/color]" % [team_tag, u_name, ab_name, t_name])
			AudioManager.play("ability")

		# ── Summoner (abilities fire via mana, summoning via attack) ──
		"summoner_archer", "summoner_guardian", "summoner_familiar":
			# Summoner abilities are handled in the attack phase; mana trigger does nothing extra
			pass

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
