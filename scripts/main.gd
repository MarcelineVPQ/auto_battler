extends Node2D

@onready var board: Board = $Board
@onready var combat_system: CombatSystem = $CombatSystem
@onready var ready_button: Button = $UI/ReadyButton
@onready var result_label: Label = $UI/ResultLabel
@onready var round_label: Label = $UI/TopBar/RoundLabel
@onready var lives_label: Label = $UI/SidePanel/LivesLabel
@onready var gold_label: Label = $UI/SidePanel/GoldLabel
@onready var farms_label: Label = $UI/SidePanel/FarmsLabel
@onready var buy_farm_button: Button = $UI/SidePanel/BuyFarmButton
@onready var info_scroll: ScrollContainer = $UI/InfoScroll
@onready var info_panel: VBoxContainer = $UI/InfoScroll/InfoPanel
@onready var ui_layer: CanvasLayer = $UI

var unit_scene: PackedScene = preload("res://scenes/unit/unit.tscn")

# Buff icon textures keyed by stat
const BUFF_ICONS: Dictionary = {
	"damage": preload("res://assets/icons/buff_damage.svg"),
	"max_hp": preload("res://assets/icons/buff_hp.svg"),
	"armor": preload("res://assets/icons/buff_armor.svg"),
	"attacks_per_second": preload("res://assets/icons/buff_speed.svg"),
	"crit_chance": preload("res://assets/icons/buff_crit.svg"),
	"evasion": preload("res://assets/icons/buff_evasion.svg"),
	"attack_range": preload("res://assets/icons/buff_range.svg"),
	"move_speed": preload("res://assets/icons/buff_movespeed.svg"),
	"max_mana": preload("res://assets/icons/buff_mana.svg"),
	"skill_proc_chance": preload("res://assets/icons/buff_skill.svg"),
	"primed": preload("res://assets/icons/buff_primed.svg"),
	"_rare": preload("res://assets/icons/buff_rare.svg"),
	"_epic": preload("res://assets/icons/buff_epic.svg"),
}

# Class color palette for UI cards
const CLASS_COLORS: Dictionary = {
	"Grunt": Color(0.85, 0.45, 0.25),
	"Tank": Color(0.45, 0.55, 0.7),
	"Archer": Color(0.35, 0.75, 0.35),
	"Assassin": Color(0.65, 0.3, 0.7),
	"Warlock": Color(0.6, 0.25, 0.85),
	"Priest": Color(0.95, 0.9, 0.5),
	"Herbalist": Color(0.3, 0.8, 0.45),
	"Summoner": Color(0.3, 0.7, 0.85),
	"Paladin": Color(1.0, 0.8, 0.3),
	"SkeletonArcher": Color(0.36, 0.75, 0.92),
}

# Hero data pool
var hero_pool: Array[UnitData] = [
	preload("res://resources/units/warlock.tres"),
	preload("res://resources/units/priest.tres"),
	preload("res://resources/units/tank.tres"),
	preload("res://resources/units/herbalist.tres"),
	preload("res://resources/units/grunt.tres"),
	preload("res://resources/units/archer.tres"),
	preload("res://resources/units/assassin.tres"),
	preload("res://resources/units/summoner.tres"),
	preload("res://resources/units/paladin.tres"),
]

# Upgrade definitions
var upgrade_pool: Array[Dictionary] = [
	# ── Generic: Cheap (2-3g) ──
	{"name": "Corrosive", "cost": 2, "rarity": "Normal", "desc": "+2 corrosive DoT (armor then HP)", "stat": "corrosive", "amount": 2},
	{"name": "Exploit Weakness", "cost": 2, "rarity": "Normal", "desc": "+3 damage", "stat": "damage", "amount": 3},
	{"name": "Toughness", "cost": 2, "rarity": "Normal", "desc": "+20 max HP", "stat": "max_hp", "amount": 20},
	{"name": "Swift Strikes", "cost": 2, "rarity": "Normal", "desc": "+0.1 atk/s", "stat": "attacks_per_second", "amount": 0.1},
	{"name": "Iron Skin", "cost": 2, "rarity": "Normal", "desc": "+5 armor", "stat": "armor", "amount": 5},
	{"name": "Keen Edge", "cost": 2, "rarity": "Normal", "desc": "+2% crit", "stat": "crit_chance", "amount": 2.0},
	{"name": "Nimble", "cost": 2, "rarity": "Normal", "desc": "+3% evasion", "stat": "evasion", "amount": 3.0},
	{"name": "Quickstep", "cost": 3, "rarity": "Normal", "desc": "+5 move speed", "stat": "move_speed", "amount": 5.0},
	{"name": "Longshot", "cost": 3, "rarity": "Normal", "desc": "+30 atk range", "stat": "attack_range", "amount": 30.0},
	{"name": "Poison Tip", "cost": 3, "rarity": "Normal", "desc": "+1 corrosive power", "stat": "corrosive", "amount": 1},
	# ── Generic: Mid (4-6g) ──
	{"name": "Deadly Focus", "cost": 5, "rarity": "Normal", "desc": "+5% crit", "stat": "crit_chance", "amount": 5.0},
	{"name": "Bloodlust", "cost": 5, "rarity": "Normal", "desc": "+0.2 atk/s", "stat": "attacks_per_second", "amount": 0.2},
	{"name": "Giant Killer", "cost": 6, "rarity": "Normal", "desc": "+5 damage", "stat": "damage", "amount": 5},
	{"name": "Arcane Surge", "cost": 4, "rarity": "Normal", "desc": "+3 max mana", "stat": "max_mana", "amount": 3},
	{"name": "Primed", "cost": 5, "rarity": "Normal", "desc": "Ability ready at battle start", "stat": "primed", "amount": 1.0},
	{"name": "Living Shield", "cost": 6, "rarity": "Normal", "desc": "Absorb first 30 dmg each combat", "stat": "living_shield", "amount": 30},
	# ── Generic: Expensive (8-10g) ──
	{"name": "Sepsis", "cost": 8, "rarity": "Normal", "desc": "Attacks spread 2 corrosive to nearby enemies", "stat": "sepsis", "amount": 2},
	{"name": "Thorns", "cost": 8, "rarity": "Normal", "desc": "Aura: enemies within 120px move at -50% speed", "stat": "thorns_slow", "amount": 1.0},
	{"name": "Vampirism", "cost": 8, "rarity": "Normal", "desc": "Heal 25% of damage dealt", "stat": "lifesteal", "amount": 0.25},
	{"name": "Berserk", "cost": 10, "rarity": "Normal", "desc": "-30% max HP, +6 dmg, +0.4 atk/s", "stat": "berserk", "amount": 1.0},
	{"name": "Last Stand", "cost": 10, "rarity": "Normal", "desc": "Below 30% HP: +12 dmg, +0.4 atk/s, +15% evasion", "stat": "last_stand", "amount": 1.0},
	{"name": "Relentless", "cost": 10, "rarity": "Normal", "desc": "On kill: +2 dmg, +0.1 atk/s permanently", "stat": "relentless", "amount": 1.0},
	# ── Generic: Rare (15g, round 6+) ──
	{"name": "Invincible", "cost": 15, "rarity": "Rare", "desc": "Immune to first 3 hits per combat, +5% evasion", "stat": "invincible", "amount": 3},
	{"name": "Haymaker", "cost": 15, "rarity": "Rare", "desc": "Every 4th attack deals 3x damage", "stat": "haymaker", "amount": 4},
	# ── Normal Hero-Specific (5g, always available) ──
	{"name": "War Paint", "cost": 5, "rarity": "Normal", "desc": "+3 dmg, +10 HP", "stat": "war_paint", "amount": 1.0, "class_req": "Grunt"},
	{"name": "Venom Arrow", "cost": 5, "rarity": "Normal", "desc": "+2 poison/hit (stacks, HP dmg/tick)", "stat": "venom_arrow", "amount": 2, "class_req": "Archer"},
	{"name": "Shadow Cloak", "cost": 5, "rarity": "Normal", "desc": "+5% evasion, +3% crit", "stat": "shadow_cloak", "amount": 1.0, "class_req": "Assassin"},
	{"name": "Thick Plate", "cost": 5, "rarity": "Normal", "desc": "+10 armor, +15 HP", "stat": "thick_plate", "amount": 1.0, "class_req": "Tank"},
	{"name": "Dark Sigil", "cost": 5, "rarity": "Normal", "desc": "+3 dmg, +2 max mana", "stat": "dark_sigil", "amount": 1.0, "class_req": "Warlock"},
	{"name": "Sacred Blessing", "cost": 5, "rarity": "Normal", "desc": "+15 HP, +2 max mana", "stat": "sacred_blessing", "amount": 1.0, "class_req": "Priest"},
	{"name": "Herbal Brew", "cost": 5, "rarity": "Normal", "desc": "+3 dmg, +3% skill proc", "stat": "herbal_brew", "amount": 1.0, "class_req": "Herbalist"},
	{"name": "Shield of Faith", "cost": 5, "rarity": "Normal", "desc": "+8 armor, +10% armor effectiveness", "stat": "shield_of_faith", "amount": 1.0, "class_req": "Paladin"},
	{"name": "Soul Binding", "cost": 5, "rarity": "Normal", "desc": "+1 necromancy stack, +10 HP", "stat": "soul_binding", "amount": 1.0, "class_req": "Summoner"},
	# ── Rare Hero-Specific (12g, round 6+) ──
	{"name": "Blood Rage", "cost": 12, "rarity": "Rare", "desc": "+5 dmg, +0.2 atk/s", "stat": "blood_rage", "amount": 1.0, "class_req": "Grunt"},
	{"name": "Deadeye", "cost": 12, "rarity": "Rare", "desc": "+8 dmg, +80 range", "stat": "deadeye", "amount": 1.0, "class_req": "Archer"},
	{"name": "Phantom Step", "cost": 12, "rarity": "Rare", "desc": "+10% evade, +10% crit", "stat": "phantom_step", "amount": 1.0, "class_req": "Assassin"},
	{"name": "Fortress", "cost": 12, "rarity": "Rare", "desc": "+25 armor, +40 HP", "stat": "fortress", "amount": 1.0, "class_req": "Tank"},
	{"name": "Soul Rend", "cost": 12, "rarity": "Rare", "desc": "+8 dmg, +3 max mana", "stat": "soul_rend", "amount": 1.0, "class_req": "Warlock"},
	{"name": "Divine Covenant", "cost": 12, "rarity": "Rare", "desc": "+30 HP, +3 max mana", "stat": "divine_covenant", "amount": 1.0, "class_req": "Priest"},
	{"name": "Toxic Mastery", "cost": 12, "rarity": "Rare", "desc": "+5 dmg, +5% skill proc", "stat": "toxic_mastery", "amount": 1.0, "class_req": "Herbalist"},
	{"name": "Holy Vanguard", "cost": 12, "rarity": "Rare", "desc": "+15 armor, +25% armor power, +3 dmg", "stat": "holy_vanguard", "amount": 1.0, "class_req": "Paladin"},
	{"name": "Necromancy", "cost": 12, "rarity": "Rare", "desc": "Archers inherit 15% stats (max 3)", "stat": "necromancy", "amount": 1.0, "class_req": "Summoner"},
	# ── Epic Hero-Specific (18g, round 11+) ──
	{"name": "Rampage", "cost": 18, "rarity": "Epic", "desc": "+10 dmg, +0.3 atk/s, +20 HP", "stat": "rampage", "amount": 1.0, "class_req": "Grunt"},
	{"name": "Hawkeye", "cost": 18, "rarity": "Epic", "desc": "+12 dmg, +120 range, +8% crit", "stat": "hawkeye", "amount": 1.0, "class_req": "Archer"},
	{"name": "Death's Embrace", "cost": 18, "rarity": "Epic", "desc": "+15% evade, +15% crit, +5 dmg", "stat": "deaths_embrace", "amount": 1.0, "class_req": "Assassin"},
	{"name": "Bastion", "cost": 18, "rarity": "Epic", "desc": "+40 armor, +60 HP, +2 dmg", "stat": "bastion", "amount": 1.0, "class_req": "Tank"},
	{"name": "Dark Pact", "cost": 18, "rarity": "Epic", "desc": "+15 dmg, +5 max mana", "stat": "dark_pact", "amount": 1.0, "class_req": "Warlock"},
	{"name": "Ascension", "cost": 18, "rarity": "Epic", "desc": "+50 HP, +5 max mana, +5 dmg", "stat": "ascension", "amount": 1.0, "class_req": "Priest"},
	{"name": "Plague Lord", "cost": 18, "rarity": "Epic", "desc": "+10 dmg, +8% skill proc, +15 armor", "stat": "plague_lord", "amount": 1.0, "class_req": "Herbalist"},
	{"name": "Divine Bulwark", "cost": 18, "rarity": "Epic", "desc": "+25 armor, +50% armor power, +40 HP, +5 dmg", "stat": "divine_bulwark", "amount": 1.0, "class_req": "Paladin"},
	{"name": "Legion Master", "cost": 18, "rarity": "Epic", "desc": "+2 necromancy, summoned units +5 dmg, +30 HP", "stat": "legion_master", "amount": 1.0, "class_req": "Summoner"},
]

# Wave strategy definitions — each describes the enemy team composition
# "weights" map unit_class to relative pick chance; "label" describes the mix
var wave_strategies: Array[Dictionary] = [
	{"label": "Frontline Defense", "strategy": "concentrated",
	 "weights": {"Tank": 5, "Priest": 2, "Warlock": 1, "Herbalist": 1, "Grunt": 3, "Archer": 0, "Assassin": 0, "Summoner": 0, "Paladin": 2}},
	{"label": "Glass Cannon", "strategy": "spread",
	 "weights": {"Tank": 0, "Priest": 1, "Warlock": 4, "Herbalist": 4, "Grunt": 0, "Archer": 3, "Assassin": 2, "Summoner": 1, "Paladin": 0}},
	{"label": "Arcane Assault", "strategy": "concentrated",
	 "weights": {"Tank": 1, "Priest": 1, "Warlock": 5, "Herbalist": 2, "Grunt": 1, "Archer": 2, "Assassin": 0, "Summoner": 2, "Paladin": 1}},
	{"label": "Holy Guard", "strategy": "many",
	 "weights": {"Tank": 3, "Priest": 5, "Warlock": 1, "Herbalist": 1, "Grunt": 2, "Archer": 0, "Assassin": 0, "Summoner": 1, "Paladin": 3}},
	{"label": "Poison Swarm", "strategy": "many",
	 "weights": {"Tank": 1, "Priest": 1, "Warlock": 1, "Herbalist": 5, "Grunt": 1, "Archer": 1, "Assassin": 1, "Summoner": 0, "Paladin": 1}},
	{"label": "Balanced Army", "strategy": "spread",
	 "weights": {"Tank": 3, "Priest": 3, "Warlock": 3, "Herbalist": 3, "Grunt": 3, "Archer": 3, "Assassin": 3, "Summoner": 1, "Paladin": 3}},
	{"label": "Blitz Rush", "strategy": "concentrated",
	 "weights": {"Tank": 0, "Priest": 1, "Warlock": 0, "Herbalist": 1, "Grunt": 5, "Archer": 1, "Assassin": 4, "Summoner": 0, "Paladin": 1}},
	{"label": "Sniper Nest", "strategy": "spread",
	 "weights": {"Tank": 2, "Priest": 1, "Warlock": 1, "Herbalist": 1, "Grunt": 1, "Archer": 5, "Assassin": 1, "Summoner": 1, "Paladin": 1}},
]

# Squad persistence — saves runtime stats between rounds
var player_squad: Array = []

# Shop state
var shop_slots: Array = []
const HERO_SHOP_SLOTS: int = 2
const UPGRADE_SHOP_SLOTS: int = 4

# Drag state
var dragging_unit: Unit = null
var drag_offset: Vector2 = Vector2.ZERO

# Wave select UI (built in code)
var wave_overlay: ColorRect
var wave_panel: PanelContainer
var wave_title: Label
var wave_dps_label: Label
var wave_cards_container: HBoxContainer
var wave_options: Array[Dictionary] = []
var _pending_bonus_gold: int = 0

# Shop UI (built in code)
var shop_bar: HBoxContainer
var shop_buttons: Array[Button] = []
var reroll_button: Button
var freeze_button: Button
var sell_button: Button
var action_bar: HBoxContainer

# Shop freeze state
var shop_frozen: bool = false

# Upgrade targeting state
var _targeting_upgrade: bool = false
var _pending_upgrade_slot: int = -1

# Shop confirmation state
var _selected_shop_slot: int = -1
var _shift_held_on_select: bool = false
var shop_confirm_bar: HBoxContainer
var buy_button: Button
var cancel_button: Button

# Currently shown info unit (for refreshing)
var _info_unit: Unit = null

# Warning feedback label
var warning_label: Label

# Battle UI — strength bar, DPS panel & combat log
var strength_bar_container: HBoxContainer
var strength_bar_player: ColorRect
var strength_bar_enemy: ColorRect
var dps_panel: HBoxContainer
var dps_player_label: Label
var dps_enemy_label: Label
var combat_log_scroll: ScrollContainer
var combat_log: RichTextLabel

func _ready() -> void:
	combat_system.setup(board)
	combat_system.combat_ended.connect(_on_combat_ended)
	combat_system.summon_requested.connect(_on_summon_requested)
	ready_button.pressed.connect(_on_ready_pressed)
	buy_farm_button.pressed.connect(_on_buy_farm_pressed)

	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.gold_changed.connect(func(_g): _update_ui())
	GameManager.lives_changed.connect(func(_l): _update_ui())
	GameManager.game_over.connect(_on_game_over)

	_build_warning_label()
	_build_wave_select_ui()
	_build_shop_bar()
	_build_battle_ui()
	_hide_info_panel()
	_hide_shop()

	combat_system.combat_event.connect(_on_combat_event)
	combat_system.tick_completed.connect(_on_tick_completed)

	GameManager.advance_round()

# ── Warning Label ──────────────────────────────────────────

func _build_warning_label() -> void:
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 18)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	warning_label.position = Vector2(380, 495)
	warning_label.size = Vector2(300, 30)
	warning_label.visible = false
	ui_layer.add_child(warning_label)

func _show_warning(text: String) -> void:
	warning_label.text = text
	warning_label.modulate = Color(1, 1, 1, 1)
	warning_label.visible = true
	AudioManager.play("warning", -4.0)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(warning_label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(func(): warning_label.visible = false)

# ── Battle UI (Strength Bar + Combat Log) ──────────────────

func _build_battle_ui() -> void:
	# Strength bar — tug-of-war HP bar below TopBar
	strength_bar_container = HBoxContainer.new()
	strength_bar_container.position = Vector2(55, 42)
	strength_bar_container.custom_minimum_size = Vector2(960, 8)
	strength_bar_container.add_theme_constant_override("separation", 0)
	ui_layer.add_child(strength_bar_container)

	strength_bar_player = ColorRect.new()
	strength_bar_player.color = Color(0.2, 0.4, 1.0)
	strength_bar_player.custom_minimum_size = Vector2(480, 8)
	strength_bar_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_bar_container.add_child(strength_bar_player)

	strength_bar_enemy = ColorRect.new()
	strength_bar_enemy.color = Color(1.0, 0.2, 0.2)
	strength_bar_enemy.custom_minimum_size = Vector2(480, 8)
	strength_bar_enemy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_bar_container.add_child(strength_bar_enemy)

	strength_bar_container.visible = false

	# DPS panel — live team DPS readout below strength bar
	dps_panel = HBoxContainer.new()
	dps_panel.position = Vector2(55, 52)
	dps_panel.custom_minimum_size = Vector2(900, 20)
	dps_panel.add_theme_constant_override("separation", 0)
	dps_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(dps_panel)

	dps_player_label = Label.new()
	dps_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dps_player_label.add_theme_font_size_override("font_size", 12)
	dps_player_label.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0))
	dps_player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps_player_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dps_panel.add_child(dps_player_label)

	dps_enemy_label = Label.new()
	dps_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dps_enemy_label.add_theme_font_size_override("font_size", 12)
	dps_enemy_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	dps_enemy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dps_enemy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dps_panel.add_child(dps_enemy_label)

	dps_panel.visible = false

	# Combat log — scrolling text at bottom-right
	combat_log_scroll = ScrollContainer.new()
	combat_log_scroll.position = Vector2(970, 440)
	combat_log_scroll.custom_minimum_size = Vector2(250, 160)
	combat_log_scroll.size = Vector2(250, 160)
	ui_layer.add_child(combat_log_scroll)

	combat_log = RichTextLabel.new()
	combat_log.bbcode_enabled = true
	combat_log.fit_content = true
	combat_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_log.custom_minimum_size = Vector2(250, 0)
	combat_log.scroll_active = false
	combat_log.add_theme_font_size_override("normal_font_size", 10)
	combat_log_scroll.add_child(combat_log)

	combat_log_scroll.visible = false

func _on_combat_event(text: String) -> void:
	combat_log.append_text(text + "\n")
	# Auto-scroll to bottom
	await get_tree().process_frame
	combat_log_scroll.scroll_vertical = int(combat_log_scroll.get_v_scroll_bar().max_value)

func _on_tick_completed() -> void:
	var player_hp := 0
	var player_dps := 0.0
	var enemy_hp := 0
	var enemy_dps := 0.0
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		player_hp += unit.current_hp
		player_dps += unit.damage * unit.attacks_per_second
	for unit in board.get_units_on_team(Unit.Team.ENEMY):
		enemy_hp += unit.current_hp
		enemy_dps += unit.damage * unit.attacks_per_second

	var total := player_hp + enemy_hp
	if total <= 0:
		return
	var ratio: float = float(player_hp) / float(total)
	var bar_width: float = Board.ARENA_WIDTH
	strength_bar_player.custom_minimum_size.x = bar_width * ratio
	strength_bar_enemy.custom_minimum_size.x = bar_width * (1.0 - ratio)

	dps_player_label.text = "Your DPS: %.1f" % player_dps
	dps_enemy_label.text = "Enemy DPS: %.1f" % enemy_dps

	# Refresh info panel during combat so debuff stacks update live
	if _info_unit and is_instance_valid(_info_unit) and not _info_unit.is_dead:
		_show_info_panel(_info_unit)

func _show_battle_ui() -> void:
	strength_bar_container.visible = true
	dps_panel.visible = true
	combat_log_scroll.visible = true

func _hide_battle_ui() -> void:
	strength_bar_container.visible = false
	dps_panel.visible = false
	combat_log_scroll.visible = false

# ── Wave Select UI ──────────────────────────────────────────

func _build_wave_select_ui() -> void:
	wave_overlay = ColorRect.new()
	wave_overlay.color = Color(0, 0, 0, 0.65)
	wave_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wave_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(wave_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 40
	center.offset_bottom = -40
	wave_overlay.add_child(center)

	wave_panel = PanelContainer.new()
	wave_panel.custom_minimum_size = Vector2(780, 0)
	wave_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.6, 0.6, 0.7, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(10)
	wave_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(wave_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	wave_panel.add_child(vbox)

	wave_title = Label.new()
	wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(wave_title)

	wave_dps_label = Label.new()
	wave_dps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_dps_label.add_theme_font_size_override("font_size", 12)
	wave_dps_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(wave_dps_label)

	wave_cards_container = HBoxContainer.new()
	wave_cards_container.add_theme_constant_override("separation", 10)
	wave_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(wave_cards_container)

	wave_overlay.visible = false

func _show_wave_select() -> void:
	wave_options = _generate_wave_options()
	var title := "Round %d/%d" % [GameManager.current_round, GameManager.MAX_ROUNDS]
	if GameManager.current_round % 5 == 0:
		title += "  —  +1 Life!"
	wave_title.text = title
	wave_dps_label.text = "Your Squad DPS: %.1f" % _get_squad_dps()
	_populate_wave_cards()
	wave_overlay.visible = true
	if GameManager.current_round % 5 == 0:
		_show_warning("+1 Life gained!")
		AudioManager.play("victory")

func _show_wave_select_rematch() -> void:
	wave_title.text = "Round %d/%d — Rematch" % [GameManager.current_round, GameManager.MAX_ROUNDS]
	wave_dps_label.text = "Your Squad DPS: %.1f" % _get_squad_dps()
	_populate_wave_cards()
	wave_overlay.visible = true

func _get_squad_dps() -> float:
	var total := 0.0
	for entry in player_squad:
		if entry.has("stats"):
			var s: Dictionary = entry.stats
			total += s.get("damage", 0) * s.get("attacks_per_second", 0.5)
	return total

func _populate_wave_cards() -> void:
	for child in wave_cards_container.get_children():
		child.queue_free()

	for i in range(3):
		var wave: Dictionary = wave_options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 280)
		btn.clip_contents = true

		# Margin wrapper so the card content sizes the button
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 8)
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL

		# Gold bonus banner (3rd card) — all cards reserve the same row height
		var bonus_gold: int = wave.get("bonus_gold", 0)
		if bonus_gold > 0:
			var banner := Label.new()
			banner.text = "+%dg BONUS" % bonus_gold
			banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			banner.add_theme_font_size_override("font_size", 11)
			banner.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var banner_bg := PanelContainer.new()
			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(1.0, 0.82, 0.3)
			bg_style.set_corner_radius_all(3)
			bg_style.set_content_margin_all(2)
			banner_bg.add_theme_stylebox_override("panel", bg_style)
			banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			banner_bg.add_child(banner)
			card.add_child(banner_bg)
		else:
			# Dark grey bar matching the gold banner size so everything aligns
			var spacer_label := Label.new()
			spacer_label.text = " "
			spacer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			spacer_label.add_theme_font_size_override("font_size", 11)
			spacer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var spacer_bg := PanelContainer.new()
			var sp_style := StyleBoxFlat.new()
			sp_style.bg_color = Color(0.12, 0.12, 0.15)
			sp_style.set_corner_radius_all(3)
			sp_style.set_content_margin_all(2)
			spacer_bg.add_theme_stylebox_override("panel", sp_style)
			spacer_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spacer_bg.add_child(spacer_label)
			card.add_child(spacer_bg)

		# Strategy title
		var title := Label.new()
		title.text = wave.name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 13)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(title)

		# Icon row — one icon per unique enemy class in the wave
		var icon_row := HBoxContainer.new()
		icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
		icon_row.add_theme_constant_override("separation", 4)
		icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var seen_classes: Dictionary = {}
		for entry in wave.enemies:
			var data: UnitData = entry.data
			if seen_classes.has(data.unit_class):
				continue
			seen_classes[data.unit_class] = true
			if data.texture:
				var tex := TextureRect.new()
				tex.texture = data.texture
				tex.custom_minimum_size = Vector2(22, 22)
				tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				tex.modulate = CLASS_COLORS.get(data.unit_class, Color.WHITE)
				tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_row.add_child(tex)
		card.add_child(icon_row)

		# Enemy composition text (scrollable when list is long)
		var comp := Label.new()
		comp.text = wave.enemy_text
		comp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		comp.add_theme_font_size_override("font_size", 11)
		comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		comp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var comp_scroll := ScrollContainer.new()
		comp_scroll.custom_minimum_size = Vector2(0, 0)
		comp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		comp_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		comp_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		comp_scroll.add_child(comp)
		card.add_child(comp_scroll)

		# Enemy buffs — compute max level in the wave and show scaling
		var max_lvl := 1
		for entry in wave.enemies:
			var lvl: int = entry.get("level", 1)
			if lvl > max_lvl:
				max_lvl = lvl
		if max_lvl > 1:
			var dmg_pct := int((max_lvl - 1) * 45)
			var spd_pct := int((max_lvl - 1) * 18)
			var buffs := Label.new()
			buffs.text = "Buffs: +%d%% DMG/HP, +%d%% ATK spd" % [dmg_pct, spd_pct]
			buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			buffs.add_theme_font_size_override("font_size", 10)
			buffs.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
			buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(buffs)

		# Combined DPS stat
		var total_dps := 0.0
		for entry in wave.enemies:
			var data: UnitData = entry.data
			var lvl: int = entry.get("level", 1)
			var dmg := float(data.damage)
			var aps := data.attacks_per_second
			if lvl > 1:
				dmg *= 1.0 + (lvl - 1) * 0.45
				aps *= 1.0 + (lvl - 1) * 0.18
			total_dps += dmg * aps
		var dps_label := Label.new()
		dps_label.text = "DPS: %.1f" % total_dps
		dps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dps_label.add_theme_font_size_override("font_size", 10)
		dps_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		dps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(dps_label)

		# Summary line
		var summary := Label.new()
		summary.text = "%d units (%d farms) — %s" % [wave.total_units, wave.total_farms, wave.strategy]
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary.add_theme_font_size_override("font_size", 10)
		summary.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(summary)

		margin.add_child(card)
		btn.add_child(margin)
		var idx := i
		btn.pressed.connect(func(): _on_wave_selected(idx))
		wave_cards_container.add_child(btn)

func _hide_wave_select() -> void:
	wave_overlay.visible = false

func _generate_wave_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for i in range(2):
		options.append(_generate_single_wave(0))
	# 3rd option is always the hardest — extra budget + bonus gold reward
	options.append(_generate_single_wave(2 + GameManager.current_round / 2))
	var bonus := 5 + randi_range(0, GameManager.current_round)
	options[2].bonus_gold = bonus
	# Sort first two by DPS so easiest is first, medium second
	if _wave_dps(options[0]) > _wave_dps(options[1]):
		var tmp := options[0]
		options[0] = options[1]
		options[1] = tmp
	return options

func _wave_dps(wave: Dictionary) -> float:
	var total := 0.0
	for entry in wave.enemies:
		var data: UnitData = entry.data
		var lvl: int = entry.get("level", 1)
		var dmg := float(data.damage)
		var aps := data.attacks_per_second
		if lvl > 1:
			dmg *= 1.0 + (lvl - 1) * 0.45
			aps *= 1.0 + (lvl - 1) * 0.18
		total += dmg * aps
	return total

func _generate_single_wave(extra_budget: int = 0) -> Dictionary:
	var round_num := GameManager.current_round
	# Farm budget: base + round scaling + variance + optional extra for hard waves
	var enemy_farm_budget := round_num + 1 + randi_range(0, maxi(round_num / 3, 1)) + extra_budget

	# Enemy level scales with rounds (faster progression, higher cap)
	var base_level := clampi(ceili(round_num / 2.0), 1, 10)

	# Pick a strategy and build composition from its weights
	var strat: Dictionary = wave_strategies.pick_random()
	var weighted_pool: Array[UnitData] = _build_weighted_pool(strat.weights)

	var enemies: Array[Dictionary] = []
	var budget_used := 0
	var max_attempts := 50
	var attempts := 0
	# Group enemies by class+level for display
	var counts: Dictionary = {}
	while budget_used < enemy_farm_budget and attempts < max_attempts:
		var data: UnitData = weighted_pool.pick_random()
		if budget_used + data.pop_cost <= enemy_farm_budget:
			var lvl := clampi(base_level + randi_range(-1, 1), 1, 10)
			enemies.append({"data": data, "level": lvl})
			budget_used += data.pop_cost
			var key := "%s Lv%d" % [data.unit_class, lvl]
			counts[key] = counts.get(key, 0) + 1
		attempts += 1

	var enemy_text := ""
	for key in counts:
		enemy_text += "%dx %s\n" % [counts[key], key]

	return {
		"name": strat.label,
		"strategy": strat.strategy,
		"enemies": enemies,
		"total_units": enemies.size(),
		"total_farms": budget_used,
		"enemy_text": enemy_text.strip_edges(),
	}

func _build_weighted_pool(weights: Dictionary) -> Array[UnitData]:
	var pool: Array[UnitData] = []
	for data in hero_pool:
		var w: int = weights.get(data.unit_class, 1)
		w = _apply_round_weight(w, data.pop_cost)
		for i in range(w):
			pool.append(data)
	return pool

# Bias toward cheap units early; expensive ones become common later
func _apply_round_weight(base_weight: int, pop_cost: int) -> int:
	var round_num := GameManager.current_round
	if pop_cost <= 1:
		# Cheap units: bonus weight early, fades by round 8
		return base_weight + maxi(4 - round_num / 2, 0)
	elif pop_cost == 2:
		# Medium units: small bonus early
		return base_weight + maxi(2 - round_num / 3, 0)
	else:
		# Expensive units (3-4): reduced early, full weight by round 6+
		if round_num < 3:
			return maxi(base_weight / 3, 1) if base_weight > 0 else 0
		elif round_num < 6:
			return maxi(base_weight / 2, 1) if base_weight > 0 else 0
		return base_weight

func _on_wave_selected(idx: int) -> void:
	var wave: Dictionary = wave_options[idx]
	_pending_bonus_gold = wave.get("bonus_gold", 0)
	_hide_wave_select()

	var enemies: Array = wave.enemies
	var enemy_count: int = enemies.size()
	for i in range(enemy_count):
		var entry: Dictionary = enemies[i]
		var spacing: float = Board.ARENA_HEIGHT / (enemy_count + 1)
		var raw_pos := Vector2(
			randf_range(Board.DIVIDER_X + 60, Board.ARENA_WIDTH - 60),
			spacing * (i + 1)
		)
		var pos := board.snap_to_enemy_grid(raw_pos)
		var unit := _spawn_unit(entry.data, Unit.Team.ENEMY, pos)
		# Apply level scaling: each level above 1 boosts stats
		var lvl: int = entry.get("level", 1)
		if lvl > 1:
			var scale_factor := 1.0 + (lvl - 1) * 0.45
			unit.damage = int(ceil(unit.damage * scale_factor))
			unit.max_hp = int(ceil(unit.max_hp * scale_factor))
			unit.current_hp = unit.max_hp
			unit.armor = int(ceil(unit.armor * scale_factor)) if unit.armor > 0 else 0
			unit.attacks_per_second *= 1.0 + (lvl - 1) * 0.18
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp

	_restore_squad()
	if shop_frozen:
		shop_frozen = false
	else:
		_roll_shop()
	_show_shop()
	GameManager.change_phase(GameManager.Phase.PREP)
	_update_ui()

# ── Shop Bar ────────────────────────────────────────────────

func _build_shop_bar() -> void:
	shop_bar = HBoxContainer.new()
	shop_bar.position = Vector2(30, 520)
	shop_bar.add_theme_constant_override("separation", 5)
	ui_layer.add_child(shop_bar)

	for i in range(HERO_SHOP_SLOTS + UPGRADE_SHOP_SLOTS):
		var btn := Button.new()
		if i < HERO_SHOP_SLOTS:
			btn.custom_minimum_size = Vector2(130, 80)
		else:
			btn.custom_minimum_size = Vector2(120, 80)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_constant_override("icon_max_width", 28)
		var idx := i
		btn.pressed.connect(func(): _on_shop_card_pressed(idx))
		shop_bar.add_child(btn)
		shop_buttons.append(btn)

	# Insert separator after hero cards
	var sep := VSeparator.new()
	shop_bar.add_child(sep)
	shop_bar.move_child(sep, HERO_SHOP_SLOTS)

	# Action buttons — row above Ready button
	action_bar = HBoxContainer.new()
	action_bar.position = Vector2(1010, 610)
	action_bar.add_theme_constant_override("separation", 5)
	ui_layer.add_child(action_bar)

	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(80, 24)
	reroll_button.add_theme_font_size_override("font_size", 11)
	reroll_button.text = "Re-roll (%dg)" % GameManager.REROLL_COST
	reroll_button.pressed.connect(_on_reroll_pressed)
	action_bar.add_child(reroll_button)

	freeze_button = Button.new()
	freeze_button.custom_minimum_size = Vector2(60, 24)
	freeze_button.add_theme_font_size_override("font_size", 11)
	freeze_button.text = "Freeze"
	freeze_button.pressed.connect(_on_freeze_pressed)
	action_bar.add_child(freeze_button)

	sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(50, 24)
	sell_button.add_theme_font_size_override("font_size", 11)
	sell_button.text = "Sell"
	sell_button.pressed.connect(_on_sell_pressed)
	action_bar.add_child(sell_button)

	# Confirm bar (Buy / Cancel) — hidden until a shop card is selected
	shop_confirm_bar = HBoxContainer.new()
	shop_confirm_bar.add_theme_constant_override("separation", 6)
	shop_confirm_bar.visible = false
	ui_layer.add_child(shop_confirm_bar)

	buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(50, 22)
	buy_button.add_theme_font_size_override("font_size", 11)
	buy_button.pressed.connect(_confirm_shop_purchase)
	shop_confirm_bar.add_child(buy_button)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(50, 22)
	cancel_button.add_theme_font_size_override("font_size", 11)
	cancel_button.pressed.connect(_cancel_shop_selection)
	shop_confirm_bar.add_child(cancel_button)

func _roll_shop() -> void:
	_cancel_shop_selection()
	shop_slots.clear()
	# Equal weight for all heroes — no round-based suppression in shop
	var weighted_heroes: Array[UnitData] = []
	for data in hero_pool:
		weighted_heroes.append(data)
	for i in range(HERO_SHOP_SLOTS):
		var data: UnitData = weighted_heroes.pick_random()
		shop_slots.append({"type": "hero", "data": data, "cost": data.farm_cost, "sold": false})
	var pool = upgrade_pool.filter(func(u):
		if u.rarity == "Epic": return GameManager.current_round >= 10
		if u.rarity == "Rare": return GameManager.current_round >= 5
		return true
	)
	for i in range(UPGRADE_SHOP_SLOTS):
		var upgrade: Dictionary = pool.pick_random()
		shop_slots.append({"type": "upgrade", "data": upgrade, "cost": upgrade.cost, "sold": false})
	_update_shop_display()

func _update_shop_display() -> void:
	for i in range(shop_slots.size()):
		var slot: Dictionary = shop_slots[i]
		var btn: Button = shop_buttons[i]
		btn.modulate = Color(1, 1, 1)
		btn.icon = null
		# Reset any custom style overrides
		btn.remove_theme_stylebox_override("normal")
		if slot.sold:
			btn.text = "SOLD"
			btn.disabled = true
		elif slot.type == "hero":
			var data: UnitData = slot.data
			var cls_color: Color = CLASS_COLORS.get(data.unit_class, Color.WHITE)
			var label := "%dg [F:%d]\n%s\n%s" % [data.farm_cost, data.pop_cost, data.unit_class, data.unit_name]
			if _find_player_unit_by_class(data.unit_class):
				label += "\nMerge as EXP"
			btn.text = label
			btn.disabled = false
			# Hero icon (small, left-aligned)
			if data.texture:
				btn.icon = data.texture
			# Colored left border accent
			var hero_style := StyleBoxFlat.new()
			hero_style.bg_color = Color(0.18, 0.18, 0.22)
			hero_style.border_color = cls_color
			hero_style.border_width_left = 3
			hero_style.set_corner_radius_all(3)
			hero_style.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", hero_style)
		else:
			var upgrade: Dictionary = slot.data
			var class_text := ""
			if upgrade.has("class_req"):
				class_text = "\n(%s only)" % upgrade.class_req
			btn.text = "%dg\n%s\n%s\n%s%s" % [upgrade.cost, upgrade.name, upgrade.rarity, upgrade.desc, class_text]
			btn.disabled = false
			# Buff icon — use rarity icon for class-specific, stat icon otherwise
			var stat_key: String = upgrade.get("stat", "")
			if upgrade.rarity == "Epic" and BUFF_ICONS.has("_epic"):
				btn.icon = BUFF_ICONS["_epic"]
			elif upgrade.rarity == "Rare" and upgrade.has("class_req") and BUFF_ICONS.has("_rare"):
				btn.icon = BUFF_ICONS["_rare"]
			elif BUFF_ICONS.has(stat_key):
				btn.icon = BUFF_ICONS[stat_key]
			# Rarity coloring via left border accent
			if upgrade.rarity == "Rare":
				var rare_style := StyleBoxFlat.new()
				rare_style.bg_color = Color(0.18, 0.18, 0.22)
				rare_style.border_color = Color(0.65, 0.45, 0.85)
				rare_style.border_width_left = 3
				rare_style.set_corner_radius_all(3)
				rare_style.set_content_margin_all(4)
				btn.add_theme_stylebox_override("normal", rare_style)
			elif upgrade.rarity == "Epic":
				var epic_style := StyleBoxFlat.new()
				epic_style.bg_color = Color(0.18, 0.18, 0.22)
				epic_style.border_color = Color(1.0, 0.6, 0.2)
				epic_style.border_width_left = 3
				epic_style.set_corner_radius_all(3)
				epic_style.set_content_margin_all(4)
				btn.add_theme_stylebox_override("normal", epic_style)
		if i == _selected_shop_slot and not slot.sold:
			btn.modulate = btn.modulate.lightened(0.35)

	reroll_button.text = "Re-roll (%dg)" % GameManager.REROLL_COST
	reroll_button.disabled = GameManager.gold < GameManager.REROLL_COST
	_update_freeze_display()

func _on_shop_card_pressed(idx: int) -> void:
	if _targeting_upgrade:
		return
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if idx >= shop_slots.size():
		return
	var slot: Dictionary = shop_slots[idx]
	if slot.sold:
		return
	_select_shop_slot(idx)

func _select_shop_slot(idx: int) -> void:
	_selected_shop_slot = idx
	_shift_held_on_select = Input.is_key_pressed(KEY_SHIFT)
	_update_shop_display()
	# Position confirm bar below the selected shop button
	var btn: Button = shop_buttons[idx]
	var btn_global := btn.global_position
	shop_confirm_bar.position = Vector2(btn_global.x, btn_global.y + btn.size.y + 4)
	shop_confirm_bar.visible = true
	_show_shop_preview(idx)
	# Highlight merge target if buying a duplicate hero
	var slot: Dictionary = shop_slots[idx]
	if slot.type == "hero" and not _shift_held_on_select:
		board.merge_highlight_unit = _find_player_unit_by_class(slot.data.unit_class)
	else:
		board.merge_highlight_unit = null
	board.queue_redraw()

func _cancel_shop_selection() -> void:
	if _selected_shop_slot < 0:
		return
	_selected_shop_slot = -1
	_shift_held_on_select = false
	shop_confirm_bar.visible = false
	board.merge_highlight_unit = null
	_hide_info_panel()
	_update_shop_display()

func _confirm_shop_purchase() -> void:
	if _selected_shop_slot < 0:
		return
	var idx := _selected_shop_slot
	var slot: Dictionary = shop_slots[idx]
	_selected_shop_slot = -1
	shop_confirm_bar.visible = false
	board.merge_highlight_unit = null
	if slot.type == "hero":
		_buy_hero(idx)
	else:
		_buy_upgrade(idx)
	_update_shop_display()

func _buy_hero(idx: int) -> void:
	var slot: Dictionary = shop_slots[idx]
	var data: UnitData = slot.data

	# Auto-merge: if a same-class unit exists and Shift is NOT held, feed as XP
	var merge_target := _find_player_unit_by_class(data.unit_class)
	if merge_target and not _shift_held_on_select:
		if not GameManager.spend_gold(slot.cost):
			_show_warning("Not enough gold!")
			return
		_grant_xp(merge_target, 1)
		slot.sold = true
		board.select_unit(merge_target)
		_show_info_panel(merge_target)
		_update_shop_display()
		_update_ui()
		AudioManager.play("buy")
		return

	# Spawn new unit — check farm budget
	if _get_farms_used() + data.pop_cost > GameManager.farms:
		_show_warning("Not enough farms!")
		return
	if not GameManager.spend_gold(slot.cost):
		_show_warning("Not enough gold!")
		return

	var default_pos := board.snap_to_grid(Vector2(
		randf_range(60, Board.DIVIDER_X - 60),
		randf_range(60, Board.ARENA_HEIGHT - 60)
	))
	_spawn_unit(data, Unit.Team.PLAYER, default_pos)
	slot.sold = true
	_update_shop_display()
	_update_ui()
	AudioManager.play("buy")

func _find_player_unit_by_class(unit_class: String) -> Unit:
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		if unit.unit_data.unit_class == unit_class:
			return unit
	return null

func _buy_upgrade(idx: int) -> void:
	var slot: Dictionary = shop_slots[idx]

	if not GameManager.spend_gold(slot.cost):
		_show_warning("Not enough gold!")
		return

	slot.sold = true
	_targeting_upgrade = true
	_pending_upgrade_slot = idx
	var upgrade_data: Dictionary = slot.data
	board.targeting_class_req = upgrade_data.get("class_req", "")
	board.targeting_mode = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	_update_shop_display()
	_update_ui()
	board.queue_redraw()
	AudioManager.play("buy")

func _apply_pending_upgrade(unit: Unit) -> void:
	var slot: Dictionary = shop_slots[_pending_upgrade_slot]
	var upgrade: Dictionary = slot.data

	# Validate class restriction
	if upgrade.has("class_req") and unit.unit_data.unit_class != upgrade.class_req:
		_show_warning("Wrong unit class!")
		return

	# Check if unit already has this upgrade — level it up instead of taking a slot
	var existing_upg: Dictionary = {}
	for upg in unit.applied_upgrades:
		if upg.name == upgrade.name:
			existing_upg = upg
			break

	if existing_upg.is_empty():
		# New upgrade — check slot limit
		if unit.applied_upgrades.size() >= unit.get_max_upgrades():
			_show_warning("Unit has max upgrades!")
			return
		var new_upg := upgrade.duplicate()
		new_upg.level = 1
		unit.applied_upgrades.append(new_upg)
	else:
		# Level up existing upgrade
		existing_upg.level = existing_upg.get("level", 1) + 1

	_apply_stat_buff(unit, upgrade.stat, upgrade.amount)
	AudioManager.play("upgrade")

	_targeting_upgrade = false
	_pending_upgrade_slot = -1
	board.targeting_class_req = ""
	board.targeting_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	board.select_unit(unit)
	_show_info_panel(unit)
	_update_ui()
	board.queue_redraw()

func _on_repurchase_upgrade(unit: Unit, upgrade: Dictionary) -> void:
	if not is_instance_valid(unit) or unit.is_dead:
		return
	if not GameManager.spend_gold(upgrade.cost):
		_show_warning("Not enough gold!")
		return
	_apply_stat_buff(unit, upgrade.stat, upgrade.amount)
	# Level up the existing upgrade instead of taking a new slot
	for upg in unit.applied_upgrades:
		if upg.name == upgrade.name:
			upg.level = upg.get("level", 1) + 1
			break
	AudioManager.play("upgrade")
	_show_info_panel(unit)
	_update_ui()
	board.queue_redraw()

func _cancel_upgrade_targeting() -> void:
	if not _targeting_upgrade:
		return
	var slot: Dictionary = shop_slots[_pending_upgrade_slot]
	# Refund gold and notify UI
	GameManager.gold += slot.cost
	GameManager.gold_changed.emit(GameManager.gold)
	slot.sold = false

	_targeting_upgrade = false
	_pending_upgrade_slot = -1
	board.targeting_class_req = ""
	board.targeting_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_update_shop_display()
	_update_ui()
	board.queue_redraw()

func _on_reroll_pressed() -> void:
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if GameManager.spend_gold(GameManager.REROLL_COST):
		_roll_shop()
		_update_ui()
		AudioManager.play("reroll")

func _show_shop() -> void:
	shop_bar.visible = true
	action_bar.visible = true

func _hide_shop() -> void:
	shop_bar.visible = false
	action_bar.visible = false
	shop_confirm_bar.visible = false


# ── Sell ─────────────────────────────────────────────────────

func _on_sell_pressed() -> void:
	_sell_selected_unit()

func _sell_selected_unit() -> void:
	if _targeting_upgrade:
		return
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if not board.selected_unit or not is_instance_valid(board.selected_unit):
		return
	if board.selected_unit.team != Unit.Team.PLAYER:
		return
	var unit := board.selected_unit
	var refund := unit.unit_data.farm_cost
	GameManager.gold += refund
	GameManager.gold_changed.emit(GameManager.gold)
	board.remove_unit(unit)
	unit.queue_free()
	board.deselect()
	_hide_info_panel()
	_update_ui()
	AudioManager.play("sell")

# ── Freeze Shop ──────────────────────────────────────────────

func _on_freeze_pressed() -> void:
	_toggle_freeze()

func _toggle_freeze() -> void:
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	shop_frozen = not shop_frozen
	_update_freeze_display()

func _update_freeze_display() -> void:
	if shop_frozen:
		freeze_button.text = "Unfreeze"
		freeze_button.modulate = Color(0.5, 0.8, 1.0)
	else:
		freeze_button.text = "Freeze"
		freeze_button.modulate = Color(1, 1, 1)

# ── Stat Upgrades ───────────────────────────────────────────

func _apply_stat_buff(unit: Unit, stat_key: String, amount: float) -> void:
	match stat_key:
		"damage":
			unit.damage += int(amount)
		"attacks_per_second":
			unit.attacks_per_second += amount
		"max_hp":
			unit.max_hp += int(amount)
			unit.current_hp += int(amount)
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
		"max_mana":
			unit.max_mana += int(amount)
			unit._update_mana_bar()
		"armor":
			unit.armor += int(amount)
			unit.max_armor += int(amount)
			unit._update_armor_bar()
		"evasion":
			unit.evasion += amount
		"attack_range":
			unit.attack_range += amount
		"ability_range":
			unit.ability_range += amount
		"move_speed":
			unit.move_speed += amount
		"crit_chance":
			unit.crit_chance += amount
		"skill_proc_chance":
			unit.skill_proc_chance += amount
		"necromancy":
			unit.necromancy_stacks += int(amount)
		"primed":
			unit.primed = true
		"corrosive":
			unit.corrosive_power += int(amount)
		# ── Reworked Generic Mechanics ──
		"thorns_slow":
			unit.thorns_slow = true
		"lifesteal":
			unit.lifesteal_pct += amount
		"berserk":
			var hp_loss := int(unit.max_hp * 0.3)
			unit.max_hp -= hp_loss
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
			unit.damage += 6
			unit.attacks_per_second += 0.4
		"last_stand":
			unit.last_stand = true
		"relentless":
			unit.relentless = true
		"sepsis":
			unit.sepsis_spread += int(amount)
		"living_shield":
			unit.living_shield_max += int(amount)
			unit.living_shield_hp += int(amount)
		"invincible":
			unit.invincible_max += int(amount)
			unit.invincible_charges += int(amount)
			unit.evasion += 5.0
		"haymaker":
			unit.haymaker_counter = int(amount)
		# ── Normal Hero-Specific ──
		"venom_arrow":
			unit.poison_power += int(amount)
		"war_paint":
			unit.damage += 3
			unit.max_hp += 10
			unit.current_hp += 10
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
		"steady_aim":
			unit.damage += 4
			unit.attack_range += 20
		"shadow_cloak":
			unit.evasion += 5.0
			unit.crit_chance += 3.0
		"thick_plate":
			unit.armor += 10
			unit.max_armor += 10
			unit._update_armor_bar()
			unit.max_hp += 15
			unit.current_hp += 15
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
		"dark_sigil":
			unit.damage += 3
			unit.max_mana += 2
			unit._update_mana_bar()
		"sacred_blessing":
			unit.max_hp += 15
			unit.current_hp += 15
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
			unit.max_mana += 2
			unit._update_mana_bar()
		"herbal_brew":
			unit.damage += 3
			unit.skill_proc_chance += 3.0
		"shield_of_faith":
			unit.armor += 8
			unit.max_armor += 8
			unit.armor_effectiveness += 0.1
			unit._update_armor_bar()
		"soul_binding":
			unit.necromancy_stacks += 1
			unit.max_hp += 10
			unit.current_hp += 10
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
		# ── Rare Hero-Specific ──
		"blood_rage":
			unit.damage += 5
			unit.attacks_per_second += 0.2
		"deadeye":
			unit.damage += 8
			unit.attack_range += 80
		"phantom_step":
			unit.evasion += 10
			unit.crit_chance += 10
		"fortress":
			unit.armor += 25
			unit.max_armor += 25
			unit._update_armor_bar()
			unit.max_hp += 40
			unit.current_hp += 40
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
		"soul_rend":
			unit.damage += 8
			unit.max_mana += 3
			unit._update_mana_bar()
		"divine_covenant":
			unit.max_hp += 30
			unit.current_hp += 30
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
			unit.max_mana += 3
			unit._update_mana_bar()
		"toxic_mastery":
			unit.damage += 5
			unit.skill_proc_chance += 5
		"holy_vanguard":
			unit.armor += 15
			unit.max_armor += 15
			unit.armor_effectiveness += 0.25
			unit._update_armor_bar()
			unit.damage += 3
		# ── Epic Hero-Specific ──
		"rampage":
			unit.damage += 10
			unit.attacks_per_second += 0.3
			unit.max_hp += 20
			unit.current_hp += 20
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
		"hawkeye":
			unit.damage += 12
			unit.attack_range += 120
			unit.crit_chance += 8
		"deaths_embrace":
			unit.evasion += 15
			unit.crit_chance += 15
			unit.damage += 5
		"bastion":
			unit.armor += 40
			unit.max_armor += 40
			unit._update_armor_bar()
			unit.max_hp += 60
			unit.current_hp += 60
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
			unit.damage += 2
		"dark_pact":
			unit.damage += 15
			unit.max_mana += 5
			unit._update_mana_bar()
		"ascension":
			unit.max_hp += 50
			unit.current_hp += 50
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
			unit.max_mana += 5
			unit._update_mana_bar()
			unit.damage += 5
		"plague_lord":
			unit.damage += 10
			unit.skill_proc_chance += 8
			unit.armor += 15
			unit.max_armor += 15
			unit._update_armor_bar()
		"divine_bulwark":
			unit.armor += 25
			unit.max_armor += 25
			unit.armor_effectiveness += 0.5
			unit._update_armor_bar()
			unit.max_hp += 40
			unit.current_hp += 40
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
			unit.damage += 5
		"legion_master":
			unit.legion_master = true
			unit.necromancy_stacks += 2
			unit.max_hp += 30
			unit.current_hp += 30
			unit.health_bar.max_value = unit.max_hp
			unit.health_bar.value = unit.current_hp
	board.queue_redraw()

func _on_stat_upgrade_pressed(unit: Unit, stat_key: String, increment: float) -> void:
	if not is_instance_valid(unit) or unit.is_dead:
		return
	var cost := unit.get_stat_upgrade_cost(stat_key)
	if not GameManager.spend_gold(cost):
		return
	_apply_stat_buff(unit, stat_key, increment)
	unit.record_stat_purchase(stat_key)
	_show_info_panel(unit)
	_update_ui()

# ── Hero Stacking (Merge) ──────────────────────────────────

func _merge_units(target: Unit, consumed: Unit) -> void:
	_grant_xp(target, 1 + consumed.xp)

	# Remove consumed unit
	board.remove_unit(consumed)
	consumed.queue_free()

	# Select merged unit and show updated stats
	board.select_unit(target)
	_show_info_panel(target)
	_update_ui()

func _grant_xp(target: Unit, xp_gained: int) -> void:
	target.xp += xp_gained

	# Flat boost per XP gained (additive to prevent exponential compounding)
	for i in range(xp_gained):
		target.damage += 1
		target.max_hp += 8
		target.attacks_per_second += 0.02
		target.attack_range += 3.0
		target.move_speed += 1.5
		if target.max_armor > 0:
			target.armor += 1
			target.max_armor += 1
		target.evasion += 0.5
		target.crit_chance += 0.5
		target.skill_proc_chance += 0.3
		target.max_mana += 1

	# Level-up loop (mild multiplicative — the real power spike)
	while target.xp >= Unit.XP_TO_LEVEL:
		target.xp -= Unit.XP_TO_LEVEL
		target.level += 1
		target.damage = int(ceil(target.damage * 1.08))
		target.max_hp = int(ceil(target.max_hp * 1.08))
		target.attacks_per_second *= 1.02
		target.attack_range *= 1.03
		target.move_speed *= 1.03
		target.armor += 2 if target.armor > 0 else 0
		target.evasion += 2.0
		target.crit_chance += 2.0
		target.skill_proc_chance += 1.5
		target.max_mana += 2

	target.current_hp = target.max_hp
	target.current_mana = 0

	# Update visuals
	target.health_bar.max_value = target.max_hp
	target.health_bar.value = target.current_hp
	target._update_mana_bar()
	target._update_armor_bar()
	target.update_scale()

# ── Squad Persistence ───────────────────────────────────────

func _save_squad() -> void:
	player_squad.clear()
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		var saved_upgrades: Array[Dictionary] = []
		for upg in unit.applied_upgrades:
			saved_upgrades.append(upg.duplicate())
		player_squad.append({
			"data": unit.unit_data,
			"position": unit.position,
			"xp": unit.xp,
			"level": unit.level,
			"necromancy_stacks": unit.necromancy_stacks,
			"primed": unit.primed,
			"display_name": unit.display_name,
			"ability_key": unit.ability_key,
			"instance_ability_name": unit.instance_ability_name,
			"instance_ability_desc": unit.instance_ability_desc,
			"stat_purchases": unit.stat_purchases.duplicate(),
			"applied_upgrades": saved_upgrades,
			"survival_hp_regen_bonus": unit.survival_hp_regen_bonus,
			"survival_mana_regen_bonus": unit.survival_mana_regen_bonus,
			# New buff properties
			"poison_power": unit.poison_power,
			"thorns_slow": unit.thorns_slow,
			"lifesteal_pct": unit.lifesteal_pct,
			"last_stand": unit.last_stand,
			"relentless": unit.relentless,
			"sepsis_spread": unit.sepsis_spread,
			"living_shield_max": unit.living_shield_max,
			"invincible_max": unit.invincible_max,
			"haymaker_counter": unit.haymaker_counter,
			"legion_master": unit.legion_master,
			"stats": {
				"damage": unit.damage,
				"max_hp": unit.max_hp,
				"attacks_per_second": unit.attacks_per_second,
				"attack_range": unit.attack_range,
				"ability_range": unit.ability_range,
				"move_speed": unit.move_speed,
				"armor": unit.armor,
				"max_armor": unit.max_armor,
				"evasion": unit.evasion,
				"crit_chance": unit.crit_chance,
				"skill_proc_chance": unit.skill_proc_chance,
				"max_mana": unit.max_mana,
				"mana_cost_per_attack": unit.mana_cost_per_attack,
				"mana_regen_per_second": unit.mana_regen_per_second - unit.survival_mana_regen_bonus,
				"hp_regen_per_second": unit.hp_regen_per_second - unit.survival_hp_regen_bonus,
			}
		})

func _restore_squad() -> void:
	for entry in player_squad:
		var unit := _spawn_unit(entry.data, Unit.Team.PLAYER, entry.position)
		unit.xp = entry.get("xp", 0)
		unit.level = entry.get("level", 1)
		unit.necromancy_stacks = entry.get("necromancy_stacks", 0)
		unit.primed = entry.get("primed", false)
		# Restore per-instance identity (overwrite random values from _spawn_unit)
		if entry.has("display_name"):
			unit.display_name = entry.display_name
		if entry.has("ability_key"):
			unit.ability_key = entry.ability_key
		if entry.has("instance_ability_name"):
			unit.instance_ability_name = entry.instance_ability_name
		if entry.has("instance_ability_desc"):
			unit.instance_ability_desc = entry.instance_ability_desc
		unit.stat_purchases = entry.get("stat_purchases", {}).duplicate()
		unit.survival_hp_regen_bonus = entry.get("survival_hp_regen_bonus", 0.0)
		unit.survival_mana_regen_bonus = entry.get("survival_mana_regen_bonus", 0.0)
		# Restore new buff properties
		unit.poison_power = entry.get("poison_power", 0)
		unit.thorns_slow = entry.get("thorns_slow", false)
		unit.lifesteal_pct = entry.get("lifesteal_pct", 0.0)
		unit.last_stand = entry.get("last_stand", false)
		unit.relentless = entry.get("relentless", false)
		unit.sepsis_spread = entry.get("sepsis_spread", 0)
		unit.living_shield_max = entry.get("living_shield_max", 0)
		unit.living_shield_hp = entry.get("living_shield_max", 0)
		unit.invincible_max = entry.get("invincible_max", 0)
		unit.invincible_charges = entry.get("invincible_max", 0)
		unit.haymaker_counter = entry.get("haymaker_counter", 0)
		unit.legion_master = entry.get("legion_master", false)
		var saved_upgrades: Array = entry.get("applied_upgrades", [])
		for upg in saved_upgrades:
			unit.applied_upgrades.append(upg.duplicate())
		if entry.has("stats"):
			var s: Dictionary = entry.stats
			unit.damage = s.damage
			unit.max_hp = s.max_hp
			unit.current_hp = s.max_hp
			unit.attacks_per_second = s.attacks_per_second
			unit.attack_range = s.attack_range
			unit.ability_range = s.get("ability_range", unit.unit_data.ability_range)
			unit.move_speed = s.move_speed
			unit.max_armor = s.get("max_armor", s.armor)
			unit.armor = int(unit.max_armor * 0.75) if unit.max_armor > 0 else 0
			unit.evasion = s.evasion
			unit.crit_chance = s.crit_chance
			unit.skill_proc_chance = s.skill_proc_chance
			unit.max_mana = s.max_mana
			unit.current_mana = 0
			unit.mana_cost_per_attack = s.mana_cost_per_attack
			unit.mana_regen_per_second = s.mana_regen_per_second + unit.survival_mana_regen_bonus
			unit.hp_regen_per_second = s.get("hp_regen_per_second", 0.0) + unit.survival_hp_regen_bonus
			unit.health_bar.max_value = s.max_hp
			unit.health_bar.value = s.max_hp
			unit._update_armor_bar()
			unit.update_scale()

	# Paladin aura: allies within ability_range of a Paladin get +10% armor effectiveness
	var player_units := board.get_units_on_team(Unit.Team.PLAYER)
	var paladins: Array[Unit] = []
	for u in player_units:
		if u.unit_data.unit_class == "Paladin":
			paladins.append(u)
	if not paladins.is_empty():
		for u in player_units:
			for pal in paladins:
				if u != pal and u.position.distance_to(pal.position) <= pal.ability_range:
					u.armor_effectiveness += 0.1
					break

# ── Unit Spawning ───────────────────────────────────────────

func _spawn_unit(data: UnitData, team: Unit.Team, pos: Vector2) -> Unit:
	var unit: Unit = unit_scene.instantiate()
	unit.setup(data, team, pos)
	# Assign random name and ability variant
	unit.display_name = HeroVariants.random_name(data.unit_class)
	var variant: Dictionary = HeroVariants.random_ability(data.unit_class)
	unit.ability_key = variant.key
	unit.instance_ability_name = variant.name
	unit.instance_ability_desc = variant.desc
	board.add_unit(unit)
	return unit

func _on_summon_requested(data: UnitData, team: Unit.Team, pos: Vector2, summoner: Unit) -> void:
	var archer := _spawn_unit(data, team, pos)
	# Summoned archers are weaker than recruited ones (75% base stats)
	archer.damage = int(ceil(archer.damage * 0.75))
	archer.max_hp = int(ceil(archer.max_hp * 0.75))
	archer.current_hp = archer.max_hp
	archer.attacks_per_second *= 0.9
	archer.health_bar.max_value = archer.max_hp
	archer.health_bar.value = archer.current_hp
	# Scale summoned archer stats based on the summoner's merge count and stat purchases
	var total_purchases: int = 0
	for key in summoner.stat_purchases:
		total_purchases += summoner.stat_purchases[key]
	var power: float = (summoner.level - 1) * 5.0 + summoner.xp + total_purchases
	if power > 0:
		var scale_factor := 1.0 + power * 0.12
		archer.damage = int(ceil(archer.damage * scale_factor))
		archer.max_hp = int(ceil(archer.max_hp * scale_factor))
		archer.current_hp = archer.max_hp
		archer.attacks_per_second *= 1.0 + power * 0.05
		archer.health_bar.max_value = archer.max_hp
		archer.health_bar.value = archer.current_hp
		archer.update_scale()
	# Necromancy: each stack gives summoned archers 20% of the summoner's bonus stats (max 3 stacks)
	if summoner.necromancy_stacks > 0:
		var effective_stacks := mini(summoner.necromancy_stacks, 3)
		var pct := effective_stacks * 0.20
		var bonus_dmg := summoner.damage - summoner.unit_data.damage
		var bonus_hp := summoner.max_hp - summoner.unit_data.max_hp
		var bonus_atk_spd := summoner.attacks_per_second - summoner.unit_data.attacks_per_second
		var bonus_armor := summoner.armor - summoner.unit_data.armor
		var bonus_evasion := summoner.evasion - summoner.unit_data.evasion
		var bonus_crit := summoner.crit_chance - summoner.unit_data.crit_chance
		archer.damage += int(ceil(bonus_dmg * pct))
		archer.max_hp += int(ceil(bonus_hp * pct))
		archer.current_hp = archer.max_hp
		archer.attacks_per_second += bonus_atk_spd * pct
		archer.armor += int(ceil(bonus_armor * pct))
		archer.evasion += bonus_evasion * pct
		archer.crit_chance += bonus_crit * pct
		archer.health_bar.max_value = archer.max_hp
		archer.health_bar.value = archer.current_hp
		archer._update_armor_bar()
	# Variant-specific skeleton buffs (scale with round)
	var round_num: int = GameManager.current_round
	match summoner.ability_key:
		"summoner_guardian":
			var bonus_hp := 15 + round_num * 5
			var bonus_armor := 5 + round_num * 3
			archer.max_hp += bonus_hp
			archer.current_hp = archer.max_hp
			archer.armor += bonus_armor
			archer.max_armor = maxi(archer.max_armor, archer.armor)
			archer.health_bar.max_value = archer.max_hp
			archer.health_bar.value = archer.current_hp
			archer._update_armor_bar()
		"summoner_familiar":
			var bonus_dmg := 3 + round_num * 3
			var bonus_crit := 5.0 + round_num * 2.0
			var bonus_aps := 0.1 + round_num * 0.03
			archer.damage += bonus_dmg
			archer.crit_chance += bonus_crit
			archer.attacks_per_second += bonus_aps
		_:
			var bonus_hp := 8 + round_num * 3
			var bonus_dmg := 2 + round_num * 2
			archer.max_hp += bonus_hp
			archer.current_hp = archer.max_hp
			archer.damage += bonus_dmg
			archer.health_bar.max_value = archer.max_hp
			archer.health_bar.value = archer.current_hp
	# Legion Master: summoned units get +5 dmg, +30 HP
	if summoner.legion_master:
		archer.damage += 5
		archer.max_hp += 30
		archer.current_hp = mini(archer.current_hp + 30, archer.max_hp)
		archer.health_bar.max_value = archer.max_hp
		archer.health_bar.value = archer.current_hp

# ── Input (Drag & Drop + Selection) ────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_phase == GameManager.Phase.WAVE_SELECT:
		return

	# Cancel shop selection on right-click or Escape
	if _selected_shop_slot >= 0:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_shop_selection()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_shop_selection()
			return

	# Cancel upgrade targeting on right-click or Escape
	if _targeting_upgrade:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_upgrade_targeting()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_upgrade_targeting()
			return

	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_X:
			_sell_selected_unit()
			return
		if event.keycode == KEY_F:
			_toggle_freeze()
			return

	var local_pos := board.get_local_mouse_position()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_mouse_pressed(local_pos)
		else:
			_on_mouse_released(local_pos)
	elif event is InputEventMouseMotion and dragging_unit:
		_on_mouse_drag(local_pos)

func _on_mouse_pressed(local_pos: Vector2) -> void:
	# Upgrade targeting: only accept clicks on player units
	if _targeting_upgrade:
		var clicked_unit := board.get_unit_at(local_pos)
		if clicked_unit and clicked_unit.team == Unit.Team.PLAYER:
			_apply_pending_upgrade(clicked_unit)
		return

	var clicked_unit := board.get_unit_at(local_pos)

	if clicked_unit:
		board.select_unit(clicked_unit)
		_show_info_panel(clicked_unit)

		if clicked_unit.team == Unit.Team.PLAYER and GameManager.current_phase == GameManager.Phase.PREP:
			dragging_unit = clicked_unit
			drag_offset = clicked_unit.position - local_pos
			board.show_grid = true
			board.queue_redraw()
	else:
		board.deselect()
		_hide_info_panel()

func _on_mouse_drag(local_pos: Vector2) -> void:
	if not dragging_unit or not is_instance_valid(dragging_unit):
		dragging_unit = null
		board.show_grid = false
		board.queue_redraw()
		return
	var target_pos := local_pos + drag_offset
	dragging_unit.position = board.clamp_to_player_half(target_pos)
	board.queue_redraw()

func _on_mouse_released(_local_pos: Vector2) -> void:
	if dragging_unit and is_instance_valid(dragging_unit):
		# Check for merge at the current drag position BEFORE snapping
		var merge_target := board.get_unit_at(dragging_unit.position, 50.0, dragging_unit)
		if merge_target and merge_target.team == Unit.Team.PLAYER \
				and merge_target.unit_data.unit_class == dragging_unit.unit_data.unit_class:
			_merge_units(merge_target, dragging_unit)
		else:
			var snapped := board.snap_to_grid(dragging_unit.position, dragging_unit)
			dragging_unit.position = snapped

	board.show_grid = false
	board.queue_redraw()
	dragging_unit = null

# ── Battle Flow ─────────────────────────────────────────────

func _on_ready_pressed() -> void:
	if _targeting_upgrade:
		return
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if board.get_units_on_team(Unit.Team.PLAYER).is_empty():
		_show_warning("Place units first!")
		return
	_cancel_shop_selection()
	_save_squad()
	_hide_shop()
	_hide_info_panel()
	result_label.text = ""
	combat_log.clear()
	_show_battle_ui()
	_on_tick_completed()
	GameManager.start_battle()
	combat_system.start_combat()
	_update_ui()
	AudioManager.play("round_start")

func _on_combat_ended(player_won: bool) -> void:
	_apply_survival_regen_bonuses()
	var is_first_loss := not player_won and not GameManager.first_loss_given
	GameManager.end_battle(player_won)
	if player_won:
		if _pending_bonus_gold > 0:
			GameManager.gold += _pending_bonus_gold
			GameManager.gold_changed.emit(GameManager.gold)
			result_label.text = "VICTORY! (+%dg bonus)" % _pending_bonus_gold
			_pending_bonus_gold = 0
		else:
			result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		AudioManager.play("victory")
	else:
		if is_first_loss and GameManager.lives > 0:
			result_label.text = "DEFEAT! — Rematch... (+50g bonus!)"
		else:
			result_label.text = "DEFEAT! — Rematch..."
		result_label.add_theme_color_override("font_color", Color.RED)
		AudioManager.play("defeat")
	_update_ui()

	if GameManager.current_round >= GameManager.MAX_ROUNDS and player_won:
		result_label.text = "GAME COMPLETE!"
		_show_return_to_menu_button()
	elif GameManager.lives > 0:
		if player_won and GameManager.current_round < GameManager.MAX_ROUNDS:
			get_tree().create_timer(2.0).timeout.connect(_start_next_round)
		elif not player_won:
			get_tree().create_timer(2.0).timeout.connect(_start_rematch)

func _show_return_to_menu_button() -> void:
	var btn := Button.new()
	btn.text = "Return to Menu"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.position = Vector2(540, 340)
	btn.pressed.connect(func():
		GameManager.reset()
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
	ui_layer.add_child(btn)

func _apply_survival_regen_bonuses() -> void:
	for entry in player_squad:
		var unit_name: String = entry.get("display_name", "")
		if unit_name == "" or not combat_system.survival_times.has(unit_name):
			continue
		var survived_seconds: float = combat_system.survival_times[unit_name]
		var hp_regen_earned: float = survived_seconds / 10.0 * 0.5
		var mana_regen_earned: float = survived_seconds / 10.0 * 0.1
		entry.survival_hp_regen_bonus = entry.get("survival_hp_regen_bonus", 0.0) + hp_regen_earned
		entry.survival_mana_regen_bonus = entry.get("survival_mana_regen_bonus", 0.0) + mana_regen_earned
		# Update saved stats to include new bonuses
		if entry.has("stats"):
			entry.stats.hp_regen_per_second = entry.stats.get("hp_regen_per_second", 0.0) + hp_regen_earned
			entry.stats.mana_regen_per_second = entry.stats.mana_regen_per_second + mana_regen_earned
		_on_combat_event("[color=yellow]%s survived %.0fs — earned +%.1f HP regen/s, +%.1f mana regen/s[/color]" % [unit_name, survived_seconds, hp_regen_earned, mana_regen_earned])

func _start_next_round() -> void:
	board.clear_all()
	board.deselect()
	_hide_info_panel()
	result_label.text = ""
	GameManager.advance_round()

func _start_rematch() -> void:
	board.clear_all()
	board.deselect()
	_hide_info_panel()
	_hide_battle_ui()
	result_label.text = ""
	# Reuse existing wave_options — skip _generate_wave_options() and advance_round()
	_show_wave_select_rematch()

# ── Phase Changes ───────────────────────────────────────────

func _on_phase_changed(new_phase: GameManager.Phase) -> void:
	if _targeting_upgrade:
		_cancel_upgrade_targeting()
	if new_phase == GameManager.Phase.WAVE_SELECT:
		_show_wave_select()
		_hide_battle_ui()
	elif new_phase == GameManager.Phase.PREP:
		_hide_battle_ui()
	_update_ui()

func _on_game_over() -> void:
	result_label.text = "GAME OVER"
	result_label.add_theme_color_override("font_color", Color.RED)
	ready_button.disabled = true
	_hide_shop()
	AudioManager.play("game_over")
	_show_return_to_menu_button()

# ── Farm Helpers ─────────────────────────────────────────────

func _get_farms_used() -> int:
	var total := 0
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		total += unit.unit_data.pop_cost
	return total

func _on_buy_farm_pressed() -> void:
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if not GameManager.buy_farm():
		_show_warning("Not enough gold!")
		return
	_update_ui()
	AudioManager.play("buy")

# ── UI Updates ──────────────────────────────────────────────

func _update_ui() -> void:
	round_label.text = "Round %d/%d" % [GameManager.current_round, GameManager.MAX_ROUNDS]
	lives_label.text = "Lives: %d" % GameManager.lives
	gold_label.text = "Gold: %d" % GameManager.gold
	farms_label.text = "Farms: %d/%d" % [_get_farms_used(), GameManager.farms]
	buy_farm_button.text = "Buy Farm (%dg)" % GameManager.get_farm_cost()
	buy_farm_button.disabled = GameManager.gold < GameManager.get_farm_cost() or GameManager.current_phase != GameManager.Phase.PREP

	match GameManager.current_phase:
		GameManager.Phase.WAVE_SELECT:
			ready_button.disabled = true
			ready_button.text = "Ready"
		GameManager.Phase.PREP:
			ready_button.disabled = false
			ready_button.text = "Ready"
		GameManager.Phase.BATTLE:
			ready_button.disabled = true
			ready_button.text = "Fighting..."
		GameManager.Phase.RESULT:
			ready_button.disabled = true

	if shop_bar and shop_bar.visible:
		_update_shop_display()

# ── Info Panel (with stat upgrade buttons) ──────────────────

func _show_info_panel(unit: Unit) -> void:
	_info_unit = unit
	info_scroll.visible = true

	# Clear existing children
	while info_panel.get_child_count() > 0:
		var child := info_panel.get_child(0)
		info_panel.remove_child(child)
		child.queue_free()

	var is_player := unit.team == Unit.Team.PLAYER
	var can_buy := is_player and GameManager.current_phase == GameManager.Phase.PREP

	# Header
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 16)
	var unit_name := unit.display_name if unit.display_name != "" else unit.unit_data.unit_name
	var header_text := "%s\n%s  (Cost: %dg  Farms: %d)" % [unit_name, unit.unit_data.unit_class, unit.unit_data.farm_cost, unit.unit_data.pop_cost]
	header_text += "\nLevel %d  xp %d/%d" % [unit.level, unit.xp, Unit.XP_TO_LEVEL]
	header.text = header_text
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.add_child(header)

	info_panel.add_child(HSeparator.new())

	# Stats with upgrade buttons
	_add_stat_row(unit, "damage", "Damage", "%d" % unit.damage, can_buy, 1.0)
	_add_stat_row(unit, "attacks_per_second", "Atk/Sec", "%.2f" % unit.attacks_per_second, can_buy, 0.1)
	_add_stat_display("Ability CD", "%.1fs" % unit.ability_cooldown)
	_add_stat_row(unit, "max_hp", "Health", "%d/%d" % [unit.current_hp, unit.max_hp], can_buy, 10.0)
	_add_stat_row(unit, "max_mana", "Mana", "%d/%d" % [unit.current_mana, unit.max_mana], can_buy, 2.0)
	_add_stat_row(unit, "armor", "Armor", "%d" % unit.armor, can_buy, 3.0)
	if unit.armor_pen > 0.0:
		_add_stat_display("Armor Pen", "%.0f%%" % (unit.armor_pen * 100.0))
	_add_stat_row(unit, "evasion", "Evasion", "%.0f%%" % unit.evasion, can_buy, 2.0)
	_add_stat_row(unit, "attack_range", "Atk Range", "%.0f" % unit.attack_range, can_buy, 20.0)
	_add_stat_row(unit, "ability_range", "Abl Range", "%.0f" % unit.ability_range, can_buy, 20.0)
	_add_stat_row(unit, "move_speed", "Move Speed", "%.0f" % unit.move_speed, can_buy, 5.0)
	_add_stat_row(unit, "crit_chance", "Crit", "%.0f%%" % unit.crit_chance, can_buy, 1.0)
	_add_stat_row(unit, "skill_proc_chance", "Skill Proc", "%.0f%%" % unit.skill_proc_chance, can_buy, 1.0)

	# Active debuffs / combat status (shown only when relevant)
	if unit.poison_dot > 0 or unit.corrosive_dot > 0:
		info_panel.add_child(HSeparator.new())
		var debuff_header := Label.new()
		debuff_header.add_theme_font_size_override("font_size", 14)
		debuff_header.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		debuff_header.text = "Debuffs:"
		info_panel.add_child(debuff_header)
		if unit.poison_dot > 0:
			_add_stat_display_colored("Poison", "%d stacks (%d HP/tick)" % [unit.poison_dot, unit.poison_dot], Color(0.2, 0.85, 0.2))
		if unit.corrosive_dot > 0:
			_add_stat_display_colored("Corrosive", "%d stacks" % unit.corrosive_dot, Color(0.9, 0.75, 0.1))

	# Survival Regen section (shown only when nonzero)
	if unit.survival_hp_regen_bonus > 0.0 or unit.survival_mana_regen_bonus > 0.0:
		info_panel.add_child(HSeparator.new())
		var regen_header := Label.new()
		regen_header.add_theme_font_size_override("font_size", 14)
		regen_header.text = "Survival Regen:"
		info_panel.add_child(regen_header)
		if unit.survival_hp_regen_bonus > 0.0:
			_add_stat_display("HP Regen/s", "+%.1f" % unit.survival_hp_regen_bonus)
		if unit.survival_mana_regen_bonus > 0.0:
			_add_stat_display("Mana Regen bonus", "+%.1f" % unit.survival_mana_regen_bonus)

	# Applied upgrades section — stacked with repurchase buttons
	info_panel.add_child(HSeparator.new())
	var upgrades_header := Label.new()
	upgrades_header.add_theme_font_size_override("font_size", 14)
	upgrades_header.text = "Upgrades (%d/%d):" % [unit.applied_upgrades.size(), unit.get_max_upgrades()]
	info_panel.add_child(upgrades_header)

	var at_max: bool = unit.applied_upgrades.size() >= unit.get_max_upgrades()
	for upg in unit.applied_upgrades:
		var level: int = upg.get("level", 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		if can_buy:
			var buy_btn := Button.new()
			buy_btn.text = "+%dg" % upg.cost
			buy_btn.custom_minimum_size = Vector2(42, 22)
			buy_btn.add_theme_font_size_override("font_size", 10)
			buy_btn.disabled = GameManager.gold < upg.cost
			var u := unit
			var u_upg := upg.duplicate()
			buy_btn.pressed.connect(func(): _on_repurchase_upgrade(u, u_upg))
			row.add_child(buy_btn)
		var upg_lbl := Label.new()
		upg_lbl.add_theme_font_size_override("font_size", 12)
		if level > 1:
			upg_lbl.text = "%s Lv%d — %s" % [upg.name, level, upg.desc]
		else:
			upg_lbl.text = "%s — %s" % [upg.name, upg.desc]
		var upg_color := _get_buff_icon_color(upg.get("stat", ""))
		if upg_color != Color.WHITE:
			upg_lbl.add_theme_color_override("font_color", upg_color)
		upg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(upg_lbl)
		info_panel.add_child(row)

	info_panel.add_child(HSeparator.new())

	# Ability / Skill / Boosted
	var extras := Label.new()
	extras.add_theme_font_size_override("font_size", 12)
	var ab_name := unit.instance_ability_name if unit.instance_ability_name != "" else unit.unit_data.ability_name
	var ab_desc := unit.instance_ability_desc if unit.instance_ability_desc != "" else unit.unit_data.ability_desc
	var text := "Ability: %s" % ab_name
	if ab_desc != "":
		text += "\n  %s" % ab_desc
	if unit.unit_data.skill_name != "":
		text += "\nSkill: %s" % unit.unit_data.skill_name
		if unit.unit_data.skill_desc != "":
			text += "\n  %s" % unit.unit_data.skill_desc
	if unit.unit_data.boosted_stats.size() > 0:
		text += "\nBoosted: %s" % ", ".join(unit.unit_data.boosted_stats)
	extras.text = text
	extras.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_panel.add_child(extras)

func _add_stat_row(unit: Unit, stat_key: String, label_text: String, value_text: String, can_buy: bool, increment: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	if can_buy:
		var cost := unit.get_stat_upgrade_cost(stat_key)
		var btn := Button.new()
		btn.text = "+%dg" % cost
		btn.custom_minimum_size = Vector2(42, 22)
		btn.add_theme_font_size_override("font_size", 10)
		var u := unit
		var k := stat_key
		var inc := increment
		btn.pressed.connect(func(): _on_stat_upgrade_pressed(u, k, inc))
		row.add_child(btn)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = "%s: %s" % [label_text, value_text]
	row.add_child(lbl)

	info_panel.add_child(row)

func _add_stat_display(label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text = "     %s: %s" % [label_text, value_text]
	info_panel.add_child(lbl)

func _add_stat_display_colored(label_text: String, value_text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.text = "     %s: %s" % [label_text, value_text]
	info_panel.add_child(lbl)

func _get_buff_icon_color(stat: String) -> Color:
	match stat:
		"corrosive": return Color(0.9, 0.75, 0.1)
		"venom_arrow": return Color(0.2, 0.85, 0.2)
		"thorns_slow": return Color(0.7, 0.3, 0.9)
		"lifesteal": return Color(0.9, 0.15, 0.25)
		"last_stand": return Color(1.0, 0.5, 0.1)
		"relentless": return Color(1.0, 0.85, 0.2)
		"living_shield": return Color(0.3, 0.6, 1.0)
		"invincible": return Color(1.0, 1.0, 1.0)
		"haymaker": return Color(1.0, 0.6, 0.15)
		"sepsis": return Color(0.5, 0.8, 0.1)
		"primed": return Color(0.2, 0.9, 0.9)
	return Color.WHITE

func _show_shop_preview(idx: int) -> void:
	var slot: Dictionary = shop_slots[idx]
	_info_unit = null
	info_scroll.visible = true

	# Clear existing children
	while info_panel.get_child_count() > 0:
		var child := info_panel.get_child(0)
		info_panel.remove_child(child)
		child.queue_free()

	if slot.type == "hero":
		var data: UnitData = slot.data
		var header := Label.new()
		header.add_theme_font_size_override("font_size", 16)
		header.text = "%s\n%s  (Cost: %dg  Farms: %d)" % [data.unit_name, data.unit_class, data.farm_cost, data.pop_cost]
		var merge_target := _find_player_unit_by_class(data.unit_class)
		if merge_target:
			header.text += "\nAuto-merge into existing unit"
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_panel.add_child(header)

		info_panel.add_child(HSeparator.new())

		var stats := Label.new()
		stats.add_theme_font_size_override("font_size", 13)
		stats.text = "Damage: %d\nAtk/Sec: %.2f\nAbility CD: %.1fs\nHealth: %d\nMana: %d\nArmor: %d\nEvasion: %.0f%%\nAtk Range: %.0f\nAbl Range: %.0f\nMove Speed: %.0f\nCrit: %.0f%%\nSkill Proc: %.0f%%" % [
			data.damage, data.attacks_per_second, data.ability_cooldown,
			data.max_hp, data.max_mana, data.armor, data.evasion,
			data.attack_range, data.ability_range, data.move_speed, data.crit_chance, data.skill_proc_chance
		]
		info_panel.add_child(stats)

		info_panel.add_child(HSeparator.new())

		var extras := Label.new()
		extras.add_theme_font_size_override("font_size", 12)
		# Show all possible ability variants for this class
		var variants: Array = HeroVariants.ABILITY_VARIANTS.get(data.unit_class, [])
		var text := ""
		if variants.size() > 0:
			text += "Possible Abilities:"
			for v in variants:
				text += "\n  %s — %s" % [v.name, v.desc]
		else:
			text += "Ability: %s" % data.ability_name
			if data.ability_desc != "":
				text += "\n  %s" % data.ability_desc
		if data.skill_name != "":
			text += "\nSkill: %s" % data.skill_name
			if data.skill_desc != "":
				text += "\n  %s" % data.skill_desc
		if data.boosted_stats.size() > 0:
			text += "\nBoosted: %s" % ", ".join(data.boosted_stats)
		extras.text = text
		extras.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		extras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_panel.add_child(extras)
	else:
		var upgrade: Dictionary = slot.data
		var header := Label.new()
		header.add_theme_font_size_override("font_size", 16)
		header.text = "%s\n%s  (Cost: %dg)" % [upgrade.name, upgrade.rarity, upgrade.cost]
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_panel.add_child(header)

		info_panel.add_child(HSeparator.new())

		var desc := Label.new()
		desc.add_theme_font_size_override("font_size", 13)
		var desc_text := "Effect: %s" % upgrade.desc
		if upgrade.has("class_req"):
			desc_text += "\nRequires: %s" % upgrade.class_req
		desc.text = desc_text
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_panel.add_child(desc)

func _hide_info_panel() -> void:
	info_scroll.visible = false
	_info_unit = null
