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
						summon_requested.emit(tank_data, unit.team, unit.position + offset, unit)
						combat_event.emit("[color=%s]%s summons a Guardian[/color]" % [team_tag, s_name])
					"summoner_familiar":
						summon_requested.emit(warlock_data, unit.team, unit.position + offset, unit)
						combat_event.emit("[color=%s]%s summons an Arcane Familiar[/color]" % [team_tag, s_name])
					_:
						summon_requested.emit(archer_data, unit.team, unit.position + offset, unit)
						combat_event.emit("[color=%s]%s summons an Archer[/color]" % [team_tag, s_name])
				AudioManager.play("summon")
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
	var a_name := attacker.display_name if attacker.display_name != "" else attacker.unit_data.unit_name
	var t_name := target.display_name if target.display_name != "" else target.unit_data.unit_name
	if result.evaded:
		combat_event.emit("[color=%s]%s evades %s[/color]" % [atk_tag, t_name, a_name])
		AudioManager.play("miss", -6.0)
	elif is_crit:
		combat_event.emit("[color=%s]%s CRITS %s for %d dmg![/color]" % [atk_tag, a_name, t_name, result.damage])
		AudioManager.play("crit")
	elif result.hit:
		combat_event.emit("[color=%s]%s hits %s for %d dmg[/color]" % [atk_tag, a_name, t_name, result.damage])
		AudioManager.play("hit", -8.0)

	if target.is_dead:
		combat_event.emit("[color=%s]%s kills %s[/color]" % [atk_tag, a_name, t_name])
		AudioManager.play("death")

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
	"Paladin": "slash",
}

func _trigger_ability(unit: Unit) -> void:
	var team_tag := "cyan" if unit.team == Unit.Team.PLAYER else "red"
	var u_name := unit.display_name if unit.display_name != "" else unit.unit_data.unit_name
	var ab_name := unit.instance_ability_name if unit.instance_ability_name != "" else unit.unit_data.ability_name

	match unit.ability_key:
		# ── Priest ──
		"priest_heal":
			var allies := board.get_units_on_team(unit.team)
			var heal_amount := int(unit.damage * 4.0)
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
		"priest_shield":
			var allies := board.get_units_on_team(unit.team)
			var weakest: Unit = null
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				if weakest == null or ally.current_hp < weakest.current_hp:
					weakest = ally
			if weakest:
				var shield_amount := int(weakest.max_hp * 0.5)
				weakest.armor += shield_amount
				weakest.max_armor = maxi(weakest.max_armor, weakest.armor)
				weakest._update_armor_bar()
				var t_name := weakest.display_name if weakest.display_name != "" else weakest.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s — +%d armor![/color]" % [team_tag, u_name, ab_name, t_name, shield_amount])
			AudioManager.play("heal")
		"priest_purify":
			var allies := board.get_units_on_team(unit.team)
			var weakest: Unit = null
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				if weakest == null or ally.current_hp < weakest.current_hp:
					weakest = ally
			if weakest:
				var heal_amount := int(unit.damage * 8.0)
				weakest.current_hp = mini(weakest.current_hp + heal_amount, weakest.max_hp)
				weakest.health_bar.value = weakest.current_hp
				weakest.crit_vulnerability = 0.0
				var t_name := weakest.display_name if weakest.display_name != "" else weakest.unit_data.unit_name
				combat_event.emit("[color=%s]%s casts %s on %s — heals %d & purifies![/color]" % [team_tag, u_name, ab_name, t_name, heal_amount])
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

		# ── Paladin ──
		"paladin_aegis":
			var allies := board.get_units_on_team(unit.team)
			var armor_restore := int(unit.damage * 3.0)
			var buffed := 0
			for ally in allies:
				if ally.is_dead:
					continue
				if unit.position.distance_to(ally.position) > unit.ability_range:
					continue
				ally.armor = mini(ally.armor + armor_restore, ally.max_armor)
				ally._update_armor_bar()
				ally.damage += 2
				buffed += 1
			combat_event.emit("[color=%s]%s casts %s — restores %d armor & +2 dmg to %d allies![/color]" % [team_tag, u_name, ab_name, armor_restore, buffed])
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
			combat_event.emit("[color=%s]%s casts %s — hits %d enemies for %d, heals nearby allies![/color]" % [team_tag, u_name, ab_name, hit_count, cons_dmg])
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
