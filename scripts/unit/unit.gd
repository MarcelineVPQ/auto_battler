class_name Unit
extends Node2D

signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

var unit_data: UnitData
var team: Team = Team.PLAYER
var is_dead: bool = false
var merge_count: int = 0  # how many times this unit has been merged

# Tracks per-stat purchase count (for escalating cost)
var stat_purchases: Dictionary = {}  # stat_key -> int

# Tracks named upgrades applied from shop
var applied_upgrades: Array[Dictionary] = []

# Runtime stats (copied from UnitData, can be upgraded)
var max_hp: int
var current_hp: int
var damage: int
var attacks_per_second: float
var attack_range: float
var move_speed: float
var armor: int
var evasion: float
var crit_chance: float
var skill_proc_chance: float
var max_mana: int
var current_mana: int
var mana_cost_per_attack: int
var mana_regen_per_second: float
var ability_cooldown: float

# Timers
var attack_timer: float = 0.0
var ability_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

func setup(data: UnitData, t: Team, pos: Vector2) -> void:
	unit_data = data
	team = t
	position = pos
	# Copy stats from data template
	max_hp = data.max_hp
	current_hp = data.max_hp
	damage = data.damage
	attacks_per_second = data.attacks_per_second
	attack_range = data.attack_range
	move_speed = data.move_speed
	armor = data.armor
	evasion = data.evasion
	crit_chance = data.crit_chance
	skill_proc_chance = data.skill_proc_chance
	max_mana = data.max_mana
	current_mana = data.max_mana
	mana_cost_per_attack = data.mana_cost_per_attack
	mana_regen_per_second = data.mana_regen_per_second
	ability_cooldown = data.ability_cooldown

func _ready() -> void:
	if unit_data:
		_update_visuals()

func _update_visuals() -> void:
	# Team color
	if team == Team.PLAYER:
		sprite.modulate = Color(0.2, 0.5, 1.0)
	else:
		sprite.modulate = Color(1.0, 0.2, 0.2)

	# Health bar
	health_bar.max_value = max_hp
	health_bar.value = current_hp

	# Name label
	name_label.text = unit_data.unit_name

	# Scale grows with power (merges + stat purchases)
	update_scale()

func get_stat_upgrade_cost(stat_key: String) -> int:
	var purchases: int = stat_purchases.get(stat_key, 0)
	# Base cost 2, increases by 1 every 2 purchases
	return 2 + int(purchases / 2)

func record_stat_purchase(stat_key: String) -> void:
	stat_purchases[stat_key] = stat_purchases.get(stat_key, 0) + 1
	update_scale()

func update_scale() -> void:
	# Total "power" from merges and stat purchases
	var total_purchases: int = 0
	for key in stat_purchases:
		total_purchases += stat_purchases[key]
	var power: float = merge_count * 5.0 + total_purchases
	# Scale: base 0.4, grows by 0.02 per power point, max ~0.8
	var s: float = clampf(0.4 + power * 0.02, 0.4, 0.8)
	sprite.scale = Vector2(s, s)

func take_damage(amount: int) -> Dictionary:
	var result := {"hit": true, "damage": 0, "crit": false, "evaded": false}
	if is_dead:
		result.hit = false
		return result

	# Evasion roll
	if randf() * 100.0 < evasion:
		result.hit = false
		result.evaded = true
		return result

	# Apply armor reduction (can go negative if armor is negative)
	var final_damage := maxi(amount - armor, 1)
	result.damage = final_damage
	current_hp -= final_damage
	current_hp = maxi(current_hp, 0)
	health_bar.value = current_hp

	if current_hp <= 0:
		die()
	return result

func die() -> void:
	is_dead = true
	died.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func can_attack() -> bool:
	return attack_timer <= 0.0 and not is_dead

func reset_attack_cooldown() -> void:
	attack_timer = 1.0 / attacks_per_second

func roll_crit() -> bool:
	return randf() * 100.0 < crit_chance

func move_toward_target(target_pos: Vector2, distance: float) -> void:
	var direction := (target_pos - position).normalized()
	position += direction * distance
