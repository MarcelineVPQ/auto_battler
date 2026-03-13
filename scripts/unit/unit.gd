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

# Summoned: this unit was created during combat (not saved between rounds)
var is_summoned: bool = false

# Hellfire: Warlock AoE splash after abilities
var hellfire: bool = false

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
var armor_pen: float = 0.0  # percentage of armor ignored (0.0 - 1.0)
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
	# Class-based armor penetration
	match data.unit_class:
		"Archer": armor_pen = 0.20
		"Assassin": armor_pen = 0.30

func _ready() -> void:
	if unit_data:
		_update_visuals()

func _draw() -> void:
	if not unit_data:
		return

	var sprite_radius := 64.0 * sprite.scale.x
	var arc_segments := 48
	# Arcs sweep clockwise from 12 o'clock: start at -PI/2
	var start_angle := -PI / 2.0

	# Ring radii (inside → outside): mana, health, armor, team border
	var mana_r := sprite_radius + 2.0
	var mana_thick := 2.5
	var health_r := mana_r + mana_thick + 1.5
	var health_thick := 4.0
	var armor_r := health_r + health_thick + 1.5
	var armor_thick := 3.0
	var team_r := armor_r + armor_thick + 1.5
	var team_thick := 2.0

	# ── Mana ring (blue) ──
	if max_mana > 0:
		var mana_ratio := clampf(float(current_mana) / float(max_mana), 0.0, 1.0)
		# Dim background
		draw_arc(Vector2.ZERO, mana_r, 0, TAU, arc_segments, Color(0.1, 0.15, 0.4, 0.3), mana_thick)
		# Foreground arc
		if mana_ratio > 0.0:
			draw_arc(Vector2.ZERO, mana_r, start_angle, start_angle + TAU * mana_ratio, arc_segments, Color(0.3, 0.5, 1.0, 0.9), mana_thick)

	# ── Health ring (green→yellow→red) ──
	var hp_ratio := clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	# Dim background
	draw_arc(Vector2.ZERO, health_r, 0, TAU, arc_segments, Color(0.2, 0.08, 0.08, 0.3), health_thick)
	# Health color based on ratio
	var hp_color: Color
	if hp_ratio > 0.6:
		hp_color = Color(0.2, 0.85, 0.2, 0.95)
	elif hp_ratio > 0.3:
		var t := (hp_ratio - 0.3) / 0.3
		hp_color = Color(lerp(0.95, 0.2, t), lerp(0.8, 0.85, t), 0.2, 0.95)
	else:
		hp_color = Color(0.95, 0.2, 0.15, 0.95)
	if hp_ratio > 0.0:
		draw_arc(Vector2.ZERO, health_r, start_angle, start_angle + TAU * hp_ratio, arc_segments, hp_color, health_thick)

	# ── Armor ring (white/silver, only when armor > 0) ──
	if max_armor > 0 and armor > 0:
		var armor_ratio := clampf(float(armor) / float(max_armor), 0.0, 1.0)
		# Dim background
		draw_arc(Vector2.ZERO, armor_r, 0, TAU, arc_segments, Color(0.3, 0.3, 0.35, 0.25), armor_thick)
		# Foreground
		if armor_ratio > 0.0:
			draw_arc(Vector2.ZERO, armor_r, start_angle, start_angle + TAU * armor_ratio, arc_segments, Color(0.85, 0.85, 0.9, 0.85), armor_thick)

	# ── Team border ring (outermost) ──
	var team_color: Color
	if team == Team.PLAYER:
		team_color = Color(0.2, 0.5, 1.0, 0.6)
	else:
		team_color = Color(1.0, 0.2, 0.2, 0.6)
	# Adjust team ring radius if armor ring is hidden
	var actual_team_r := team_r
	if max_armor <= 0 or armor <= 0:
		actual_team_r = armor_r  # skip armor gap
	draw_arc(Vector2.ZERO, actual_team_r, 0, TAU, arc_segments, team_color, team_thick)

	# ── Name label (centered, white with black outline) ──
	var unit_name: String = display_name if display_name != "" else unit_data.unit_name
	var font := ThemeDB.fallback_font
	var name_font_size := 11
	var name_size := font.get_string_size(unit_name, HORIZONTAL_ALIGNMENT_CENTER, -1, name_font_size)
	var name_pos := Vector2(-name_size.x * 0.5, actual_team_r + team_thick + 12.0)
	# Black outline (draw offset in 4 directions)
	var outline_col := Color(0, 0, 0, 0.9)
	for ofs in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, name_pos + ofs, unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size, outline_col)
	# White text
	draw_string(font, name_pos, unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_font_size, Color(1, 1, 1, 1))

	# ── Status icons — small colored dots below the name ──
	var icons: Array[Dictionary] = []

	if poison_dot > 0:
		icons.append({"color": Color(0.2, 0.85, 0.2), "label": str(poison_dot)})
	if corrosive_dot > 0:
		icons.append({"color": Color(0.9, 0.75, 0.1), "label": str(corrosive_dot)})
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
		icons.append({"color": Color(1.0, 0.6, 0.15), "label": str(haymaker_counter)})
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
	var y_pos := name_pos.y + 10.0

	for i in range(icons.size()):
		var icon: Dictionary = icons[i]
		var cx := start_x + i * icon_spacing
		var center := Vector2(cx, y_pos)
		draw_circle(center, icon_radius, icon.color)
		draw_arc(center, icon_radius, 0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)
		if icon.label != "":
			var icon_fs := 8
			var text_size := font.get_string_size(icon.label, HORIZONTAL_ALIGNMENT_CENTER, -1, icon_fs)
			var text_pos := Vector2(cx - text_size.x * 0.5, y_pos + text_size.y * 0.25)
			draw_string(font, text_pos, icon.label, HORIZONTAL_ALIGNMENT_LEFT, -1, icon_fs, Color(0, 0, 0))

func _update_visuals() -> void:
	# Apply class-specific texture
	if unit_data.texture:
		sprite.texture = unit_data.texture
		sprite.modulate = Color.WHITE
	elif team == Team.PLAYER:
		sprite.modulate = Color(0.2, 0.5, 1.0)
	else:
		sprite.modulate = Color(1.0, 0.2, 0.2)

	# Scale grows with power (merges + stat purchases)
	update_scale()
	queue_redraw()

const PREMIUM_STATS: Array[String] = ["evasion", "crit_chance", "skill_proc_chance", "ability_cooldown"]

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
	queue_redraw()

func _update_armor_bar() -> void:
	queue_redraw()

func restore_armor() -> void:
	# Armor is permanent now — restore any temporary corrosive shred
	armor = max_armor

func _update_mana_bar() -> void:
	queue_redraw()

func take_damage(amount: int, pen: float = 0.0) -> Dictionary:
	var result := {"hit": true, "damage": 0, "crit": false, "evaded": false, "deflected": false}
	if is_dead:
		result.hit = false
		return result

	# Evasion roll (capped at 75% — attacks always have a chance to land)
	if randf() * 100.0 < minf(evasion, 75.0):
		result.hit = false
		result.evaded = true
		return result

	# Apply armor penetration — reduce effective armor
	var effective_armor := float(armor) * armor_effectiveness * (1.0 - clampf(pen, 0.0, 1.0))

	# Armor deflection roll — higher armor = higher chance to completely block
	if effective_armor > 0:
		var deflect_chance := effective_armor / (effective_armor + 150.0) * 40.0
		if randf() * 100.0 < deflect_chance:
			result.hit = false
			result.deflected = true
			return result

	# Armor damage reduction — percentage-based, armor never depletes
	var reduced := amount
	if effective_armor > 0:
		reduced = int(ceil(float(amount) * 40.0 / (40.0 + effective_armor)))
	result.damage = reduced
	current_hp -= reduced
	current_hp = maxi(current_hp, 0)
	queue_redraw()

	if current_hp <= 0:
		die()
	return result

func die() -> void:
	is_dead = true
	died.emit(self)
	var tween := create_tween()
	# Red flash before fade
	tween.tween_property(self, "modulate", Color(1.5, 0.2, 0.2, 1.0), 0.08)
	# Fade out + shrink
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2, 0.0), 0.5)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.5)
	tween.set_parallel(false)
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
