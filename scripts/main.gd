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
	"corrosive": preload("res://assets/icons/buff_corrosive.svg"),
	"living_shield": preload("res://assets/icons/buff_living_shield.svg"),
	"sepsis": preload("res://assets/icons/buff_sepsis.svg"),
	"thorns_slow": preload("res://assets/icons/buff_thorns.svg"),
	"lifesteal": preload("res://assets/icons/buff_lifesteal.svg"),
	"berserk": preload("res://assets/icons/buff_berserk.svg"),
	"last_stand": preload("res://assets/icons/buff_last_stand.svg"),
	"relentless": preload("res://assets/icons/buff_relentless.svg"),
	"invincible": preload("res://assets/icons/buff_invincible.svg"),
	"haymaker": preload("res://assets/icons/buff_haymaker.svg"),
	"war_paint": preload("res://assets/icons/buff_war_paint.svg"),
	"venom_arrow": preload("res://assets/icons/buff_venom_arrow.svg"),
	"shadow_cloak": preload("res://assets/icons/buff_shadow_cloak.svg"),
	"thick_plate": preload("res://assets/icons/buff_thick_plate.svg"),
	"dark_sigil": preload("res://assets/icons/buff_dark_sigil.svg"),
	"sacred_blessing": preload("res://assets/icons/buff_sacred_blessing.svg"),
	"herbal_brew": preload("res://assets/icons/buff_herbal_brew.svg"),
	"shield_of_faith": preload("res://assets/icons/buff_shield_of_faith.svg"),
	"soul_binding": preload("res://assets/icons/buff_soul_binding.svg"),
	"_rare": preload("res://assets/icons/buff_rare.svg"),
	"_epic": preload("res://assets/icons/buff_epic.svg"),
}

const HOUSE_SOLID: Texture2D = preload("res://assets/icons/house_solid.svg")
const HOUSE_OUTLINE: Texture2D = preload("res://assets/icons/house_outline.svg")

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

const RARITY_COLORS: Dictionary = {
	"Normal": Color(0.75, 0.75, 0.75),
	"Rare": Color(0.65, 0.45, 0.85),
	"Epic": Color(1.0, 0.6, 0.2),
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
	{"name": "Hellfire", "cost": 12, "rarity": "Rare", "desc": "Ability also blasts nearby enemies for 50% dmg", "stat": "hellfire", "amount": 1.0, "class_req": "Warlock"},
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
var _pre_battle_positions: Dictionary = {}  # display_name -> Vector2
var _prep_snapshot: Dictionary = {}  # Snapshot of pre-shopping state for map mode defeat revert

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
var action_bar: VBoxContainer

# Shop freeze state
var shop_frozen: bool = false

# Upgrade targeting state
var _targeting_upgrade: bool = false
var _pending_upgrade_slot: int = -1

# Merge targeting state (choosing which unit to stack XP into)
var _targeting_merge: bool = false
var _pending_merge_slot: int = -1

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

# Side-panel house-icon row (replaces farms_label text)
var farms_row: HBoxContainer

# Battle UI — strength bar, DPS panel & combat log
var strength_bar_container: HBoxContainer
var strength_bar_player: ColorRect
var strength_bar_enemy: ColorRect
var dps_panel: HBoxContainer
var dps_player_label: Label
var dps_enemy_label: Label
var battle_name_panel: HBoxContainer
var battle_player_name: Label
var battle_enemy_name: Label

# Ranked PvP state
var ranked_mode: bool = false
var current_opponent_rating: int = 0
var current_opponent_name: String = ""
var _ranked_opponents: Array = []
var _waiting_for_opponents: bool = false
var combat_timer_label: Label
var combat_log_scroll: ScrollContainer
var combat_log: RichTextLabel

# Result overlay
var result_overlay: ColorRect
var result_title: Label
var result_details: Label
var result_gold_label: Label
var result_gold_won_label: Label
var result_continue_btn: Button
var _last_result: String = ""

# Quit overlay
var quit_overlay: ColorRect

# Map overlay & node overlays
var map_overlay: MapOverlay
var rest_overlay: ColorRect
var special_shop_overlay: ColorRect
var treasure_overlay: ColorRect
var event_overlay: ColorRect
var _current_map_node: Dictionary = {}
var _map_upgrade_pending: Dictionary = {}  # for rest/treasure free upgrades
var _targeting_map_upgrade: bool = false
var _map_upgrade_return_to: String = ""  # "shop", "event_market", or "" (complete node)

# Gold counting animation
var _gold_anim_base: int = 0
var _gold_anim_won: int = 0
var _gold_anim_counted: int = 0
var _gold_anim_timer: Timer

func _ready() -> void:
	combat_system.setup(board)
	combat_system.combat_ended.connect(_on_combat_ended)
	combat_system.combat_draw.connect(_on_combat_draw)
	combat_system.summon_requested.connect(_on_summon_requested)
	ready_button.pressed.connect(_on_ready_pressed)
	buy_farm_button.pressed.connect(_on_buy_farm_pressed)

	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.gold_changed.connect(func(_g): _update_ui())
	GameManager.lives_changed.connect(func(_l): _update_ui())
	GameManager.game_over.connect(_on_game_over)

	# Replace FarmsLabel text with a row of house icons
	farms_label.visible = false
	farms_row = HBoxContainer.new()
	farms_row.add_theme_constant_override("separation", 3)
	farms_label.add_sibling(farms_row)
	farms_label.get_parent().move_child(farms_row, farms_label.get_index() + 1)

	_build_warning_label()
	_build_wave_select_ui()
	_build_shop_bar()
	_build_battle_ui()
	_build_result_overlay()
	_build_quit_overlay()
	_build_map_overlay()
	_build_rest_overlay()
	_build_special_shop_overlay()
	_build_treasure_overlay()
	_build_event_overlay()
	_hide_info_panel()
	_hide_shop()

	combat_system.combat_event.connect(_on_combat_event)
	combat_system.tick_completed.connect(_on_tick_completed)

	# Ranked PvP setup
	ranked_mode = GameManager.has_meta("ranked_mode") and GameManager.get_meta("ranked_mode")
	var _bm = get_node_or_null("/root/BackendManager")
	if ranked_mode and _bm:
		_bm.opponents_fetched.connect(_on_opponents_fetched)
	else:
		ranked_mode = false

	# Load from save if flagged by main menu
	if GameManager.has_meta("loading_save") and GameManager.get_meta("loading_save"):
		GameManager.remove_meta("loading_save")
		var save_data := GameManager.load_game()
		if not save_data.is_empty():
			GameManager.restore_from_save(save_data)
			player_squad = SquadSerializer.json_to_squad(save_data.get("player_squad", []))
			if GameManager.is_map_mode:
				GameManager.change_phase(GameManager.Phase.MAP)
			else:
				GameManager.change_phase(GameManager.Phase.WAVE_SELECT)
			_update_ui()
			return

	if not ranked_mode:
		GameManager.is_map_mode = true
		if GameManager.run_map.is_empty():
			GameManager.run_map = MapGenerator.generate()
		GameManager.advance_to_map()
	else:
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

	# Name panel — player vs opponent labels above DPS
	battle_name_panel = HBoxContainer.new()
	battle_name_panel.position = Vector2(55, 52)
	battle_name_panel.custom_minimum_size = Vector2(900, 16)
	battle_name_panel.add_theme_constant_override("separation", 0)
	battle_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(battle_name_panel)

	battle_player_name = Label.new()
	battle_player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	battle_player_name.add_theme_font_size_override("font_size", 11)
	battle_player_name.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0))
	battle_player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_player_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_player_name.text = "Your Squad"
	battle_name_panel.add_child(battle_player_name)

	battle_enemy_name = Label.new()
	battle_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_enemy_name.add_theme_font_size_override("font_size", 11)
	battle_enemy_name.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	battle_enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_enemy_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_name_panel.add_child(battle_enemy_name)

	battle_name_panel.visible = false

	# DPS panel — live team DPS readout below strength bar
	dps_panel = HBoxContainer.new()
	dps_panel.position = Vector2(55, 64)
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

	# Combat timer — countdown label centered above the battlefield
	combat_timer_label = Label.new()
	combat_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_timer_label.add_theme_font_size_override("font_size", 14)
	combat_timer_label.add_theme_color_override("font_color", Color.WHITE)
	combat_timer_label.position = Vector2(430, 84)
	combat_timer_label.size = Vector2(100, 20)
	combat_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_timer_label.visible = false
	ui_layer.add_child(combat_timer_label)

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

	# Update combat timer countdown
	var remaining := maxf(combat_system.MAX_COMBAT_TIME - combat_system.combat_elapsed, 0.0)
	var mins := int(remaining) / 60
	var secs := int(remaining) % 60
	combat_timer_label.text = "%d:%02d" % [mins, secs]
	if remaining <= 5.0:
		combat_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif remaining <= 15.0:
		combat_timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	else:
		combat_timer_label.add_theme_color_override("font_color", Color.WHITE)

	# Refresh info panel during combat so debuff stacks update live
	if _info_unit and is_instance_valid(_info_unit) and not _info_unit.is_dead:
		_show_info_panel(_info_unit)

func _show_battle_ui() -> void:
	strength_bar_container.visible = true
	battle_name_panel.visible = true
	dps_panel.visible = true
	combat_timer_label.visible = true
	combat_log_scroll.visible = true

func _hide_battle_ui() -> void:
	strength_bar_container.visible = false
	battle_name_panel.visible = false
	dps_panel.visible = false
	combat_timer_label.visible = false
	combat_log_scroll.visible = false

# ── Result Overlay ─────────────────────────────────────────

func _build_result_overlay() -> void:
	result_overlay = ColorRect.new()
	result_overlay.color = Color(0, 0, 0, 0.65)
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(result_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.6, 0.6, 0.7, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(result_title)

	result_details = Label.new()
	result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_details.add_theme_font_size_override("font_size", 14)
	result_details.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	result_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(result_details)

	result_gold_label = Label.new()
	result_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_gold_label.add_theme_font_size_override("font_size", 22)
	result_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(result_gold_label)

	result_gold_won_label = Label.new()
	result_gold_won_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_gold_won_label.add_theme_font_size_override("font_size", 16)
	result_gold_won_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
	vbox.add_child(result_gold_won_label)

	_gold_anim_timer = Timer.new()
	_gold_anim_timer.one_shot = false
	_gold_anim_timer.wait_time = 0.08
	_gold_anim_timer.timeout.connect(_on_gold_anim_tick)
	add_child(_gold_anim_timer)

	result_continue_btn = Button.new()
	result_continue_btn.text = "Continue"
	result_continue_btn.custom_minimum_size = Vector2(200, 40)
	result_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_continue_btn.pressed.connect(_on_result_continue)
	vbox.add_child(result_continue_btn)

	result_overlay.visible = false

func _show_result_overlay(title: String, title_color: Color, details: String, gold_won: int = 0) -> void:
	result_title.text = title
	result_title.add_theme_color_override("font_color", title_color)
	result_details.text = details
	result_continue_btn.text = "Continue"
	if gold_won > 0:
		_gold_anim_base = GameManager.gold
		_gold_anim_won = gold_won
		_gold_anim_counted = 0
		result_gold_label.text = "Gold: %dg" % _gold_anim_base
		result_gold_won_label.text = "+%dg" % gold_won
		result_gold_label.visible = true
		result_gold_won_label.visible = true
		_gold_anim_timer.start()
	else:
		result_gold_label.text = "Gold: %dg" % GameManager.gold
		result_gold_won_label.visible = false
		result_gold_label.visible = true
	result_overlay.visible = true

func _on_gold_anim_tick() -> void:
	_gold_anim_counted += 1
	var remaining := _gold_anim_won - _gold_anim_counted
	result_gold_label.text = "Gold: %dg" % (_gold_anim_base + _gold_anim_counted)
	result_gold_won_label.text = "+%dg" % remaining
	AudioManager.play("coin", -6.0)
	if _gold_anim_counted >= _gold_anim_won:
		result_gold_won_label.visible = false
		_gold_anim_timer.stop()

func _finish_gold_anim() -> void:
	_gold_anim_timer.stop()
	if _gold_anim_won > 0 and _gold_anim_counted < _gold_anim_won:
		_gold_anim_counted = _gold_anim_won
		result_gold_label.text = "Gold: %dg" % (_gold_anim_base + _gold_anim_won)
		result_gold_won_label.visible = false

func _on_result_continue() -> void:
	_finish_gold_anim()
	result_overlay.visible = false
	match _last_result:
		"game_complete":
			GameManager.delete_save()
			GameManager.reset()
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		"victory":
			if GameManager.is_map_mode:
				_advance_map_node()
			else:
				_start_next_round()
		"defeat", "draw":
			if GameManager.is_map_mode:
				# In map mode, defeat/draw = rematch same node
				_start_rematch()
			else:
				_start_rematch()
		"game_over":
			GameManager.delete_save()
			GameManager.reset()
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

# ── Quit Overlay ──────────────────────────────────────────

func _build_quit_overlay() -> void:
	quit_overlay = ColorRect.new()
	quit_overlay.color = Color(0, 0, 0, 0.8)
	quit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	quit_overlay.visible = false
	ui_layer.add_child(quit_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.border_color = Color(0.6, 0.6, 0.7, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Save & Quit?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var save_quit_btn := Button.new()
	save_quit_btn.text = "Save & Quit"
	save_quit_btn.custom_minimum_size = Vector2(130, 40)
	save_quit_btn.pressed.connect(_on_save_and_quit)
	btn_row.add_child(save_quit_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(130, 40)
	cancel_btn.pressed.connect(func(): quit_overlay.visible = false)
	btn_row.add_child(cancel_btn)

func _on_save_and_quit() -> void:
	_save_squad()
	GameManager.save_game(SquadSerializer.squad_to_json(player_squad), ranked_mode)
	AudioManager.stop_music()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

# ── Map Overlay ──────────────────────────────────────────────

func _build_map_overlay() -> void:
	map_overlay = MapOverlay.new()
	map_overlay.build()
	map_overlay.node_selected.connect(_on_map_node_selected)
	ui_layer.add_child(map_overlay)

func _on_map_node_selected(node_id: int) -> void:
	var node := MapGenerator.get_node_by_id(GameManager.run_map, node_id)
	if node.is_empty():
		return
	_current_map_node = node
	GameManager.map_node_id = node_id
	GameManager.run_map["current_node_id"] = node_id

	var node_type: int = node["type"]
	match node_type:
		MapData.NodeType.BATTLE, MapData.NodeType.ELITE, MapData.NodeType.BOSS:
			_start_map_battle(node)
		MapData.NodeType.REST:
			_show_rest_overlay()
		MapData.NodeType.SHOP:
			_show_special_shop_overlay()
		MapData.NodeType.TREASURE:
			_show_treasure_overlay()
		MapData.NodeType.UNKNOWN:
			_show_event_overlay()

func _start_map_battle(node: Dictionary) -> void:
	map_overlay.visible = false
	var act: int = node["act"]
	var floor_idx: int = node["floor"]
	var node_type: int = node["type"]
	var eff_round := MapData.get_effective_round(act, floor_idx)
	var budget_mult := MapData.get_budget_multiplier(node_type)

	# Try handcrafted encounter for elite/boss nodes
	if node_type == MapData.NodeType.ELITE or node_type == MapData.NodeType.BOSS:
		var encounter: Dictionary
		if node_type == MapData.NodeType.ELITE:
			encounter = Encounters.pick_elite(act, GameManager.encountered_ids)
		else:
			encounter = Encounters.pick_boss(act, GameManager.encountered_ids)
		if not encounter.is_empty():
			GameManager.encountered_ids.append(encounter.id)
			var wave := _build_encounter_wave(encounter, eff_round)
			wave_options = [wave]
			_on_wave_selected(0)
			return

	# Fallback: AI economy-simulated squad
	var battle_seed := hash(GameManager.run_map.get("seed", 0) + node.get("id", 0))
	var wave := AiSquadBuilder.build_squad(eff_round, budget_mult, battle_seed, hero_pool, upgrade_pool, wave_strategies)
	wave_options = [wave]
	_on_wave_selected(0)

func _complete_map_node() -> void:
	if _current_map_node.is_empty():
		return
	var node_id: int = _current_map_node["id"]
	MapGenerator.mark_node_visited(GameManager.run_map, node_id)
	MapGenerator.update_available_nodes(GameManager.run_map, node_id)
	_current_map_node = {}
	# Clear board — units may have been spawned for upgrade targeting
	board.clear_all()
	board.deselect()
	_hide_info_panel()
	GameManager.advance_to_map()

# ── Rest Overlay ─────────────────────────────────────────────

func _build_rest_overlay() -> void:
	rest_overlay = ColorRect.new()
	rest_overlay.color = Color(0, 0, 0, 0.8)
	rest_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	rest_overlay.visible = false
	ui_layer.add_child(rest_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.3, 0.8, 0.4, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Campfire Rest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "The warmth of the fire soothes your weary team.\nChoose a benefit:"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc)

	var btn_row := VBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var heal_btn := Button.new()
	heal_btn.text = "Restore 1 Life"
	heal_btn.custom_minimum_size = Vector2(0, 44)
	heal_btn.pressed.connect(_on_rest_heal)
	btn_row.add_child(heal_btn)

	var upgrade_btn := Button.new()
	upgrade_btn.text = "Free Upgrade (choose a unit)"
	upgrade_btn.custom_minimum_size = Vector2(0, 44)
	upgrade_btn.pressed.connect(_on_rest_upgrade)
	btn_row.add_child(upgrade_btn)

func _show_rest_overlay() -> void:
	map_overlay.visible = false
	rest_overlay.visible = true

func _on_rest_heal() -> void:
	rest_overlay.visible = false
	GameManager.lives += 1
	GameManager.lives_changed.emit(GameManager.lives)
	_show_warning("+1 Life restored!")
	AudioManager.play("victory")
	_complete_map_node()

func _on_rest_upgrade() -> void:
	rest_overlay.visible = false
	# Pick a random generic upgrade (no class restriction) for free
	var generic_upgrades := upgrade_pool.filter(func(u): return not u.has("class_req"))
	var upgrade: Dictionary = generic_upgrades.pick_random().duplicate()
	_map_upgrade_pending = upgrade
	_targeting_map_upgrade = true
	board.targeting_mode = true
	board.targeting_class_req = upgrade.get("class_req", "")
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	board.queue_redraw()
	_restore_squad()
	_show_warning("Apply free %s upgrade — click a unit" % upgrade.name)

# ── Special Shop Overlay ─────────────────────────────────────

func _build_special_shop_overlay() -> void:
	special_shop_overlay = ColorRect.new()
	special_shop_overlay.color = Color(0, 0, 0, 0.8)
	special_shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	special_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	special_shop_overlay.visible = false
	ui_layer.add_child(special_shop_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	special_shop_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(1.0, 0.85, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Wandering Merchant"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Exclusive wares not found in the regular shop."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc)

	# Items will be dynamically populated
	var items_vbox := VBoxContainer.new()
	items_vbox.name = "ShopItems"
	items_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(items_vbox)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(0, 40)
	leave_btn.pressed.connect(_on_special_shop_leave)
	vbox.add_child(leave_btn)

func _show_special_shop_overlay() -> void:
	map_overlay.visible = false
	# Populate items
	var items_vbox: VBoxContainer = special_shop_overlay.find_child("ShopItems", true, false)
	for child in items_vbox.get_children():
		child.queue_free()

	var shop_items := [
		{"name": "Extra House (+1 farm)", "cost": 8, "action": "farm"},
		{"name": "Restore Life (+1)", "cost": 15, "action": "life"},
		{"name": "Random Rare Upgrade", "cost": 10, "action": "rare_upgrade"},
		{"name": "Full Squad Heal (+30 HP each)", "cost": 12, "action": "squad_heal"},
	]
	# Act 2+ gets epic upgrade option
	if GameManager.run_map.get("current_act", 1) >= 2:
		shop_items.append({"name": "Random Epic Upgrade", "cost": 20, "action": "epic_upgrade"})

	for item in shop_items:
		var btn := Button.new()
		btn.text = "%s — %dg" % [item["name"], item["cost"]]
		btn.custom_minimum_size = Vector2(0, 40)
		var action: String = item["action"]
		var cost: int = item["cost"]
		btn.pressed.connect(func(): _buy_special_shop_item(action, cost, btn))
		items_vbox.add_child(btn)

	special_shop_overlay.visible = true

func _buy_special_shop_item(action: String, cost: int, btn: Button) -> void:
	if not GameManager.spend_gold(cost):
		_show_warning("Not enough gold!")
		return
	btn.disabled = true
	btn.text += " [SOLD]"
	AudioManager.play("buy")

	match action:
		"farm":
			GameManager.farms += 1
			GameManager.farm_purchases += 1
			GameManager.farms_changed.emit()
			_show_warning("+1 House!")
		"life":
			GameManager.lives += 1
			GameManager.lives_changed.emit(GameManager.lives)
			_show_warning("+1 Life!")
		"rare_upgrade":
			special_shop_overlay.visible = false
			var rare_upgrades := upgrade_pool.filter(func(u): return u.rarity == "Rare")
			if rare_upgrades.is_empty():
				rare_upgrades = upgrade_pool
			var upgrade: Dictionary = rare_upgrades.pick_random().duplicate()
			_map_upgrade_pending = upgrade
			_targeting_map_upgrade = true
			_map_upgrade_return_to = "shop"
			board.targeting_mode = true
			board.targeting_class_req = upgrade.get("class_req", "")
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			board.queue_redraw()
			_restore_squad()
			_show_warning("Apply %s — click a unit" % upgrade.name)
		"epic_upgrade":
			special_shop_overlay.visible = false
			var epic_upgrades := upgrade_pool.filter(func(u): return u.rarity == "Epic")
			if epic_upgrades.is_empty():
				epic_upgrades = upgrade_pool.filter(func(u): return u.rarity == "Rare")
			var upgrade: Dictionary = epic_upgrades.pick_random().duplicate()
			_map_upgrade_pending = upgrade
			_targeting_map_upgrade = true
			_map_upgrade_return_to = "shop"
			board.targeting_mode = true
			board.targeting_class_req = upgrade.get("class_req", "")
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			board.queue_redraw()
			_restore_squad()
			_show_warning("Apply %s — click a unit" % upgrade.name)
		"squad_heal":
			for entry in player_squad:
				if entry.has("stats"):
					entry.stats.max_hp = entry.stats.get("max_hp", 100) + 30
			_show_warning("Squad healed! +30 max HP each")
	_update_ui()

func _on_special_shop_leave() -> void:
	special_shop_overlay.visible = false
	_complete_map_node()

# ── Treasure Overlay ─────────────────────────────────────────

func _build_treasure_overlay() -> void:
	treasure_overlay = ColorRect.new()
	treasure_overlay.color = Color(0, 0, 0, 0.8)
	treasure_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	treasure_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	treasure_overlay.visible = false
	ui_layer.add_child(treasure_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	treasure_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.65, 0.45, 0.85, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "TreasureVBox"
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

func _show_treasure_overlay() -> void:
	map_overlay.visible = false
	var vbox: VBoxContainer = treasure_overlay.find_child("TreasureVBox", true, false)
	for child in vbox.get_children():
		child.queue_free()

	# Pick a random rare/epic upgrade
	var good_upgrades := upgrade_pool.filter(func(u): return u.rarity == "Rare" or u.rarity == "Epic")
	if good_upgrades.is_empty():
		good_upgrades = upgrade_pool
	var upgrade: Dictionary = good_upgrades.pick_random().duplicate()

	var title := Label.new()
	title.text = "Treasure Chest!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.65, 0.45, 0.85))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "You found: %s\n%s" % [upgrade.name, upgrade.desc]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc)

	var btn_row := VBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var apply_btn := Button.new()
	apply_btn.text = "Apply to Unit"
	apply_btn.custom_minimum_size = Vector2(0, 44)
	apply_btn.pressed.connect(func():
		treasure_overlay.visible = false
		_map_upgrade_pending = upgrade
		_targeting_map_upgrade = true
		board.targeting_mode = true
		board.targeting_class_req = upgrade.get("class_req", "")
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		board.queue_redraw()
		_restore_squad()
		_show_warning("Apply %s — click a unit" % upgrade.name)
	)
	btn_row.add_child(apply_btn)

	var gold_amount := randi_range(8, 15)
	var gold_btn := Button.new()
	gold_btn.text = "Take Gold Instead (+%dg)" % gold_amount
	gold_btn.custom_minimum_size = Vector2(0, 44)
	gold_btn.pressed.connect(func():
		treasure_overlay.visible = false
		GameManager.gold += gold_amount
		GameManager.gold_changed.emit(GameManager.gold)
		_show_warning("+%dg gold!" % gold_amount)
		_complete_map_node()
	)
	btn_row.add_child(gold_btn)

	treasure_overlay.visible = true

# ── Event Overlay (Unknown Nodes) ────────────────────────────

const MAP_EVENTS := [
	{"name": "Gold Cache", "desc": "You stumble upon a hidden stash of gold!", "type": "gold"},
	{"name": "Ambush!", "desc": "Enemies spring from the shadows!", "type": "ambush"},
	{"name": "Traveling Healer", "desc": "A kind healer offers to mend your wounds.", "type": "heal"},
	{"name": "Mysterious Stranger", "desc": "A cloaked figure offers a strange enchantment...", "type": "upgrade"},
	{"name": "Cursed Treasure", "desc": "A chest radiates dark energy. Great riches, but at a cost...", "type": "cursed"},
	{"name": "Training Ground", "desc": "Your squad finds an abandoned training yard.", "type": "training"},
	{"name": "Black Market", "desc": "A shady dealer offers rare wares at a discount.", "type": "market"},
]

func _build_event_overlay() -> void:
	event_overlay = ColorRect.new()
	event_overlay.color = Color(0, 0, 0, 0.8)
	event_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	event_overlay.visible = false
	ui_layer.add_child(event_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.border_color = Color(0.4, 0.7, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "EventVBox"
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

func _show_event_overlay() -> void:
	map_overlay.visible = false
	var vbox: VBoxContainer = event_overlay.find_child("EventVBox", true, false)
	for child in vbox.get_children():
		child.queue_free()

	var event: Dictionary = MAP_EVENTS.pick_random()

	var title := Label.new()
	title.text = event["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = event["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var btn_container := VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_container)

	match event["type"]:
		"gold":
			var gold_amount := randi_range(10, 20)
			var btn := Button.new()
			btn.text = "Take the gold (+%dg)" % gold_amount
			btn.custom_minimum_size = Vector2(0, 44)
			btn.pressed.connect(func():
				event_overlay.visible = false
				GameManager.gold += gold_amount
				GameManager.gold_changed.emit(GameManager.gold)
				_show_warning("+%dg gold!" % gold_amount)
				AudioManager.play("buy")
				_complete_map_node()
			)
			btn_container.add_child(btn)
		"ambush":
			var btn := Button.new()
			btn.text = "Fight! (reduced enemy strength)"
			btn.custom_minimum_size = Vector2(0, 44)
			btn.pressed.connect(func():
				event_overlay.visible = false
				# Generate a half-strength battle
				var act: int = _current_map_node.get("act", 1)
				var floor_idx: int = _current_map_node.get("floor", 0)
				var eff_round := MapData.get_effective_round(act, floor_idx)
				var wave := _generate_single_wave(0, eff_round, 0.5)
				wave_options = [wave]
				_on_wave_selected(0)
			)
			btn_container.add_child(btn)
		"heal":
			var btn := Button.new()
			btn.text = "Accept healing (+1 Life)"
			btn.custom_minimum_size = Vector2(0, 44)
			btn.pressed.connect(func():
				event_overlay.visible = false
				GameManager.lives += 1
				GameManager.lives_changed.emit(GameManager.lives)
				_show_warning("+1 Life!")
				AudioManager.play("victory")
				_complete_map_node()
			)
			btn_container.add_child(btn)
		"upgrade":
			var btn := Button.new()
			btn.text = "Accept the enchantment"
			btn.custom_minimum_size = Vector2(0, 44)
			btn.pressed.connect(func():
				event_overlay.visible = false
				var generic_ups := upgrade_pool.filter(func(u): return not u.has("class_req"))
				var upgrade: Dictionary = generic_ups.pick_random().duplicate()
				_map_upgrade_pending = upgrade
				_targeting_map_upgrade = true
				board.targeting_mode = true
				board.targeting_class_req = upgrade.get("class_req", "")
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)
				board.queue_redraw()
				_restore_squad()
				_show_warning("Apply %s — click a unit" % upgrade.name)
			)
			btn_container.add_child(btn)
		"cursed":
			var gold_amount := 15
			var btn_take := Button.new()
			btn_take.text = "Take treasure (+%dg, -1 Life)" % gold_amount
			btn_take.custom_minimum_size = Vector2(0, 44)
			btn_take.pressed.connect(func():
				event_overlay.visible = false
				GameManager.gold += gold_amount
				GameManager.gold_changed.emit(GameManager.gold)
				GameManager.lives -= 1
				GameManager.lives_changed.emit(GameManager.lives)
				_show_warning("+%dg gold, -1 Life!" % gold_amount)
				if GameManager.lives <= 0:
					GameManager.game_over.emit()
				else:
					_complete_map_node()
			)
			btn_container.add_child(btn_take)

			var btn_leave := Button.new()
			btn_leave.text = "Leave it alone"
			btn_leave.custom_minimum_size = Vector2(0, 44)
			btn_leave.pressed.connect(func():
				event_overlay.visible = false
				_complete_map_node()
			)
			btn_container.add_child(btn_leave)
		"training":
			var btn := Button.new()
			btn.text = "Train your squad (+2 damage each)"
			btn.custom_minimum_size = Vector2(0, 44)
			btn.pressed.connect(func():
				event_overlay.visible = false
				for entry in player_squad:
					if entry.has("stats"):
						entry.stats.damage = entry.stats.get("damage", 10) + 2
				_show_warning("All units gained +2 damage!")
				AudioManager.play("upgrade")
				_complete_map_node()
			)
			btn_container.add_child(btn)
		"market":
			# Two rare upgrades at half price
			var rare_upgrades := upgrade_pool.filter(func(u): return u.rarity == "Rare")
			if rare_upgrades.size() < 2:
				rare_upgrades = upgrade_pool
			rare_upgrades.shuffle()
			for i in range(mini(2, rare_upgrades.size())):
				var upgrade: Dictionary = rare_upgrades[i].duplicate()
				var half_cost: int = maxi(1, upgrade.cost / 2)
				var btn := Button.new()
				btn.text = "%s — %dg (50%% off)" % [upgrade.name, half_cost]
				btn.custom_minimum_size = Vector2(0, 40)
				var u := upgrade
				var c := half_cost
				btn.pressed.connect(func():
					if not GameManager.spend_gold(c):
						_show_warning("Not enough gold!")
						return
					event_overlay.visible = false
					AudioManager.play("buy")
					_map_upgrade_pending = u
					_targeting_map_upgrade = true
					_map_upgrade_return_to = "event_market"
					board.targeting_mode = true
					board.targeting_class_req = u.get("class_req", "")
					Input.set_default_cursor_shape(Input.CURSOR_CROSS)
					board.queue_redraw()
					_restore_squad()
					_show_warning("Apply %s — click a unit" % u.name)
				)
				btn_container.add_child(btn)

			var leave_btn := Button.new()
			leave_btn.text = "Leave"
			leave_btn.custom_minimum_size = Vector2(0, 40)
			leave_btn.pressed.connect(func():
				event_overlay.visible = false
				_complete_map_node()
			)
			btn_container.add_child(leave_btn)

	event_overlay.visible = true

# ── Map Upgrade Targeting ────────────────────────────────────

func _apply_map_upgrade_to_unit(unit: Unit) -> void:
	if not _targeting_map_upgrade or _map_upgrade_pending.is_empty():
		return

	var upgrade: Dictionary = _map_upgrade_pending

	# Validate class restriction
	if upgrade.has("class_req") and upgrade.class_req != "" and unit.unit_data.unit_class != upgrade.class_req:
		_show_warning("Wrong unit class!")
		return

	# Check if unit already has this upgrade — level it up
	var existing_upg: Dictionary = {}
	for upg in unit.applied_upgrades:
		if upg.name == upgrade.name:
			existing_upg = upg
			break

	if existing_upg.is_empty():
		if unit.applied_upgrades.size() >= unit.get_max_upgrades():
			_show_warning("Unit has max upgrades!")
			return
		var new_upg := upgrade.duplicate()
		new_upg.level = 1
		unit.applied_upgrades.append(new_upg)
	else:
		existing_upg.level = existing_upg.get("level", 1) + 1

	_apply_stat_buff(unit, upgrade.stat, upgrade.amount)
	AudioManager.play("upgrade")

	_targeting_map_upgrade = false
	_map_upgrade_pending = {}
	board.targeting_class_req = ""
	board.targeting_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	board.select_unit(unit)
	_show_info_panel(unit)
	_update_ui()
	board.queue_redraw()

	# Return to origin overlay or complete the node
	_save_squad()
	var return_to := _map_upgrade_return_to
	_map_upgrade_return_to = ""
	match return_to:
		"shop":
			_show_special_shop_overlay()
		"event_market":
			# Market event: after applying, complete the node
			_complete_map_node()
		_:
			_complete_map_node()

func _cancel_map_upgrade_targeting() -> void:
	if not _targeting_map_upgrade:
		return
	var return_to := _map_upgrade_return_to
	_targeting_map_upgrade = false
	_map_upgrade_pending = {}
	_map_upgrade_return_to = ""
	board.targeting_class_req = ""
	board.targeting_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_update_ui()
	board.queue_redraw()
	# Return to source overlay or complete node
	match return_to:
		"shop":
			_show_special_shop_overlay()
		_:
			_complete_map_node()

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
	var title := "Round %d/%d" % [GameManager.current_round, GameManager.MAX_ROUNDS]
	if ranked_mode:
		title += "  [Ranked]"
	if GameManager.current_round % 5 == 0:
		title += "  —  +1 Life!"
	wave_title.text = title
	wave_dps_label.text = "Your Squad DPS: %.1f" % _get_squad_dps()

	var bm = get_node_or_null("/root/BackendManager")
	if ranked_mode and bm and bm.is_online:
		# Upload current squad snapshot then fetch opponents
		if not player_squad.is_empty():
			var squad_json := SquadSerializer.squad_to_json(player_squad)
			bm.upload_squad_snapshot(squad_json, GameManager.current_round)
		_waiting_for_opponents = true
		bm.fetch_opponents(bm.player_rating, GameManager.current_round)
		# Show overlay with "Searching for opponent..." — no wave cards
		wave_title.text = "Searching for opponent..."
		wave_dps_label.text = ""
		for child in wave_cards_container.get_children():
			child.queue_free()
		wave_overlay.visible = true
	elif ranked_mode:
		# Ranked but backend offline — auto-generate AI opponent, skip picker
		var ai_wave := _generate_single_wave(0)
		ai_wave["ranked_ai_rating"] = bm.player_rating if bm else 1000
		wave_options = [ai_wave]
		_on_wave_selected(0)
	else:
		wave_options = _generate_wave_options()
		_populate_wave_cards()
		wave_overlay.visible = true

	if GameManager.current_round % 5 == 0:
		_show_warning("+1 Life gained!")
		AudioManager.play("victory")

func _show_wave_select_rematch() -> void:
	if ranked_mode or GameManager.is_map_mode:
		# Ranked/map rematch: skip wave picker, auto-select the same wave
		_on_wave_selected(0)
		return
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

func _on_opponents_fetched(opponents: Array) -> void:
	if not _waiting_for_opponents:
		return
	_waiting_for_opponents = false
	_ranked_opponents = opponents

	if ranked_mode:
		# Auto-match: pick the single closest-ELO opponent, skip the picker
		var best_wave := _pick_best_opponent(opponents)
		if best_wave.is_empty():
			# No valid opponents — fall back to AI wave with synthetic rating for ELO
			var ai_wave := _generate_single_wave(0)
			var bm_fallback = get_node_or_null("/root/BackendManager")
			ai_wave["ranked_ai_rating"] = bm_fallback.player_rating if bm_fallback else 1000
			wave_options = [ai_wave]
		else:
			wave_options = [best_wave]
		_on_wave_selected(0)
		return

	if opponents.is_empty():
		# Fallback to AI waves — already generated
		return

	# Build 3 wave options from opponent snapshots (lower/similar/higher ELO)
	var opponent_waves := _build_opponent_wave_options(opponents)
	if opponent_waves.size() >= 3:
		wave_options = opponent_waves
	elif not opponent_waves.is_empty():
		# Fill remaining slots with AI waves
		while opponent_waves.size() < 3:
			opponent_waves.append(_generate_single_wave(0))
		wave_options = opponent_waves
	# Refresh the cards
	_populate_wave_cards()


func _build_opponent_wave_options(opponents: Array) -> Array[Dictionary]:
	if opponents.is_empty():
		return []

	# Sort by rating
	var sorted := opponents.duplicate()
	sorted.sort_custom(func(a, b):
		return a.get("rating_at_time", 1000) < b.get("rating_at_time", 1000)
	)

	var bm_node = get_node_or_null("/root/BackendManager")
	var my_rating: int = bm_node.player_rating if bm_node else 1000
	var options: Array[Dictionary] = []

	# Pick 3 tiers: lower, similar, higher
	var lower: Dictionary = {}
	var similar: Dictionary = {}
	var higher: Dictionary = {}
	var best_similar_dist := 9999

	for opp in sorted:
		var r: int = opp.get("rating_at_time", 1000)
		if r < my_rating - 50 and (lower.is_empty() or r > lower.get("rating_at_time", 0)):
			lower = opp
		elif r > my_rating + 50 and (higher.is_empty() or r < higher.get("rating_at_time", 9999)):
			higher = opp
		var dist: int = abs(r - my_rating)
		if dist < best_similar_dist:
			best_similar_dist = dist
			similar = opp

	# Build wave dicts from the 3 picks
	for pick in [lower, similar, higher]:
		if pick.is_empty():
			continue
		var squad_json = pick.get("squad_json", [])
		if squad_json is String:
			var json := JSON.new()
			if json.parse(squad_json) == OK:
				squad_json = json.data
		if not squad_json is Array or squad_json.is_empty():
			continue

		var opp_name: String = pick.get("player_name", "Unknown")
		var opp_rating: int = pick.get("rating_at_time", 1000)

		# Build enemy text from squad
		var counts: Dictionary = {}
		for entry in squad_json:
			var uc: String = entry.get("unit_class", "?")
			counts[uc] = counts.get(uc, 0) + 1
		var enemy_text := ""
		for key in counts:
			enemy_text += "%dx %s\n" % [counts[key], key]

		# Calculate DPS
		var total_dps := SquadSerializer.calculate_squad_dps(squad_json)

		options.append({
			"name": "%s (ELO: %d)" % [opp_name, opp_rating],
			"strategy": "opponent",
			"enemies": [],
			"total_units": squad_json.size(),
			"total_farms": 0,
			"enemy_text": enemy_text.strip_edges(),
			"is_opponent": true,
			"opponent_squad_json": squad_json,
			"opponent_name": opp_name,
			"opponent_rating": opp_rating,
			"opponent_dps": total_dps,
		})

	return options


func _pick_best_opponent(opponents: Array) -> Dictionary:
	# Returns a single wave dict for the closest-ELO opponent
	if opponents.is_empty():
		return {}
	var bm_node = get_node_or_null("/root/BackendManager")
	var my_rating: int = bm_node.player_rating if bm_node else 1000
	var best: Dictionary = opponents[0]
	var best_dist: int = abs(best.get("rating_at_time", 1000) - my_rating)
	for opp in opponents:
		var dist: int = abs(opp.get("rating_at_time", 1000) - my_rating)
		if dist < best_dist:
			best_dist = dist
			best = opp
	# Build wave dict from this opponent
	var squad_json = best.get("squad_json", [])
	if squad_json is String:
		var json := JSON.new()
		if json.parse(squad_json) == OK:
			squad_json = json.data
	if not squad_json is Array or squad_json.is_empty():
		return {}
	var opp_name: String = best.get("player_name", "Unknown")
	var opp_rating: int = best.get("rating_at_time", 1000)
	var counts: Dictionary = {}
	for entry in squad_json:
		var uc: String = entry.get("unit_class", "?")
		counts[uc] = counts.get(uc, 0) + 1
	var enemy_text := ""
	for key in counts:
		enemy_text += "%dx %s\n" % [counts[key], key]
	var total_dps := SquadSerializer.calculate_squad_dps(squad_json)
	return {
		"name": "%s (ELO: %d)" % [opp_name, opp_rating],
		"strategy": "opponent",
		"enemies": [],
		"total_units": squad_json.size(),
		"total_farms": 0,
		"enemy_text": enemy_text.strip_edges(),
		"is_opponent": true,
		"opponent_squad_json": squad_json,
		"opponent_name": opp_name,
		"opponent_rating": opp_rating,
		"opponent_dps": total_dps,
	}


func _populate_wave_cards() -> void:
	for child in wave_cards_container.get_children():
		child.queue_free()

	for i in range(mini(3, wave_options.size())):
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

		# Strategy title (or opponent name + rating for PvP)
		var title := Label.new()
		if wave.get("is_opponent", false):
			title.text = wave.get("opponent_name", "Unknown")
			title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		else:
			title.text = wave.name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 13)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(title)

		# Show ELO rating for opponent waves
		if wave.get("is_opponent", false):
			var elo_label := Label.new()
			elo_label.text = "ELO: %d" % wave.get("opponent_rating", 1000)
			elo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			elo_label.add_theme_font_size_override("font_size", 11)
			elo_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
			elo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(elo_label)

		# Icon row — one icon per unique enemy class in the wave
		var icon_row := HBoxContainer.new()
		icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
		icon_row.add_theme_constant_override("separation", 4)
		icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var seen_classes: Dictionary = {}
		if wave.get("is_opponent", false):
			# For opponent waves, extract classes from squad_json
			for entry in wave.get("opponent_squad_json", []):
				var uc: String = entry.get("unit_class", "")
				if uc == "" or seen_classes.has(uc):
					continue
				seen_classes[uc] = true
				var udata := SquadSerializer.get_unit_data(uc)
				if udata and udata.texture:
					var tex := TextureRect.new()
					tex.texture = udata.texture
					tex.custom_minimum_size = Vector2(22, 22)
					tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					tex.modulate = CLASS_COLORS.get(uc, Color.WHITE)
					tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
					icon_row.add_child(tex)
		else:
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
		if not wave.get("is_opponent", false):
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
		if wave.get("is_opponent", false):
			total_dps = wave.get("opponent_dps", 0.0)
		else:
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
		if wave.get("is_opponent", false):
			summary.text = "%d units — PvP" % wave.total_units
		else:
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
	options.append(_generate_single_wave(3 + GameManager.current_round * 2 / 3))
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

func _generate_single_wave(extra_budget: int = 0, effective_round: int = -1, budget_mult: float = 1.0) -> Dictionary:
	var round_num: int = effective_round if effective_round > 0 else GameManager.current_round
	# Farm budget: base + round scaling + variance + optional extra for hard waves
	var enemy_farm_budget := int((round_num + 1 + round_num / 5 + randi_range(0, maxi(round_num / 3, 1)) + extra_budget) * budget_mult)

	# Enemy level scales with rounds (faster progression, higher cap)
	var base_level := clampi(ceili(round_num / 2.0) + maxi(round_num - 10, 0) / 3, 1, 12)

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
			var lvl := clampi(base_level + randi_range(-1, 1), 1, 12)
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

	if wave.get("is_opponent", false):
		# PvP: spawn opponent's squad
		current_opponent_rating = wave.get("opponent_rating", 1000)
		current_opponent_name = wave.get("opponent_name", "Unknown")
		battle_enemy_name.text = "vs %s (ELO: %d)" % [current_opponent_name, current_opponent_rating]
		_spawn_opponent_squad(wave.get("opponent_squad_json", []))
	else:
		# AI: spawn procedurally generated enemies
		current_opponent_rating = wave.get("ranked_ai_rating", 0)
		current_opponent_name = "AI Opponent" if current_opponent_rating > 0 else ""
		battle_enemy_name.text = "vs AI Wave (Ranked)" if current_opponent_rating > 0 else "vs AI Wave"
		var enemies: Array = wave.enemies
		var enemy_count: int = enemies.size()
		var wave_strategy: String = wave.get("strategy", "")
		if wave_strategy == "encounter":
			battle_enemy_name.text = "vs " + wave.get("encounter_name", "Elite")
		elif wave_strategy == "ai_simulated":
			battle_enemy_name.text = "vs " + wave.get("name", "AI Squad")
		for i in range(enemy_count):
			var entry: Dictionary = enemies[i]
			var spacing: float = Board.ARENA_HEIGHT / (enemy_count + 1)
			var raw_pos := Vector2(
				randf_range(Board.DIVIDER_X + 60, Board.ARENA_WIDTH - 60),
				spacing * (i + 1)
			)
			var pos := board.snap_to_enemy_grid(raw_pos)
			var override: Dictionary = entry.get("override", {})
			if entry.has("display_name") and not override.has("hero_name"):
				override["hero_name"] = entry.display_name
			if entry.has("ability_key") and entry.ability_key != "" and not override.has("ability_key"):
				override["ability_key"] = entry.ability_key
				override["ability_name"] = entry.get("instance_ability_name", "")
				override["ability_desc"] = entry.get("instance_ability_desc", "")
			var unit := _spawn_unit(entry.data, Unit.Team.ENEMY, pos, override)
			if entry.has("stats"):
				# AI-simulated squad: apply pre-computed stats directly
				var s: Dictionary = entry.stats
				unit.xp = entry.get("xp", 0)
				unit.level = entry.get("level", 1)
				unit.damage = s.damage
				unit.max_hp = s.max_hp
				unit.current_hp = s.max_hp
				unit.attacks_per_second = s.attacks_per_second
				unit.attack_range = s.attack_range
				unit.ability_range = s.get("ability_range", unit.unit_data.ability_range)
				unit.move_speed = s.move_speed
				unit.max_armor = s.get("max_armor", s.armor)
				unit.armor = unit.max_armor
				unit.evasion = s.evasion
				unit.crit_chance = s.crit_chance
				unit.skill_proc_chance = s.skill_proc_chance
				unit.max_mana = s.max_mana
				unit.mana_cost_per_attack = s.mana_cost_per_attack
				unit.ability_cooldown = s.get("ability_cooldown", unit.ability_cooldown)
				unit.mana_regen_per_second = s.mana_regen_per_second
				unit.hp_regen_per_second = s.get("hp_regen_per_second", 0.0)
				# Apply modifier flags
				unit.primed = entry.get("primed", false)
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
				unit.necromancy_stacks = entry.get("necromancy_stacks", 0)
				unit.hellfire = entry.get("hellfire", false)
				unit.corrosive_power = entry.get("corrosive_power", 0)
				var saved_upgrades: Array = entry.get("applied_upgrades", [])
				for upg in saved_upgrades:
					unit.applied_upgrades.append(upg.duplicate())
			else:
				# Legacy level-based scaling (ranked PvP / old waves)
				var lvl: int = entry.get("level", 1)
				if lvl > 1:
					var scale_factor := 1.0 + (lvl - 1) * 0.45
					unit.damage = int(ceil(unit.damage * scale_factor))
					unit.max_hp = int(ceil(unit.max_hp * scale_factor))
					unit.current_hp = unit.max_hp
					unit.armor = int(ceil(unit.armor * scale_factor)) if unit.armor > 0 else 0
					unit.attacks_per_second *= 1.0 + (lvl - 1) * 0.18
				# Apply encounter-specific boss stat multiplier
				var boss_mult: float = entry.get("stat_mult", 1.0)
				if boss_mult > 1.0:
					unit.damage = int(ceil(unit.damage * boss_mult))
					unit.max_hp = int(ceil(unit.max_hp * boss_mult))
					unit.current_hp = unit.max_hp
					unit.armor = int(ceil(unit.armor * boss_mult)) if unit.armor > 0 else 0
					unit.attacks_per_second *= 1.0 + (boss_mult - 1.0) * 0.4
				# Apply encounter modifiers (primed, lifesteal, etc.)
				var mods: Dictionary = entry.get("modifiers", {})
				for key in mods:
					unit.set(key, mods[key])
				# Visual scale-up for boss units
				if entry.get("is_boss_unit", false):
					unit.scale = Vector2(1.3, 1.3)
			unit.queue_redraw()

	_restore_squad()
	if GameManager.is_map_mode:
		_prep_snapshot = {
			"squad": _deep_copy_squad(player_squad),
			"gold": GameManager.gold,
			"farms": GameManager.farms,
			"farm_purchases": GameManager.farm_purchases,
		}
		GameManager.gold_snapshot = GameManager.gold
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
	shop_bar.position = Vector2(30, 530)
	shop_bar.add_theme_constant_override("separation", 5)
	ui_layer.add_child(shop_bar)

	for i in range(HERO_SHOP_SLOTS + UPGRADE_SHOP_SLOTS):
		var btn := Button.new()
		if i < HERO_SHOP_SLOTS:
			btn.custom_minimum_size = Vector2(130, 100)
		else:
			btn.custom_minimum_size = Vector2(150, 100)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_constant_override("icon_max_width", 28)
		btn.clip_contents = true
		var idx := i
		btn.pressed.connect(func(): _on_shop_card_pressed(idx))
		shop_bar.add_child(btn)
		shop_buttons.append(btn)

	# Insert separator after hero cards
	var sep := VSeparator.new()
	shop_bar.add_child(sep)
	shop_bar.move_child(sep, HERO_SHOP_SLOTS)

	# Action icon buttons — stacked vertically at the end of the shop bar
	action_bar = VBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 2)
	action_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shop_bar.add_child(action_bar)

	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(50, 28)
	reroll_button.add_theme_font_size_override("font_size", 13)
	reroll_button.text = "⚄ %dg" % GameManager.REROLL_COST
	reroll_button.tooltip_text = "Re-roll Shop (%dg)" % GameManager.REROLL_COST
	reroll_button.pressed.connect(_on_reroll_pressed)
	action_bar.add_child(reroll_button)

	freeze_button = Button.new()
	freeze_button.custom_minimum_size = Vector2(50, 28)
	freeze_button.add_theme_font_size_override("font_size", 15)
	freeze_button.text = "🔒"
	freeze_button.tooltip_text = "Freeze Shop"
	freeze_button.pressed.connect(_on_freeze_pressed)
	action_bar.add_child(freeze_button)

	sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(50, 28)
	sell_button.add_theme_font_size_override("font_size", 15)
	sell_button.text = "💰"
	sell_button.tooltip_text = "Sell Selected Unit"
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
		var variant: Dictionary = HeroVariants.random_ability(data.unit_class)
		var hero_name: String = HeroVariants.random_name(data.unit_class)
		shop_slots.append({
			"type": "hero", "data": data, "cost": data.farm_cost, "sold": false,
			"ability_key": variant.key, "ability_name": variant.name, "ability_desc": variant.desc,
			"hero_name": hero_name,
		})
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
		# Clear any previous card children
		for child in btn.get_children():
			child.queue_free()
		if slot.sold:
			btn.text = "SOLD"
			btn.disabled = true
		elif slot.type == "hero":
			var data: UnitData = slot.data
			var cls_color: Color = CLASS_COLORS.get(data.unit_class, Color.WHITE)
			btn.text = ""
			btn.icon = null
			btn.disabled = false
			# Colored left border accent with rounded corners
			var hero_style := StyleBoxFlat.new()
			hero_style.bg_color = Color(0.18, 0.18, 0.22)
			hero_style.border_color = cls_color
			hero_style.border_width_left = 3
			hero_style.set_corner_radius_all(6)
			hero_style.set_content_margin_all(0)
			btn.add_theme_stylebox_override("normal", hero_style)
			# Build structured card layout
			var hero_margin := MarginContainer.new()
			hero_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			hero_margin.add_theme_constant_override("margin_left", 6)
			hero_margin.add_theme_constant_override("margin_right", 6)
			hero_margin.add_theme_constant_override("margin_top", 4)
			hero_margin.add_theme_constant_override("margin_bottom", 4)
			hero_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var hero_vbox := VBoxContainer.new()
			hero_vbox.add_theme_constant_override("separation", 1)
			hero_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Row 1: Hero icon (left) + gold cost (right, gold-colored)
			var hero_top := HBoxContainer.new()
			hero_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if data.texture:
				var hero_icon := TextureRect.new()
				hero_icon.texture = data.texture
				hero_icon.custom_minimum_size = Vector2(18, 18)
				hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hero_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				hero_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hero_top.add_child(hero_icon)
			var hero_spacer := Control.new()
			hero_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hero_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hero_top.add_child(hero_spacer)
			var hero_gold := Label.new()
			hero_gold.text = "%dg" % data.farm_cost
			hero_gold.add_theme_font_size_override("font_size", 12)
			hero_gold.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			hero_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hero_top.add_child(hero_gold)
			hero_vbox.add_child(hero_top)
			# Row 2: Class name (centered, class-colored)
			var hero_class_lbl := Label.new()
			hero_class_lbl.text = data.unit_class
			hero_class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hero_class_lbl.add_theme_font_size_override("font_size", 12)
			hero_class_lbl.add_theme_color_override("font_color", cls_color)
			hero_class_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hero_vbox.add_child(hero_class_lbl)
			# Row 3: Hero name (centered, white)
			var hero_name_lbl := Label.new()
			hero_name_lbl.text = slot.hero_name
			hero_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hero_name_lbl.add_theme_font_size_override("font_size", 11)
			hero_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hero_vbox.add_child(hero_name_lbl)
			# Row 4: House icons row (centered) — one solid house per pop_cost
			var house_row := HBoxContainer.new()
			house_row.alignment = BoxContainer.ALIGNMENT_CENTER
			house_row.add_theme_constant_override("separation", 2)
			house_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for _h in range(data.pop_cost):
				var h_icon := TextureRect.new()
				h_icon.texture = HOUSE_SOLID
				h_icon.custom_minimum_size = Vector2(14, 14)
				h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				h_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				h_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				house_row.add_child(h_icon)
			hero_vbox.add_child(house_row)
			# Row 5: Merge button (if same-class unit exists on board)
			if _find_player_unit_by_class(data.unit_class):
				var merge_btn := Button.new()
				merge_btn.text = "Merge as EXP"
				merge_btn.add_theme_font_size_override("font_size", 9)
				merge_btn.custom_minimum_size = Vector2(0, 18)
				merge_btn.mouse_filter = Control.MOUSE_FILTER_STOP
				var merge_style := StyleBoxFlat.new()
				merge_style.bg_color = Color(0.25, 0.15, 0.15)
				merge_style.border_color = Color(0.8, 0.3, 0.3, 0.6)
				merge_style.set_border_width_all(1)
				merge_style.set_corner_radius_all(3)
				merge_style.set_content_margin_all(2)
				merge_btn.add_theme_stylebox_override("normal", merge_style)
				var merge_hover := StyleBoxFlat.new()
				merge_hover.bg_color = Color(0.35, 0.18, 0.18)
				merge_hover.border_color = Color(1.0, 0.4, 0.4, 0.8)
				merge_hover.set_border_width_all(1)
				merge_hover.set_corner_radius_all(3)
				merge_hover.set_content_margin_all(2)
				merge_btn.add_theme_stylebox_override("hover", merge_hover)
				merge_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
				merge_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.8))
				var merge_idx := i
				merge_btn.pressed.connect(func(): _on_merge_button_pressed(merge_idx))
				hero_vbox.add_child(merge_btn)
			hero_margin.add_child(hero_vbox)
			btn.add_child(hero_margin)
		else:
			var upgrade: Dictionary = slot.data
			btn.text = ""
			btn.icon = null
			btn.disabled = false
			# Card style — rounded, dark bg
			var rarity_color: Color = RARITY_COLORS.get(upgrade.rarity, Color.WHITE)
			var card_style := StyleBoxFlat.new()
			card_style.bg_color = Color(0.14, 0.14, 0.18)
			card_style.set_corner_radius_all(6)
			card_style.set_content_margin_all(0)
			btn.add_theme_stylebox_override("normal", card_style)
			# Build card layout
			var margin := MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			margin.add_theme_constant_override("margin_left", 6)
			margin.add_theme_constant_override("margin_right", 6)
			margin.add_theme_constant_override("margin_top", 4)
			margin.add_theme_constant_override("margin_bottom", 4)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var vbox := VBoxContainer.new()
			vbox.add_theme_constant_override("separation", 1)
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Row 1: Gold cost (right-aligned) over name row
			var top_row := HBoxContainer.new()
			top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Buff icon (left)
			var stat_key: String = upgrade.get("stat", "")
			var icon_tex: Texture2D = null
			if upgrade.rarity == "Epic" and BUFF_ICONS.has("_epic"):
				icon_tex = BUFF_ICONS["_epic"]
			elif upgrade.rarity == "Rare" and upgrade.has("class_req") and BUFF_ICONS.has("_rare"):
				icon_tex = BUFF_ICONS["_rare"]
			elif BUFF_ICONS.has(stat_key):
				icon_tex = BUFF_ICONS[stat_key]
			if icon_tex:
				var icon_rect := TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(18, 18)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				top_row.add_child(icon_rect)
			var top_spacer := Control.new()
			top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_row.add_child(top_spacer)
			var gold_label := Label.new()
			gold_label.text = "%dg" % upgrade.cost
			gold_label.add_theme_font_size_override("font_size", 12)
			gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_row.add_child(gold_label)
			vbox.add_child(top_row)
			# Row 2: Buff name (centered, bold)
			var name_label := Label.new()
			name_label.text = upgrade.name
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 12)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(name_label)
			# Row 3: Rarity colored line
			var rarity_line := ColorRect.new()
			rarity_line.color = rarity_color
			rarity_line.custom_minimum_size = Vector2(0, 2)
			rarity_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(rarity_line)
			# Row 4: Description (word-wrapped)
			var desc_label := Label.new()
			desc_label.text = upgrade.desc
			if upgrade.has("class_req"):
				desc_label.text += "\n(%s only)" % upgrade.class_req
			desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(desc_label)
			margin.add_child(vbox)
			btn.add_child(margin)
		if i == _selected_shop_slot and not slot.sold:
			btn.modulate = btn.modulate.lightened(0.35)
		# Freeze lock overlay on unsold items
		if shop_frozen and not slot.sold:
			var lock_overlay := ColorRect.new()
			lock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lock_overlay.color = Color(0.7, 0.85, 1.0, 0.15)
			lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(lock_overlay)
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒"
			lock_lbl.add_theme_font_size_override("font_size", 22)
			lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock_lbl.modulate = Color(1, 1, 1, 0.4)
			btn.add_child(lock_lbl)

	reroll_button.text = "⚄ %dg" % GameManager.REROLL_COST
	reroll_button.disabled = GameManager.gold < GameManager.REROLL_COST
	_update_freeze_display()

func _on_shop_card_pressed(idx: int) -> void:
	if _targeting_upgrade or _targeting_merge:
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

func _on_merge_button_pressed(idx: int) -> void:
	if _targeting_upgrade or _targeting_merge:
		return
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if idx >= shop_slots.size():
		return
	var slot: Dictionary = shop_slots[idx]
	if slot.sold:
		return
	var data: UnitData = slot.data
	var matches := _find_player_units_by_class(data.unit_class)
	if matches.is_empty():
		_show_warning("No %s to merge into!" % data.unit_class)
		return
	if matches.size() == 1:
		if not GameManager.spend_gold(slot.cost):
			_show_warning("Not enough gold!")
			return
		_grant_xp(matches[0], 1)
		slot.sold = true
		board.select_unit(matches[0])
		_show_info_panel(matches[0])
		_update_shop_display()
		_update_ui()
		AudioManager.play("buy")
	else:
		if not GameManager.spend_gold(slot.cost):
			_show_warning("Not enough gold!")
			return
		slot.sold = true
		_targeting_merge = true
		_pending_merge_slot = idx
		board.targeting_class_req = data.unit_class
		board.targeting_mode = true
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		_show_warning("Click a %s to merge into" % data.unit_class)
		_update_shop_display()
		_update_ui()
		board.queue_redraw()
		AudioManager.play("buy")

func _buy_hero(idx: int) -> void:
	var slot: Dictionary = shop_slots[idx]
	var data: UnitData = slot.data

	# Spawn new unit — check farm budget
	if _get_farms_used() + data.pop_cost > GameManager.farms:
		_show_warning("Not enough houses!")
		return
	if not GameManager.spend_gold(slot.cost):
		_show_warning("Not enough gold!")
		return

	var default_pos := board.snap_to_grid(Vector2(
		randf_range(60, Board.DIVIDER_X - 60),
		randf_range(60, Board.ARENA_HEIGHT - 60)
	))
	_spawn_unit(data, Unit.Team.PLAYER, default_pos, slot)
	slot.sold = true
	_update_shop_display()
	_update_ui()
	AudioManager.play("buy")

func _find_player_unit_by_class(unit_class: String) -> Unit:
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		if unit.unit_data.unit_class == unit_class:
			return unit
	return null

func _find_player_units_by_class(unit_class: String) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		if unit.unit_data.unit_class == unit_class:
			result.append(unit)
	return result

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

func _apply_pending_merge(unit: Unit) -> void:
	var slot: Dictionary = shop_slots[_pending_merge_slot]
	var required_class: String = slot.data.unit_class

	if unit.unit_data.unit_class != required_class:
		_show_warning("Must be a %s!" % required_class)
		return

	_grant_xp(unit, 1)

	_targeting_merge = false
	_pending_merge_slot = -1
	board.targeting_class_req = ""
	board.targeting_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	board.select_unit(unit)
	_show_info_panel(unit)
	_update_shop_display()
	_update_ui()
	board.queue_redraw()

func _cancel_merge_targeting() -> void:
	if not _targeting_merge:
		return
	var slot: Dictionary = shop_slots[_pending_merge_slot]
	# Refund gold and notify UI
	GameManager.gold += slot.cost
	GameManager.gold_changed.emit(GameManager.gold)
	slot.sold = false

	_targeting_merge = false
	_pending_merge_slot = -1
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

func _hide_shop() -> void:
	shop_bar.visible = false
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
		freeze_button.text = "🔓"
		freeze_button.modulate = Color(0.5, 0.8, 1.0)
		freeze_button.tooltip_text = "Unfreeze Shop"
	else:
		freeze_button.text = "🔒"
		freeze_button.modulate = Color(1, 1, 1)
		freeze_button.tooltip_text = "Freeze Shop"

# ── Sell Upgrade ─────────────────────────────────────────────

func _sell_upgrade(unit: Unit, upgrade_name: String) -> void:
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	var upg_idx := -1
	for i in range(unit.applied_upgrades.size()):
		if unit.applied_upgrades[i].name == upgrade_name:
			upg_idx = i
			break
	if upg_idx < 0:
		return
	var upg: Dictionary = unit.applied_upgrades[upg_idx]
	var level: int = upg.get("level", 1)
	var total_cost: int = upg.cost * level
	var refund := int(total_cost * 0.75)
	# Reverse stat changes (once per level)
	for _lv in range(level):
		_remove_stat_buff(unit, upg.stat, upg.amount)
	unit.applied_upgrades.remove_at(upg_idx)
	GameManager.gold += refund
	GameManager.gold_changed.emit(GameManager.gold)
	unit.queue_redraw()
	board.queue_redraw()
	_show_info_panel(unit)
	_update_ui()
	AudioManager.play("sell")


func _remove_stat_buff(unit: Unit, stat_key: String, amount: float) -> void:
	match stat_key:
		"damage":
			unit.damage = maxi(unit.damage - int(amount), 0)
		"attacks_per_second":
			unit.attacks_per_second = maxf(unit.attacks_per_second - amount, 0.1)
		"max_hp":
			unit.max_hp = maxi(unit.max_hp - int(amount), 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
		"max_mana":
			unit.max_mana = maxi(unit.max_mana - int(amount), 0)
			unit._update_mana_bar()
		"armor":
			unit.armor = maxi(unit.armor - int(amount), 0)
			unit.max_armor = maxi(unit.max_armor - int(amount), 0)
			unit._update_armor_bar()
		"evasion":
			unit.evasion = maxf(unit.evasion - amount, 0.0)
		"attack_range":
			unit.attack_range = maxf(unit.attack_range - amount, 0.0)
		"ability_range":
			unit.ability_range = maxf(unit.ability_range - amount, 0.0)
		"move_speed":
			unit.move_speed = maxf(unit.move_speed - amount, 0.0)
		"crit_chance":
			unit.crit_chance = maxf(unit.crit_chance - amount, 0.0)
		"skill_proc_chance":
			unit.skill_proc_chance = maxf(unit.skill_proc_chance - amount, 0.0)
		"ability_cooldown":
			unit.ability_cooldown -= amount
		"necromancy":
			unit.necromancy_stacks = maxi(unit.necromancy_stacks - int(amount), 0)
		"primed":
			unit.primed = false
		"corrosive":
			unit.corrosive_power = maxi(unit.corrosive_power - int(amount), 0)
		"thorns_slow":
			unit.thorns_slow = false
		"lifesteal":
			unit.lifesteal_pct = maxf(unit.lifesteal_pct - amount, 0.0)
		"berserk":
			unit.damage = maxi(unit.damage - 6, 0)
			unit.attacks_per_second = maxf(unit.attacks_per_second - 0.4, 0.1)
			var hp_restore := int(float(unit.max_hp) / 0.7 * 0.3)
			unit.max_hp += hp_restore
			unit.current_hp = mini(unit.current_hp + hp_restore, unit.max_hp)
			unit.queue_redraw()
		"last_stand":
			unit.last_stand = false
			unit.last_stand_active = false
		"relentless":
			unit.relentless = false
		"sepsis":
			unit.sepsis_spread = maxi(unit.sepsis_spread - int(amount), 0)
		"living_shield":
			unit.living_shield_max = maxi(unit.living_shield_max - int(amount), 0)
			unit.living_shield_hp = mini(unit.living_shield_hp, unit.living_shield_max)
		"invincible":
			unit.invincible_max = maxi(unit.invincible_max - int(amount), 0)
			unit.invincible_charges = mini(unit.invincible_charges, unit.invincible_max)
			unit.evasion = maxf(unit.evasion - 5.0, 0.0)
		"haymaker":
			unit.haymaker_counter = 0
		"venom_arrow":
			unit.poison_power = maxi(unit.poison_power - int(amount), 0)
		"war_paint":
			unit.damage = maxi(unit.damage - 3, 0)
			unit.max_hp = maxi(unit.max_hp - 10, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
		"shadow_cloak":
			unit.evasion = maxf(unit.evasion - 5.0, 0.0)
			unit.crit_chance = maxf(unit.crit_chance - 3.0, 0.0)
		"thick_plate":
			unit.armor = maxi(unit.armor - 10, 0)
			unit.max_armor = maxi(unit.max_armor - 10, 0)
			unit._update_armor_bar()
			unit.max_hp = maxi(unit.max_hp - 15, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
		"dark_sigil":
			unit.damage = maxi(unit.damage - 3, 0)
			unit.max_mana = maxi(unit.max_mana - 2, 0)
			unit._update_mana_bar()
		"sacred_blessing":
			unit.max_hp = maxi(unit.max_hp - 15, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
			unit.max_mana = maxi(unit.max_mana - 2, 0)
			unit._update_mana_bar()
		"herbal_brew":
			unit.damage = maxi(unit.damage - 3, 0)
			unit.skill_proc_chance = maxf(unit.skill_proc_chance - 3.0, 0.0)
		"shield_of_faith":
			unit.armor = maxi(unit.armor - 8, 0)
			unit.max_armor = maxi(unit.max_armor - 8, 0)
			unit.armor_effectiveness = maxf(unit.armor_effectiveness - 0.1, 0.0)
			unit._update_armor_bar()
		"soul_binding":
			unit.necromancy_stacks = maxi(unit.necromancy_stacks - 1, 0)
			unit.max_hp = maxi(unit.max_hp - 10, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
		"blood_rage":
			unit.damage = maxi(unit.damage - 5, 0)
			unit.attacks_per_second = maxf(unit.attacks_per_second - 0.2, 0.1)
		"deadeye":
			unit.damage = maxi(unit.damage - 8, 0)
			unit.attack_range = maxf(unit.attack_range - 80, 0.0)
		"phantom_step":
			unit.evasion = maxf(unit.evasion - 10, 0.0)
			unit.crit_chance = maxf(unit.crit_chance - 10, 0.0)
		"fortress":
			unit.armor = maxi(unit.armor - 25, 0)
			unit.max_armor = maxi(unit.max_armor - 25, 0)
			unit._update_armor_bar()
			unit.max_hp = maxi(unit.max_hp - 40, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
		"soul_rend":
			unit.damage = maxi(unit.damage - 8, 0)
			unit.max_mana = maxi(unit.max_mana - 3, 0)
			unit._update_mana_bar()
		"hellfire":
			unit.hellfire = false
		"divine_covenant":
			unit.max_hp = maxi(unit.max_hp - 30, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
			unit.max_mana = maxi(unit.max_mana - 3, 0)
			unit._update_mana_bar()
		"toxic_mastery":
			unit.damage = maxi(unit.damage - 5, 0)
			unit.skill_proc_chance = maxf(unit.skill_proc_chance - 5, 0.0)
		"holy_vanguard":
			unit.armor = maxi(unit.armor - 15, 0)
			unit.max_armor = maxi(unit.max_armor - 15, 0)
			unit.armor_effectiveness = maxf(unit.armor_effectiveness - 0.25, 0.0)
			unit._update_armor_bar()
			unit.damage = maxi(unit.damage - 3, 0)
		"rampage":
			unit.damage = maxi(unit.damage - 10, 0)
			unit.attacks_per_second = maxf(unit.attacks_per_second - 0.3, 0.1)
			unit.max_hp = maxi(unit.max_hp - 20, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
		"hawkeye":
			unit.damage = maxi(unit.damage - 12, 0)
			unit.attack_range = maxf(unit.attack_range - 120, 0.0)
			unit.crit_chance = maxf(unit.crit_chance - 8, 0.0)
		"deaths_embrace":
			unit.evasion = maxf(unit.evasion - 15, 0.0)
			unit.crit_chance = maxf(unit.crit_chance - 15, 0.0)
			unit.damage = maxi(unit.damage - 5, 0)
		"bastion":
			unit.armor = maxi(unit.armor - 40, 0)
			unit.max_armor = maxi(unit.max_armor - 40, 0)
			unit._update_armor_bar()
			unit.max_hp = maxi(unit.max_hp - 60, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
			unit.damage = maxi(unit.damage - 2, 0)
		"dark_pact":
			unit.damage = maxi(unit.damage - 15, 0)
			unit.max_mana = maxi(unit.max_mana - 5, 0)
			unit._update_mana_bar()
		"ascension":
			unit.max_hp = maxi(unit.max_hp - 50, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
			unit.max_mana = maxi(unit.max_mana - 5, 0)
			unit._update_mana_bar()
			unit.damage = maxi(unit.damage - 5, 0)
		"plague_lord":
			unit.damage = maxi(unit.damage - 10, 0)
			unit.skill_proc_chance = maxf(unit.skill_proc_chance - 8, 0.0)
			unit.armor = maxi(unit.armor - 15, 0)
			unit.max_armor = maxi(unit.max_armor - 15, 0)
			unit._update_armor_bar()
		"divine_bulwark":
			unit.armor = maxi(unit.armor - 25, 0)
			unit.max_armor = maxi(unit.max_armor - 25, 0)
			unit.armor_effectiveness = maxf(unit.armor_effectiveness - 0.5, 0.0)
			unit._update_armor_bar()
			unit.max_hp = maxi(unit.max_hp - 40, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()
			unit.damage = maxi(unit.damage - 5, 0)
		"legion_master":
			unit.legion_master = false
			unit.necromancy_stacks = maxi(unit.necromancy_stacks - 2, 0)
			unit.max_hp = maxi(unit.max_hp - 30, 1)
			unit.current_hp = mini(unit.current_hp, unit.max_hp)
			unit.queue_redraw()

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
			unit.queue_redraw()
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
		"ability_cooldown":
			unit.ability_cooldown = maxf(unit.ability_cooldown + amount, 0.5)
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
			unit.queue_redraw()
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
			unit.queue_redraw()
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
			unit.queue_redraw()
		"dark_sigil":
			unit.damage += 3
			unit.max_mana += 2
			unit._update_mana_bar()
		"sacred_blessing":
			unit.max_hp += 15
			unit.current_hp += 15
			unit.queue_redraw()
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
			unit.queue_redraw()
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
			unit.queue_redraw()
		"soul_rend":
			unit.damage += 8
			unit.max_mana += 3
			unit._update_mana_bar()
		"hellfire":
			unit.hellfire = true
		"divine_covenant":
			unit.max_hp += 30
			unit.current_hp += 30
			unit.queue_redraw()
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
			unit.queue_redraw()
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
			unit.queue_redraw()
			unit.damage += 2
		"dark_pact":
			unit.damage += 15
			unit.max_mana += 5
			unit._update_mana_bar()
		"ascension":
			unit.max_hp += 50
			unit.current_hp += 50
			unit.queue_redraw()
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
			unit.queue_redraw()
			unit.damage += 5
		"legion_master":
			unit.legion_master = true
			unit.necromancy_stacks += 2
			unit.max_hp += 30
			unit.current_hp += 30
			unit.queue_redraw()
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

	# Percentage boost per XP gained (~12% across core stats)
	for i in range(xp_gained):
		target.damage = maxi(target.damage + 1, int(ceil(target.damage * 1.12)))
		target.max_hp = maxi(target.max_hp + 5, int(ceil(target.max_hp * 1.12)))
		target.attacks_per_second *= 1.10
		target.attack_range = maxf(target.attack_range + 2.0, target.attack_range * 1.05)
		target.move_speed = maxf(target.move_speed + 1.0, target.move_speed * 1.05)
		if target.max_armor > 0:
			target.armor = maxi(target.armor + 1, int(ceil(target.armor * 1.12)))
			target.max_armor = maxi(target.max_armor + 1, int(ceil(target.max_armor * 1.12)))
		target.evasion += 1.0
		target.crit_chance += 1.0
		target.skill_proc_chance += 0.5
		target.max_mana += 2

	# Level-up loop (major power spike ~28% on core stats)
	while target.xp >= Unit.XP_TO_LEVEL:
		target.xp -= Unit.XP_TO_LEVEL
		target.level += 1
		target.damage = maxi(target.damage + 2, int(ceil(target.damage * 1.28)))
		target.max_hp = maxi(target.max_hp + 10, int(ceil(target.max_hp * 1.28)))
		target.attacks_per_second *= 1.20
		target.attack_range *= 1.08
		target.move_speed *= 1.08
		if target.armor > 0:
			target.armor = maxi(target.armor + 2, int(ceil(target.armor * 1.25)))
		target.evasion += 3.0
		target.crit_chance += 3.0
		target.skill_proc_chance += 2.0
		target.max_mana += 3

	target.current_hp = target.max_hp
	target.current_mana = 0

	# Update visuals
	target.queue_redraw()
	target.update_scale()

# ── Squad Persistence ───────────────────────────────────────

func _save_squad() -> void:
	var board_units := board.get_units_on_team(Unit.Team.PLAYER)
	if board_units.is_empty():
		return  # Don't overwrite existing squad data when board is empty (e.g. wave select phase)
	player_squad.clear()
	for unit in board_units:
		if unit.is_summoned:
			continue
		var saved_upgrades: Array[Dictionary] = []
		for upg in unit.applied_upgrades:
			saved_upgrades.append(upg.duplicate())
		var saved_pos: Vector2 = _pre_battle_positions.get(unit.display_name, unit.position)
		player_squad.append({
			"data": unit.unit_data,
			"position": saved_pos,
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
				"ability_cooldown": unit.ability_cooldown,
				"mana_regen_per_second": unit.mana_regen_per_second - unit.survival_mana_regen_bonus,
				"hp_regen_per_second": unit.hp_regen_per_second - unit.survival_hp_regen_bonus,
			}
		})

func _deep_copy_squad(squad: Array) -> Array:
	var copy: Array = []
	for entry in squad:
		copy.append(entry.duplicate(true))
	return copy

func _restore_squad() -> void:
	# Clear existing player units to prevent duplication (e.g. shop buying multiple upgrades)
	for existing in board.get_units_on_team(Unit.Team.PLAYER):
		board.remove_unit(existing)
		existing.queue_free()
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
			unit.armor = unit.max_armor
			unit.evasion = s.evasion
			unit.crit_chance = s.crit_chance
			unit.skill_proc_chance = s.skill_proc_chance
			unit.max_mana = s.max_mana
			unit.current_mana = 0
			unit.mana_cost_per_attack = s.mana_cost_per_attack
			unit.ability_cooldown = s.get("ability_cooldown", unit.ability_cooldown)
			unit.mana_regen_per_second = s.mana_regen_per_second + unit.survival_mana_regen_bonus
			unit.hp_regen_per_second = s.get("hp_regen_per_second", 0.0) + unit.survival_hp_regen_bonus
			unit.queue_redraw()
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

# ── Encounter Helpers ──────────────────────────────────────

func _get_unit_data_for_class(unit_class: String) -> UnitData:
	for data in hero_pool:
		if data.unit_class == unit_class:
			return data
	return null

func _find_ability_variant(unit_class: String, ability_key: String) -> Dictionary:
	var variants: Array = HeroVariants.ABILITY_VARIANTS.get(unit_class, [])
	for v in variants:
		if v.key == ability_key:
			return v
	return {}

func _build_encounter_wave(encounter: Dictionary, eff_round: int) -> Dictionary:
	var base_level := clampi(ceili(eff_round / 2.0) + maxi(eff_round - 10, 0) / 3, 1, 12)
	var enemies: Array[Dictionary] = []
	var unit_descs: PackedStringArray = []

	for unit_def in encounter.units:
		var data := _get_unit_data_for_class(unit_def["class"])
		if not data:
			continue
		var lvl: int = base_level + unit_def.get("level_offset", 0)

		var override := {"hero_name": unit_def.get("hero_name", "")}
		var ability_key: String = unit_def.get("ability_key", "")
		if ability_key != "":
			override["ability_key"] = ability_key
			var variant := _find_ability_variant(unit_def["class"], ability_key)
			if not variant.is_empty():
				override["ability_name"] = variant.name
				override["ability_desc"] = variant.desc

		enemies.append({
			"data": data,
			"level": lvl,
			"override": override,
			"modifiers": unit_def.get("modifiers", {}),
			"is_boss_unit": unit_def.get("is_boss_unit", false),
			"stat_mult": unit_def.get("stat_mult", 1.0),
		})
		unit_descs.append(unit_def.get("hero_name", data.unit_class))

	return {
		"name": encounter.name,
		"encounter_name": encounter.name,
		"strategy": "encounter",
		"enemies": enemies,
		"total_units": enemies.size(),
		"total_farms": 0,
		"enemy_text": ", ".join(unit_descs),
	}

# ── Unit Spawning ───────────────────────────────────────────

func _spawn_unit(data: UnitData, team: Unit.Team, pos: Vector2, override: Dictionary = {}) -> Unit:
	var unit: Unit = unit_scene.instantiate()
	unit.setup(data, team, pos)
	# Use overrides if provided, otherwise randomize
	unit.display_name = override.get("hero_name", HeroVariants.random_name(data.unit_class))
	var variant: Dictionary = HeroVariants.random_ability(data.unit_class)
	unit.ability_key = override.get("ability_key", variant.key)
	unit.instance_ability_name = override.get("ability_name", variant.name)
	unit.instance_ability_desc = override.get("ability_desc", variant.desc)
	board.add_unit(unit)
	return unit

## Spawn an opponent's squad from their snapshot JSON.
## Mirrors X positions to the enemy half of the board, restores full stats.
func _spawn_opponent_squad(squad_json: Array) -> void:
	var entries := SquadSerializer.json_to_wave_enemies(squad_json)
	var count := entries.size()
	for i in range(count):
		var entry: Dictionary = entries[i]
		var data: UnitData = entry.get("data")
		if not data:
			continue
		# Mirror player position to enemy half:
		# Original X is in [0, DIVIDER_X] → mirror to [DIVIDER_X, ARENA_WIDTH]
		var orig_pos: Vector2 = entry.get("position", Vector2.ZERO)
		var mirrored_x := Board.ARENA_WIDTH - orig_pos.x
		var mirrored_pos := Vector2(mirrored_x, orig_pos.y)
		# Clamp to enemy half and snap to grid
		mirrored_pos.x = clampf(mirrored_pos.x, Board.DIVIDER_X + 30, Board.ARENA_WIDTH - 30)
		mirrored_pos.y = clampf(mirrored_pos.y, 30, Board.ARENA_HEIGHT - 30)
		var pos := board.snap_to_enemy_grid(mirrored_pos)
		var unit := _spawn_unit(data, Unit.Team.ENEMY, pos)

		# Restore per-instance identity
		if entry.has("display_name") and entry.display_name != "":
			unit.display_name = entry.display_name
		if entry.has("ability_key") and entry.ability_key != "":
			unit.ability_key = entry.ability_key
		if entry.has("instance_ability_name"):
			unit.instance_ability_name = entry.instance_ability_name
		if entry.has("instance_ability_desc"):
			unit.instance_ability_desc = entry.instance_ability_desc

		# Restore buff properties
		unit.necromancy_stacks = entry.get("necromancy_stacks", 0)
		unit.primed = entry.get("primed", false)
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

		# Restore full stats from snapshot
		if entry.has("stats"):
			var s: Dictionary = entry.stats
			unit.damage = s.get("damage", unit.damage)
			unit.max_hp = s.get("max_hp", unit.max_hp)
			unit.current_hp = unit.max_hp
			unit.attacks_per_second = s.get("attacks_per_second", unit.attacks_per_second)
			unit.attack_range = s.get("attack_range", unit.attack_range)
			unit.ability_range = s.get("ability_range", unit.unit_data.ability_range)
			unit.move_speed = s.get("move_speed", unit.move_speed)
			unit.max_armor = s.get("max_armor", s.get("armor", unit.armor))
			unit.armor = unit.max_armor
			unit.evasion = s.get("evasion", unit.evasion)
			unit.crit_chance = s.get("crit_chance", unit.crit_chance)
			unit.skill_proc_chance = s.get("skill_proc_chance", unit.skill_proc_chance)
			unit.max_mana = s.get("max_mana", unit.max_mana)
			unit.current_mana = 0
			unit.mana_cost_per_attack = s.get("mana_cost_per_attack", unit.mana_cost_per_attack)
			unit.mana_regen_per_second = s.get("mana_regen_per_second", unit.mana_regen_per_second)
			unit.hp_regen_per_second = s.get("hp_regen_per_second", 0.0)
			unit.queue_redraw()
			unit.update_scale()


func _on_summon_requested(data: UnitData, team: Unit.Team, pos: Vector2, summoner: Unit) -> void:
	var archer := _spawn_unit(data, team, pos)
	archer.is_summoned = true
	# Summoned archers are weaker than recruited ones (75% base stats)
	archer.damage = int(ceil(archer.damage * 0.75))
	archer.max_hp = int(ceil(archer.max_hp * 0.75))
	archer.current_hp = archer.max_hp
	archer.attacks_per_second *= 0.9
	archer.queue_redraw()
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
		archer.queue_redraw()
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
		archer.queue_redraw()
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
			archer.queue_redraw()
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
			archer.queue_redraw()
	# Legion Master: summoned units get +5 dmg, +30 HP
	if summoner.legion_master:
		archer.damage += 5
		archer.max_hp += 30
		archer.current_hp = mini(archer.current_hp + 30, archer.max_hp)
		archer.queue_redraw()

# ── Input (Drag & Drop + Selection) ────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# ESC to show quit dialog (when nothing else is active)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if quit_overlay.visible:
			quit_overlay.visible = false
			return
		if _targeting_map_upgrade:
			_cancel_map_upgrade_targeting()
			return
		var phase := GameManager.current_phase
		if phase == GameManager.Phase.MAP or phase == GameManager.Phase.WAVE_SELECT or (phase == GameManager.Phase.PREP and _selected_shop_slot < 0 and not _targeting_upgrade and not _targeting_merge):
			quit_overlay.visible = true
			return

	if GameManager.current_phase == GameManager.Phase.MAP and not _targeting_map_upgrade:
		return
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

	# Cancel map upgrade targeting on right-click
	if _targeting_map_upgrade:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_map_upgrade_targeting()
			return

	# Cancel upgrade/merge targeting on right-click or Escape
	if _targeting_upgrade:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_upgrade_targeting()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_upgrade_targeting()
			return
	if _targeting_merge:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_merge_targeting()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_merge_targeting()
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
	# Map upgrade targeting: accept clicks on player units
	if _targeting_map_upgrade:
		var clicked_unit := board.get_unit_at(local_pos)
		if clicked_unit and clicked_unit.team == Unit.Team.PLAYER:
			_apply_map_upgrade_to_unit(clicked_unit)
		return

	# Upgrade targeting: only accept clicks on player units
	if _targeting_upgrade:
		var clicked_unit := board.get_unit_at(local_pos)
		if clicked_unit and clicked_unit.team == Unit.Team.PLAYER:
			_apply_pending_upgrade(clicked_unit)
		return

	# Merge targeting: only accept clicks on matching-class player units
	if _targeting_merge:
		var clicked_unit := board.get_unit_at(local_pos)
		if clicked_unit and clicked_unit.team == Unit.Team.PLAYER:
			_apply_pending_merge(clicked_unit)
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
	if _targeting_upgrade or _targeting_merge:
		return
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	if board.get_units_on_team(Unit.Team.PLAYER).is_empty():
		_show_warning("Place units first!")
		return
	_cancel_shop_selection()
	# Save pre-battle positions so post-combat save restores units to their prep positions
	_pre_battle_positions.clear()
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		_pre_battle_positions[unit.display_name] = unit.position
	_save_squad()
	# Upload squad snapshot if ranked mode
	var bm_ready = get_node_or_null("/root/BackendManager")
	if ranked_mode and bm_ready and bm_ready.is_online:
		var squad_json := SquadSerializer.squad_to_json(player_squad)
		bm_ready.upload_squad_snapshot(squad_json, GameManager.current_round)
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
	AudioManager.play_music("battle_music")

func _on_combat_ended(player_won: bool) -> void:
	AudioManager.stop_music()
	_apply_survival_regen_bonuses()
	GameManager.end_battle(player_won)

	# ELO calculation for ranked PvP
	var elo_text := ""
	var bm_elo = get_node_or_null("/root/BackendManager")
	if ranked_mode and current_opponent_rating > 0 and bm_elo:
		var old_rating: int = bm_elo.player_rating
		var new_rating := EloCalculator.new_rating(old_rating, current_opponent_rating, player_won)
		elo_text = " (%s ELO)" % EloCalculator.rating_change_text(old_rating, current_opponent_rating, player_won)
		bm_elo.update_rating(new_rating)
		bm_elo.update_win_loss(player_won)

	var vs_text := " vs %s" % current_opponent_name if current_opponent_name != "" else ""
	var gold_won: int = 0
	var bounty_gold: int = combat_system.kill_bounty_gold
	var hero_income: int = 0
	if player_won:
		# Add bonus gold now so interest calculation includes it
		var bonus: int = _pending_bonus_gold
		_pending_bonus_gold = 0
		hero_income = GameManager.calculate_hero_income(player_squad)
		var extra := bonus + bounty_gold + hero_income
		if extra > 0:
			GameManager.gold += extra
			GameManager.gold_changed.emit(GameManager.gold)
		# Preview upcoming income (advance_round will add this; extra is already in GameManager.gold)
		gold_won = GameManager.calculate_income()
		AudioManager.play("victory")
	else:
		# Partial reward: kill bounty even on defeat
		if bounty_gold > 0:
			GameManager.gold += bounty_gold
			GameManager.gold_changed.emit(GameManager.gold)
		# In map mode, preview income payout (added in _start_rematch)
		if GameManager.is_map_mode:
			gold_won = GameManager.calculate_income()
		AudioManager.play("defeat")
	_update_ui()

	# Autosave — skip on game_complete or game_over (those delete the save)
	var is_game_complete: bool
	if GameManager.is_map_mode:
		is_game_complete = player_won and _current_map_node.get("type", -1) == MapData.NodeType.BOSS and _current_map_node.get("act", 0) == 3
	else:
		is_game_complete = GameManager.current_round >= GameManager.MAX_ROUNDS and player_won
	var is_game_over := GameManager.lives <= 0
	if not is_game_complete and not is_game_over:
		# Don't re-save squad here — pre-battle save already has all units with correct positions.
		# Re-saving now would lose dead units (already queue_free'd) and capture post-movement positions.
		GameManager.save_game(SquadSerializer.squad_to_json(player_squad), ranked_mode)

	# Build income breakdown lines
	var income_lines: Array[String] = []
	if bounty_gold > 0:
		income_lines.append("Kill bounty: +%dg" % bounty_gold)
	if hero_income > 0:
		income_lines.append("Hero income: +%dg" % hero_income)

	if is_game_complete:
		_last_result = "game_complete"
		ProfileManager.record_win(GameManager.current_round)
		var details := "All rounds cleared%s!%s" % [vs_text, elo_text]
		if not income_lines.is_empty():
			details += "\n" + "\n".join(income_lines)
		_show_result_overlay("GAME COMPLETE!", Color.GREEN, details, gold_won)
		result_continue_btn.text = "Return to Menu"
	elif GameManager.lives > 0:
		if player_won:
			_last_result = "victory"
			var details_parts: Array[String] = []
			# Show act completion for boss victories in map mode
			if GameManager.is_map_mode and _current_map_node.get("type", -1) == MapData.NodeType.BOSS:
				var act_names := ["I", "II", "III"]
				var act_num: int = _current_map_node.get("act", 1)
				details_parts.append("Act %s Complete!" % act_names[clampi(act_num - 1, 0, 2)])
			elif vs_text != "":
				details_parts.append("Defeated%s" % vs_text)
			if elo_text != "":
				details_parts.append(elo_text.strip_edges())
			details_parts.append_array(income_lines)
			_show_result_overlay("VICTORY!", Color.GREEN, "\n".join(details_parts), gold_won)
		else:
			_last_result = "defeat"
			var details_parts: Array[String] = []
			if vs_text != "":
				details_parts.append("Lost%s" % vs_text)
			if elo_text != "":
				details_parts.append(elo_text.strip_edges())
			details_parts.append_array(income_lines)
			_show_result_overlay("DEFEAT!", Color.RED, "\n".join(details_parts), gold_won)

func _on_combat_draw() -> void:
	AudioManager.stop_music()
	_apply_survival_regen_bonuses()
	combat_system.stop_combat()
	AudioManager.play("round_start")
	_update_ui()
	_last_result = "draw"
	_show_result_overlay("DRAW!", Color(1.0, 1.0, 0.3), "Combat timed out — no winner.")

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
	if GameManager.is_map_mode:
		GameManager.advance_to_map()
	else:
		GameManager.advance_round()

func _advance_map_node() -> void:
	if _current_map_node.is_empty():
		_start_next_round()
		return
	var node_id: int = _current_map_node["id"]
	MapGenerator.mark_node_visited(GameManager.run_map, node_id)
	MapGenerator.update_available_nodes(GameManager.run_map, node_id)
	_current_map_node = {}
	board.clear_all()
	board.deselect()
	_hide_info_panel()
	_hide_battle_ui()
	result_label.text = ""
	# Check for act transition or game complete
	if MapGenerator.is_run_complete(GameManager.run_map):
		# Handled by game_complete in combat result already
		return
	GameManager.advance_to_map()

func _start_rematch() -> void:
	if GameManager.is_map_mode:
		# Map mode: keep all prep changes, give income payout
		var income := GameManager.calculate_income()
		GameManager.gold += income
		GameManager.gold_changed.emit(GameManager.gold)
	elif not _prep_snapshot.is_empty():
		# Ranked/non-map mode: restore pre-shopping state for retry
		player_squad = _prep_snapshot["squad"]
		GameManager.farms = _prep_snapshot["farms"]
		GameManager.farm_purchases = _prep_snapshot["farm_purchases"]
		GameManager.farms_changed.emit()
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
	if _targeting_merge:
		_cancel_merge_targeting()
	if _targeting_map_upgrade:
		_cancel_map_upgrade_targeting()
	if new_phase == GameManager.Phase.MAP:
		_hide_battle_ui()
		_hide_shop()
		_hide_wave_select()
		# Ensure board is clean when returning to map
		board.clear_all()
		board.deselect()
		_hide_info_panel()
		result_label.text = ""
		map_overlay.refresh(GameManager.run_map)
		map_overlay.visible = true
	elif new_phase == GameManager.Phase.WAVE_SELECT:
		if map_overlay:
			map_overlay.visible = false
		_show_wave_select()
		_hide_battle_ui()
	elif new_phase == GameManager.Phase.PREP:
		if map_overlay:
			map_overlay.visible = false
		_hide_battle_ui()
	else:
		# BATTLE and RESULT phases — ensure map overlay is hidden
		if map_overlay:
			map_overlay.visible = false
	_update_ui()

func _on_game_over() -> void:
	ready_button.disabled = true
	_hide_shop()
	AudioManager.play("game_over")
	_last_result = "game_over"
	ProfileManager.record_loss(GameManager.current_round)
	_show_result_overlay("GAME OVER", Color.RED, "You ran out of lives!")
	result_continue_btn.text = "Return to Menu"

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
	var round_text: String
	if GameManager.is_map_mode and not GameManager.run_map.is_empty():
		var act_names := ["I", "II", "III"]
		var act_idx := clampi(GameManager.run_map.get("current_act", 1) - 1, 0, 2)
		round_text = "Act %s — Round %d" % [act_names[act_idx], GameManager.current_round]
	else:
		round_text = "Round %d/%d" % [GameManager.current_round, GameManager.MAX_ROUNDS]
	var bm_ui = get_node_or_null("/root/BackendManager")
	if ranked_mode and bm_ui:
		round_text += "  |  ELO: %d" % bm_ui.player_rating
	round_label.text = round_text
	lives_label.text = "Lives: %d" % GameManager.lives
	gold_label.text = "Gold: %d" % GameManager.gold
	# Rebuild house icon row: solid = used, outline = available
	for child in farms_row.get_children():
		child.queue_free()
	var used := _get_farms_used()
	if GameManager.farms <= 6:
		for i in range(GameManager.farms):
			var icon := TextureRect.new()
			icon.texture = HOUSE_SOLID if i < used else HOUSE_OUTLINE
			icon.custom_minimum_size = Vector2(18, 18)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			farms_row.add_child(icon)
	else:
		# Compact format: solid icon + used/total number
		var h_icon := TextureRect.new()
		h_icon.texture = HOUSE_SOLID
		h_icon.custom_minimum_size = Vector2(24, 24)
		h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		farms_row.add_child(h_icon)
		var count_lbl := Label.new()
		count_lbl.text = "%d/%d" % [used, GameManager.farms]
		count_lbl.add_theme_font_size_override("font_size", 13)
		count_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		farms_row.add_child(count_lbl)
		# Show outline icons for each empty slot
		var empty := GameManager.farms - used
		for i in range(empty):
			var outline := TextureRect.new()
			outline.texture = HOUSE_OUTLINE
			outline.custom_minimum_size = Vector2(18, 18)
			outline.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			outline.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			farms_row.add_child(outline)
	buy_farm_button.text = "Buy House (%dg)" % GameManager.get_farm_cost()
	buy_farm_button.disabled = GameManager.gold < GameManager.get_farm_cost() or GameManager.current_phase != GameManager.Phase.PREP

	match GameManager.current_phase:
		GameManager.Phase.MAP:
			ready_button.disabled = true
			ready_button.text = "Choose Path"
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

	# Class-colored header panel
	var cls_color: Color = CLASS_COLORS.get(unit.unit_data.unit_class, Color(0.5, 0.5, 0.5))
	var header_panel := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(cls_color.r, cls_color.g, cls_color.b, 0.25)
	header_style.border_color = Color(cls_color.r, cls_color.g, cls_color.b, 0.6)
	header_style.border_width_left = 3
	header_style.border_width_top = 0
	header_style.border_width_right = 0
	header_style.border_width_bottom = 0
	header_style.content_margin_left = 8.0
	header_style.content_margin_right = 8.0
	header_style.content_margin_top = 6.0
	header_style.content_margin_bottom = 6.0
	header_style.corner_radius_top_left = 4
	header_style.corner_radius_top_right = 4
	header_style.corner_radius_bottom_left = 4
	header_style.corner_radius_bottom_right = 4
	header_panel.add_theme_stylebox_override("panel", header_style)
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 2)

	var unit_name := unit.display_name if unit.display_name != "" else unit.unit_data.unit_name
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.text = unit_name
	header_vbox.add_child(name_label)

	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 4)
	var class_name_lbl := Label.new()
	class_name_lbl.add_theme_font_size_override("font_size", 13)
	class_name_lbl.add_theme_color_override("font_color", cls_color.lightened(0.3))
	class_name_lbl.text = unit.unit_data.unit_class
	class_row.add_child(class_name_lbl)
	var dot1 := Label.new()
	dot1.add_theme_font_size_override("font_size", 13)
	dot1.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dot1.text = "•"
	class_row.add_child(dot1)
	var gold_cost_lbl := Label.new()
	gold_cost_lbl.add_theme_font_size_override("font_size", 13)
	gold_cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_cost_lbl.text = "%dg" % unit.unit_data.farm_cost
	class_row.add_child(gold_cost_lbl)
	var dot2 := Label.new()
	dot2.add_theme_font_size_override("font_size", 13)
	dot2.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	dot2.text = "•"
	class_row.add_child(dot2)
	for _h in range(unit.unit_data.pop_cost):
		var h_icon := TextureRect.new()
		h_icon.texture = HOUSE_SOLID
		h_icon.custom_minimum_size = Vector2(14, 14)
		h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		h_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		class_row.add_child(h_icon)
	header_vbox.add_child(class_row)

	var level_label := Label.new()
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	level_label.text = "Level %d  •  XP %d/%d" % [unit.level, unit.xp, Unit.XP_TO_LEVEL]
	header_vbox.add_child(level_label)

	header_panel.add_child(header_vbox)
	info_panel.add_child(header_panel)

	# Stats with upgrade buttons
	_add_stat_row(unit, "damage", "Damage", "%d" % unit.damage, can_buy, 1.0)
	_add_stat_row(unit, "attacks_per_second", "Atk/Sec", "%.2f" % unit.attacks_per_second, can_buy, 0.1)
	_add_stat_row(unit, "ability_cooldown", "Ability CD", "%.1fs" % unit.ability_cooldown, can_buy, -0.3)
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
			# Sell button (75% refund)
			var sell_refund := int(upg.cost * level * 0.75)
			var sell_btn := Button.new()
			sell_btn.text = "-%dg" % sell_refund
			sell_btn.custom_minimum_size = Vector2(42, 22)
			sell_btn.add_theme_font_size_override("font_size", 10)
			sell_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
			var u_sell := unit
			var u_name := upg.name as String
			sell_btn.pressed.connect(func(): _sell_upgrade(u_sell, u_name))
			row.add_child(sell_btn)
			# Re-buy button (level up same upgrade)
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
		var cls_color: Color = CLASS_COLORS.get(data.unit_class, Color(0.5, 0.5, 0.5))
		var header_panel := PanelContainer.new()
		var header_style := StyleBoxFlat.new()
		header_style.bg_color = Color(cls_color.r, cls_color.g, cls_color.b, 0.25)
		header_style.border_color = Color(cls_color.r, cls_color.g, cls_color.b, 0.6)
		header_style.border_width_left = 3
		header_style.content_margin_left = 8.0
		header_style.content_margin_right = 8.0
		header_style.content_margin_top = 6.0
		header_style.content_margin_bottom = 6.0
		header_style.corner_radius_top_left = 4
		header_style.corner_radius_top_right = 4
		header_style.corner_radius_bottom_left = 4
		header_style.corner_radius_bottom_right = 4
		header_panel.add_theme_stylebox_override("panel", header_style)
		header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var header_vbox := VBoxContainer.new()
		header_vbox.add_theme_constant_override("separation", 2)

		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.text = slot.hero_name
		header_vbox.add_child(name_label)

		var class_row := HBoxContainer.new()
		class_row.add_theme_constant_override("separation", 4)
		var class_name_lbl := Label.new()
		class_name_lbl.add_theme_font_size_override("font_size", 13)
		class_name_lbl.add_theme_color_override("font_color", cls_color.lightened(0.3))
		class_name_lbl.text = data.unit_class
		class_row.add_child(class_name_lbl)
		var shop_dot1 := Label.new()
		shop_dot1.add_theme_font_size_override("font_size", 13)
		shop_dot1.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		shop_dot1.text = "•"
		class_row.add_child(shop_dot1)
		var shop_gold_lbl := Label.new()
		shop_gold_lbl.add_theme_font_size_override("font_size", 13)
		shop_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		shop_gold_lbl.text = "%dg" % data.farm_cost
		class_row.add_child(shop_gold_lbl)
		var shop_dot2 := Label.new()
		shop_dot2.add_theme_font_size_override("font_size", 13)
		shop_dot2.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		shop_dot2.text = "•"
		class_row.add_child(shop_dot2)
		for _h in range(data.pop_cost):
			var h_icon := TextureRect.new()
			h_icon.texture = HOUSE_SOLID
			h_icon.custom_minimum_size = Vector2(14, 14)
			h_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			h_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			class_row.add_child(h_icon)
		header_vbox.add_child(class_row)

		var merge_target := _find_player_unit_by_class(data.unit_class)
		if merge_target:
			var merge_label := Label.new()
			merge_label.add_theme_font_size_override("font_size", 11)
			merge_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			merge_label.text = "Auto-merge into existing unit"
			header_vbox.add_child(merge_label)

		header_panel.add_child(header_vbox)
		info_panel.add_child(header_panel)

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
		var text := "Ability: %s" % slot.ability_name
		if slot.ability_desc != "":
			text += "\n  %s" % slot.ability_desc
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
