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

# Thorns aura: slows nearby enemies
var thorns_slow: bool = false

# Vampirism: heal percentage of damage dealt
var lifesteal_pct: float = 0.0

# Last Stand: bonus when below 30% HP
var last_stand: bool = false
var last_stand_active: bool = false

# Relentless: on-kill power gain
var relentless: bool = false

# Sepsis: spread corrosive to nearby enemies on hit
var sepsis_spread: int = 0

# Living Shield: absorb damage, refreshes each combat
var living_shield_max: int = 0
var living_shield_hp: int = 0

# Invincible: ignore first N hits per combat
var invincible_charges: int = 0
var invincible_max: int = 0

# Haymaker: every Nth attack deals 3x
var haymaker_counter: int = 0

# Legion Master: bonus stats for summoned units
var legion_master: bool = false

# Corrosive: attack buff that applies stacking DoT to targets
var corrosive_power: int = 0  # damage applied per stack on hit
var corrosive_dot: int = 0    # active DoT stacks on this unit (from enemy attacks)

# Poison: pure HP damage over time (no armor shred)
var poison_power: int = 0     # poison stacks applied per hit
var poison_dot: int = 0       # active poison stacks on this unit

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
var armor_effectiveness: float = 1.0
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

	# Status icons — small colored dots below the name label
	var icons: Array[Dictionary] = []  # {color, label}

	# Debuffs (red-ish tones)
	if poison_dot > 0:
		icons.append({"color": Color(0.2, 0.85, 0.2), "label": str(poison_dot)})
	if corrosive_dot > 0:
		icons.append({"color": Color(0.9, 0.75, 0.1), "label": str(corrosive_dot)})

	# Buffs (blue/purple tones)
	if thorns_slow:
		icons.append({"color": Color(0.7, 0.3, 0.9), "label": ""})
	if lifesteal_pct > 0.0:
		icons.append({"color": Color(0.9, 0.15, 0.25), "label": ""})
	if last_stand:
		var col := Color(1.0, 0.5, 0.1) if last_stand_active else Color(0.6, 0.35, 0.1, 0.5)
		icons.append({"color": col, "label": ""})
	if relentless:
		icons.append({"color": Color(1.0, 0.85, 0.2), "label": ""})
	if living_shield_max > 0:
		icons.append({"color": Color(0.3, 0.6, 1.0), "label": str(living_shield_hp)})
	if invincible_max > 0:
		icons.append({"color": Color(1.0, 1.0, 1.0), "label": str(invincible_charges)})
	if haymaker_counter > 0:
		var remaining := haymaker_counter
		# Show how many attacks until haymaker fires (lower = closer)
		icons.append({"color": Color(1.0, 0.6, 0.15), "label": str(remaining)})
	if poison_power > 0:
		icons.append({"color": Color(0.1, 0.7, 0.3), "label": str(poison_power)})
	if corrosive_power > 0:
		icons.append({"color": Color(0.8, 0.65, 0.0), "label": str(corrosive_power)})
	if sepsis_spread > 0:
		icons.append({"color": Color(0.5, 0.8, 0.1), "label": ""})
	if primed:
		icons.append({"color": Color(0.2, 0.9, 0.9), "label": ""})

	if icons.is_empty():
		return

	var icon_radius := 5.0
	var icon_spacing := 14.0
	var total_width := (icons.size() - 1) * icon_spacing
	var start_x := -total_width * 0.5
	var y_pos := 42.0

	for i in range(icons.size()):
		var icon: Dictionary = icons[i]
		var cx := start_x + i * icon_spacing
		var center := Vector2(cx, y_pos)
		# Filled circle
		draw_circle(center, icon_radius, icon.color)
		# Dark outline
		draw_arc(center, icon_radius, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)
		# Stack count text
		if icon.label != "":
			var font := ThemeDB.fallback_font
			var font_size := 8
			var text_size := font.get_string_size(icon.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := Vector2(cx - text_size.x * 0.5, y_pos + text_size.y * 0.25)
			draw_string(font, text_pos, icon.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0))

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
	if armor > 0:
		armor_bar.visible = true
		armor_bar.max_value = armor
		armor_bar.value = armor
	else:
		armor_bar.visible = false

func restore_armor() -> void:
	# Armor is permanent now — restore any temporary corrosive shred
	armor = max_armor

func _update_mana_bar() -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = current_mana

func take_damage(amount: int) -> Dictionary:
	var result := {"hit": true, "damage": 0, "crit": false, "evaded": false, "deflected": false}
	if is_dead:
		result.hit = false
		return result

	# Evasion roll
	if randf() * 100.0 < evasion:
		result.hit = false
		result.evaded = true
		return result

	# Armor deflection roll — higher armor = higher chance to completely block
	var effective_armor := float(armor) * armor_effectiveness
	if effective_armor > 0:
		var deflect_chance := effective_armor / (effective_armor + 150.0) * 40.0
		if randf() * 100.0 < deflect_chance:
			result.hit = false
			result.deflected = true
			return result

	# Armor damage reduction — percentage-based, armor never depletes
	var reduced := amount
	if effective_armor > 0:
		reduced = int(ceil(float(amount) * 100.0 / (100.0 + effective_armor)))
	result.damage = reduced
	current_hp -= reduced
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
