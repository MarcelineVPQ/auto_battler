class_name CombatSystem
extends Node

signal combat_ended(player_won: bool)

const TICK_INTERVAL: float = 0.5

var board: Board
var is_fighting: bool = false
var tick_timer: float = 0.0

func setup(b: Board) -> void:
	board = b

func start_combat() -> void:
	is_fighting = true
	tick_timer = 0.0
	for unit in board.all_units:
		unit.attack_timer = 0.0
		unit.ability_timer = 0.0

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

		# Find target
		var target := board.find_nearest_enemy(unit)
		if target == null:
			continue

		var dist := unit.position.distance_to(target.position)

		if dist <= unit.attack_range:
			# In range — attack if ready
			if unit.can_attack():
				_attack(unit, target)
		else:
			# Out of range — move toward target
			unit.move_toward_target(target.position, unit.move_speed)

func _attack(attacker: Unit, target: Unit) -> void:
	attacker.reset_attack_cooldown()

	# Calculate damage with crit
	var atk_damage := attacker.damage
	var is_crit := attacker.roll_crit()
	if is_crit:
		atk_damage *= 2

	# Deal damage (armor/evasion handled inside target)
	var result := target.take_damage(atk_damage)

	# Visual feedback — attacker "punch" scale
	var tween := attacker.create_tween()
	tween.tween_property(attacker, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(attacker, "scale", Vector2(1.0, 1.0), 0.1)

	# Clean up dead target
	if target.is_dead:
		board.remove_unit(target)
