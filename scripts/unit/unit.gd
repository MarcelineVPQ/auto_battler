class_name Unit
extends Node2D

signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

var unit_data: UnitData
var team: Team = Team.PLAYER
var is_dead: bool = false
var xp: int = 0
var level: int = 1
const XP_TO_LEVEL: int = 4

# Per-instance identity and ability variant
var display_name: String = ""
var ability_key: String = ""
var instance_ability_name: String = ""
var instance_ability_desc: String = ""

# Tracks per-stat purchase count (for escalating cost)
var stat_purchases: Dictionary = {}  # stat_key -> int

# Tracks named upgrades applied from shop
var applied_upgrades: Array[Dictionary] = []

# Summoner-specific: necromancy stacks cause summoned archers to inherit stats
var necromancy_stacks: int = 0

# Primed: ability fires immediately at combat start
var primed: bool = false

# Runtime stats (copied from UnitData, can be upgraded)
var max_hp: int
var current_hp: int
var damage: int
var attacks_per_second: float
var attack_range: float
var ability_range: float
var move_speed: float
var armor: int
var max_armor: int
var evasion: float
var crit_chance: float
var crit_vulnerability: float = 0.0
var skill_proc_chance: float
var max_mana: int
var current_mana: int
var mana_cost_per_attack: int
var mana_regen_per_second: float
var hp_regen_per_second: float
var ability_cooldown: float

# Accumulated survival regen bonuses (earned from surviving battles)
var survival_hp_regen_bonus: float = 0.0
var survival_mana_regen_bonus: float = 0.0

# Timers
var attack_timer: float = 0.0
var ability_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var armor_bar: ProgressBar = $ArmorBar
@onready var mana_bar: ProgressBar = $ManaBar
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
	ability_range = data.ability_range
	move_speed = data.move_speed
	armor = data.armor
	max_armor = data.armor
	evasion = data.evasion
	crit_chance = data.crit_chance
	skill_proc_chance = data.skill_proc_chance
	max_mana = data.max_mana
	current_mana = 0
	mana_cost_per_attack = data.mana_cost_per_attack
	mana_regen_per_second = data.mana_regen_per_second
	hp_regen_per_second = data.hp_regen_per_second
	ability_cooldown = data.ability_cooldown

func _ready() -> void:
	if unit_data:
		_update_visuals()

func _draw() -> void:
	# Team-colored ring behind sprite
	var ring_color: Color
	if team == Team.PLAYER:
		ring_color = Color(0.2, 0.5, 1.0, 0.6)
	else:
		ring_color = Color(1.0, 0.2, 0.2, 0.6)
	draw_arc(Vector2.ZERO, 18, 0, TAU, 32, ring_color, 2.0)

func _update_visuals() -> void:
	# Apply class-specific texture
	if unit_data.texture:
		sprite.texture = unit_data.texture
		sprite.modulate = Color.WHITE
	elif team == Team.PLAYER:
		sprite.modulate = Color(0.2, 0.5, 1.0)
	else:
		sprite.modulate = Color(1.0, 0.2, 0.2)

	# Health bar
	health_bar.max_value = max_hp
	health_bar.value = current_hp

	# Mana bar
	_update_mana_bar()

	# Armor bar — visible only when armor > 0
	_update_armor_bar()

	# Name label
	name_label.text = display_name if display_name != "" else unit_data.unit_name

	# Scale grows with power (merges + stat purchases)
	update_scale()

const PREMIUM_STATS: Array[String] = ["evasion", "crit_chance", "skill_proc_chance"]

func get_stat_upgrade_cost(stat_key: String) -> int:
	var purchases: int = stat_purchases.get(stat_key, 0)
	if stat_key in PREMIUM_STATS:
		return 2 + int(float(purchases) / 4.0)
	return 1 + int(float(purchases) / 5.0)

func get_max_upgrades() -> int:
	return level + 1

func record_stat_purchase(stat_key: String) -> void:
	stat_purchases[stat_key] = stat_purchases.get(stat_key, 0) + 1
	update_scale()

func update_scale() -> void:
	# Base scale 0.22, grows slowly with level and purchases, capped at 0.45
	var base_s: float = 0.22 + (level - 1) * 0.03
	var total_purchases: int = 0
	for key in stat_purchases:
		total_purchases += stat_purchases[key]
	var s: float = clampf(base_s + total_purchases * 0.002, 0.22, 0.45)
	sprite.scale = Vector2(s, s)

func _update_armor_bar() -> void:
	if max_armor > 0:
		armor_bar.visible = true
		armor_bar.max_value = max_armor
		armor_bar.value = armor
	else:
		armor_bar.visible = false

func restore_armor() -> void:
	if max_armor > 0:
		armor = int(max_armor * 0.75)

func _update_mana_bar() -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = current_mana

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

	# Armor absorbs damage first, then remainder hits HP
	var remaining := amount
	if armor > 0:
		var absorbed := mini(armor, remaining)
		armor -= absorbed
		remaining -= absorbed
		_update_armor_bar()
	result.damage = amount
	current_hp -= remaining
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
