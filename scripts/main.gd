extends Node2D

@onready var board: Board = $Board
@onready var combat_system: CombatSystem = $CombatSystem
@onready var ready_button: Button = $UI/SidePanel/ReadyButton
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
]

# Upgrade definitions
var upgrade_pool: Array[Dictionary] = [
	# ── Cheap (2-3g) ──
	{"name": "Corrosive", "cost": 2, "rarity": "Normal", "desc": "+2 damage", "stat": "damage", "amount": 2},
	{"name": "Exploit Weakness", "cost": 2, "rarity": "Normal", "desc": "+3 damage", "stat": "damage", "amount": 3},
	{"name": "Toughness", "cost": 2, "rarity": "Normal", "desc": "+20 max HP", "stat": "max_hp", "amount": 20},
	{"name": "Swift Strikes", "cost": 2, "rarity": "Normal", "desc": "+0.1 atk/s", "stat": "attacks_per_second", "amount": 0.1},
	{"name": "Iron Skin", "cost": 2, "rarity": "Normal", "desc": "+1 armor", "stat": "armor", "amount": 1},
	{"name": "Keen Edge", "cost": 2, "rarity": "Normal", "desc": "+2% crit", "stat": "crit_chance", "amount": 2.0},
	{"name": "Nimble", "cost": 2, "rarity": "Normal", "desc": "+3% evasion", "stat": "evasion", "amount": 3.0},
	{"name": "Quickstep", "cost": 3, "rarity": "Normal", "desc": "+5 move speed", "stat": "move_speed", "amount": 5.0},
	{"name": "Longshot", "cost": 3, "rarity": "Normal", "desc": "+30 atk range", "stat": "attack_range", "amount": 30.0},
	{"name": "Vitality", "cost": 3, "rarity": "Normal", "desc": "+15 max HP", "stat": "max_hp", "amount": 15},
	{"name": "Poison Tip", "cost": 3, "rarity": "Normal", "desc": "+1 damage", "stat": "damage", "amount": 1},
	# ── Mid (4-6g) ──
	{"name": "Deadly Focus", "cost": 5, "rarity": "Normal", "desc": "+5% crit", "stat": "crit_chance", "amount": 5.0},
	{"name": "Revenge", "cost": 5, "rarity": "Normal", "desc": "+2 armor", "stat": "armor", "amount": 2},
	{"name": "Bloodlust", "cost": 5, "rarity": "Normal", "desc": "+0.2 atk/s", "stat": "attacks_per_second", "amount": 0.2},
	{"name": "Eagle Eye", "cost": 5, "rarity": "Normal", "desc": "+50 atk range", "stat": "attack_range", "amount": 50.0},
	{"name": "Adrenaline", "cost": 4, "rarity": "Normal", "desc": "+8 move speed", "stat": "move_speed", "amount": 8.0},
	{"name": "Giant Killer", "cost": 6, "rarity": "Normal", "desc": "+5 damage", "stat": "damage", "amount": 5},
	{"name": "Arcane Surge", "cost": 4, "rarity": "Normal", "desc": "+3 max mana", "stat": "max_mana", "amount": 3},
	{"name": "Primed", "cost": 5, "rarity": "Normal", "desc": "Ability ready at battle start", "stat": "primed", "amount": 1.0},
	{"name": "Fortify", "cost": 6, "rarity": "Normal", "desc": "+3 armor", "stat": "armor", "amount": 3},
	# ── Expensive (8-12g) ──
	{"name": "Sepsis", "cost": 8, "rarity": "Normal", "desc": "+5% skill proc", "stat": "skill_proc_chance", "amount": 5.0},
	{"name": "Thorns", "cost": 8, "rarity": "Normal", "desc": "+4 armor", "stat": "armor", "amount": 4},
	{"name": "Vampirism", "cost": 8, "rarity": "Normal", "desc": "+8% evasion", "stat": "evasion", "amount": 8.0},
	{"name": "Berserk", "cost": 10, "rarity": "Normal", "desc": "+0.3 atk/s", "stat": "attacks_per_second", "amount": 0.3},
	{"name": "Last Stand", "cost": 10, "rarity": "Normal", "desc": "+40 max HP", "stat": "max_hp", "amount": 40},
	{"name": "Relentless", "cost": 10, "rarity": "Normal", "desc": "+12 move speed", "stat": "move_speed", "amount": 12.0},
	# ── Rare (15g) ──
	{"name": "Nearly Fatal", "cost": 15, "rarity": "Rare", "desc": "+15% crit", "stat": "crit_chance", "amount": 15.0},
	{"name": "Invincible", "cost": 15, "rarity": "Rare", "desc": "+15% evasion", "stat": "evasion", "amount": 15.0},
	{"name": "Haymaker", "cost": 15, "rarity": "Rare", "desc": "+10 damage", "stat": "damage", "amount": 10},
	{"name": "Sniper", "cost": 15, "rarity": "Rare", "desc": "+100 atk range", "stat": "attack_range", "amount": 100.0},
	{"name": "Necromancy", "cost": 12, "rarity": "Rare", "desc": "Summoner: archers inherit 15% stats (max 3)", "stat": "necromancy", "amount": 1.0},
	# ── Rare Hero-Specific (12g, round 6+) ──
	{"name": "Blood Rage", "cost": 12, "rarity": "Rare", "desc": "+5 dmg, +0.2 atk/s", "stat": "blood_rage", "amount": 1.0, "class_req": "Grunt"},
	{"name": "Deadeye", "cost": 12, "rarity": "Rare", "desc": "+8 dmg, +80 range", "stat": "deadeye", "amount": 1.0, "class_req": "Archer"},
	{"name": "Phantom Step", "cost": 12, "rarity": "Rare", "desc": "+10% evade, +10% crit", "stat": "phantom_step", "amount": 1.0, "class_req": "Assassin"},
	{"name": "Fortress", "cost": 12, "rarity": "Rare", "desc": "+5 armor, +40 HP", "stat": "fortress", "amount": 1.0, "class_req": "Tank"},
	{"name": "Soul Rend", "cost": 12, "rarity": "Rare", "desc": "+8 dmg, +3 max mana", "stat": "soul_rend", "amount": 1.0, "class_req": "Warlock"},
	{"name": "Divine Covenant", "cost": 12, "rarity": "Rare", "desc": "+30 HP, +3 max mana", "stat": "divine_covenant", "amount": 1.0, "class_req": "Priest"},
	{"name": "Toxic Mastery", "cost": 12, "rarity": "Rare", "desc": "+5 dmg, +5% skill proc", "stat": "toxic_mastery", "amount": 1.0, "class_req": "Herbalist"},
	# ── Epic Hero-Specific (18g, round 11+) ──
	{"name": "Rampage", "cost": 18, "rarity": "Epic", "desc": "+10 dmg, +0.3 atk/s, +20 HP", "stat": "rampage", "amount": 1.0, "class_req": "Grunt"},
	{"name": "Hawkeye", "cost": 18, "rarity": "Epic", "desc": "+12 dmg, +120 range, +8% crit", "stat": "hawkeye", "amount": 1.0, "class_req": "Archer"},
	{"name": "Death's Embrace", "cost": 18, "rarity": "Epic", "desc": "+15% evade, +15% crit, +5 dmg", "stat": "deaths_embrace", "amount": 1.0, "class_req": "Assassin"},
	{"name": "Bastion", "cost": 18, "rarity": "Epic", "desc": "+8 armor, +60 HP, +2 dmg", "stat": "bastion", "amount": 1.0, "class_req": "Tank"},
	{"name": "Dark Pact", "cost": 18, "rarity": "Epic", "desc": "+15 dmg, +5 max mana", "stat": "dark_pact", "amount": 1.0, "class_req": "Warlock"},
	{"name": "Ascension", "cost": 18, "rarity": "Epic", "desc": "+50 HP, +5 max mana, +5 dmg", "stat": "ascension", "amount": 1.0, "class_req": "Priest"},
	{"name": "Plague Lord", "cost": 18, "rarity": "Epic", "desc": "+10 dmg, +8% skill proc, +3 armor", "stat": "plague_lord", "amount": 1.0, "class_req": "Herbalist"},
]

# Wave strategy definitions — each describes the enemy team composition
# "weights" map unit_class to relative pick chance; "label" describes the mix
var wave_strategies: Array[Dictionary] = [
	{"label": "Frontline Defense", "strategy": "concentrated",
	 "weights": {"Tank": 5, "Priest": 2, "Warlock": 1, "Herbalist": 1, "Grunt": 3, "Archer": 0, "Assassin": 0, "Summoner": 0}},
	{"label": "Glass Cannon", "strategy": "spread",
	 "weights": {"Tank": 0, "Priest": 1, "Warlock": 4, "Herbalist": 4, "Grunt": 0, "Archer": 3, "Assassin": 2, "Summoner": 1}},
	{"label": "Arcane Assault", "strategy": "concentrated",
	 "weights": {"Tank": 1, "Priest": 1, "Warlock": 5, "Herbalist": 2, "Grunt": 1, "Archer": 2, "Assassin": 0, "Summoner": 2}},
	{"label": "Holy Guard", "strategy": "many",
	 "weights": {"Tank": 3, "Priest": 5, "Warlock": 1, "Herbalist": 1, "Grunt": 2, "Archer": 0, "Assassin": 0, "Summoner": 1}},
	{"label": "Poison Swarm", "strategy": "many",
	 "weights": {"Tank": 1, "Priest": 1, "Warlock": 1, "Herbalist": 5, "Grunt": 1, "Archer": 1, "Assassin": 1, "Summoner": 0}},
	{"label": "Balanced Army", "strategy": "spread",
	 "weights": {"Tank": 3, "Priest": 3, "Warlock": 3, "Herbalist": 3, "Grunt": 3, "Archer": 3, "Assassin": 3, "Summoner": 1}},
	{"label": "Blitz Rush", "strategy": "concentrated",
	 "weights": {"Tank": 0, "Priest": 1, "Warlock": 0, "Herbalist": 1, "Grunt": 5, "Archer": 1, "Assassin": 4, "Summoner": 0}},
	{"label": "Sniper Nest", "strategy": "spread",
	 "weights": {"Tank": 2, "Priest": 1, "Warlock": 1, "Herbalist": 1, "Grunt": 1, "Archer": 5, "Assassin": 1, "Summoner": 1}},
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
var wave_cards_container: HBoxContainer
var wave_options: Array[Dictionary] = []

# Shop UI (built in code)
var shop_bar: HBoxContainer
var shop_buttons: Array[Button] = []
var reroll_button: Button
var freeze_button: Button
var sell_button: Button

# Shop freeze state
var shop_frozen: bool = false

# Upgrade targeting state
var _targeting_upgrade: bool = false
var _pending_upgrade_slot: int = -1

# Shop confirmation state
var _selected_shop_slot: int = -1
var shop_confirm_bar: HBoxContainer
var buy_button: Button
var cancel_button: Button

# Currently shown info unit (for refreshing)
var _info_unit: Unit = null

# Battle UI — strength bar & combat log
var strength_bar_container: HBoxContainer
var strength_bar_player: ColorRect
var strength_bar_enemy: ColorRect
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

	_build_wave_select_ui()
	_build_shop_bar()
	_build_battle_ui()
	_hide_info_panel()
	_hide_shop()

	combat_system.combat_event.connect(_on_combat_event)
	combat_system.tick_completed.connect(_on_tick_completed)

	GameManager.advance_round()

# ── Battle UI (Strength Bar + Combat Log) ──────────────────

func _build_battle_ui() -> void:
	# Strength bar — tug-of-war HP bar below TopBar
	strength_bar_container = HBoxContainer.new()
	strength_bar_container.position = Vector2(55, 42)
	strength_bar_container.custom_minimum_size = Vector2(860, 8)
	strength_bar_container.add_theme_constant_override("separation", 0)
	ui_layer.add_child(strength_bar_container)

	strength_bar_player = ColorRect.new()
	strength_bar_player.color = Color(0.2, 0.4, 1.0)
	strength_bar_player.custom_minimum_size = Vector2(430, 8)
	strength_bar_player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_bar_container.add_child(strength_bar_player)

	strength_bar_enemy = ColorRect.new()
	strength_bar_enemy.color = Color(1.0, 0.2, 0.2)
	strength_bar_enemy.custom_minimum_size = Vector2(430, 8)
	strength_bar_enemy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strength_bar_container.add_child(strength_bar_enemy)

	strength_bar_container.visible = false

	# Combat log — scrolling text at bottom-right
	combat_log_scroll = ScrollContainer.new()
	combat_log_scroll.position = Vector2(1010, 440)
	combat_log_scroll.custom_minimum_size = Vector2(260, 160)
	combat_log_scroll.size = Vector2(260, 160)
	ui_layer.add_child(combat_log_scroll)

	combat_log = RichTextLabel.new()
	combat_log.bbcode_enabled = true
	combat_log.fit_content = true
	combat_log.custom_minimum_size = Vector2(260, 0)
	combat_log.scroll_active = false
	combat_log.add_theme_font_size_override("normal_font_size", 11)
	combat_log_scroll.add_child(combat_log)

	combat_log_scroll.visible = false

func _on_combat_event(text: String) -> void:
	combat_log.append_text(text + "\n")
	# Auto-scroll to bottom
	await get_tree().process_frame
	combat_log_scroll.scroll_vertical = int(combat_log_scroll.get_v_scroll_bar().max_value)

func _on_tick_completed() -> void:
	var player_hp := 0
	var enemy_hp := 0
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		player_hp += unit.current_hp
	for unit in board.get_units_on_team(Unit.Team.ENEMY):
		enemy_hp += unit.current_hp

	var total := player_hp + enemy_hp
	if total <= 0:
		return
	var ratio: float = float(player_hp) / float(total)
	var bar_width: float = 860.0
	strength_bar_player.custom_minimum_size.x = bar_width * ratio
	strength_bar_enemy.custom_minimum_size.x = bar_width * (1.0 - ratio)

func _show_battle_ui() -> void:
	strength_bar_container.visible = true
	combat_log_scroll.visible = true

func _hide_battle_ui() -> void:
	strength_bar_container.visible = false
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
	wave_overlay.add_child(center)

	wave_panel = PanelContainer.new()
	wave_panel.custom_minimum_size = Vector2(780, 260)
	center.add_child(wave_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	wave_panel.add_child(vbox)

	wave_title = Label.new()
	wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(wave_title)

	wave_cards_container = HBoxContainer.new()
	wave_cards_container.add_theme_constant_override("separation", 15)
	wave_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(wave_cards_container)

	wave_overlay.visible = false

func _show_wave_select() -> void:
	wave_options = _generate_wave_options()
	wave_title.text = "Round %d/%d" % [GameManager.current_round, GameManager.MAX_ROUNDS]

	for child in wave_cards_container.get_children():
		child.queue_free()

	for i in range(3):
		var wave: Dictionary = wave_options[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 180)
		btn.text = "%s\n\n%s\n\n%d units (%d farms)\nStrategy: %s" % [
			wave.name, wave.enemy_text, wave.total_units, wave.total_farms, wave.strategy
		]
		var idx := i
		btn.pressed.connect(func(): _on_wave_selected(idx))
		wave_cards_container.add_child(btn)

	wave_overlay.visible = true

func _hide_wave_select() -> void:
	wave_overlay.visible = false

func _generate_wave_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for i in range(3):
		options.append(_generate_single_wave())
	return options

func _generate_single_wave() -> Dictionary:
	var round_num := GameManager.current_round
	# Farm budget starts at 1 and scales up: ~1 unit round 1, ~2 round 2, etc.
	var enemy_farm_budget := round_num + randi_range(0, maxi(round_num / 3, 1))

	# Enemy level scales with rounds
	var base_level := clampi(ceili(round_num / 3.0), 1, 7)

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
		for i in range(w):
			pool.append(data)
	return pool

func _on_wave_selected(idx: int) -> void:
	var wave: Dictionary = wave_options[idx]
	_hide_wave_select()

	var enemies: Array = wave.enemies
	var enemy_count: int = enemies.size()
	for i in range(enemy_count):
		var entry: Dictionary = enemies[i]
		var spacing: float = Board.ARENA_HEIGHT / (enemy_count + 1)
		var pos := Vector2(
			randf_range(Board.DIVIDER_X + 80, Board.ARENA_WIDTH - 60),
			spacing * (i + 1)
		)
		var unit := _spawn_unit(entry.data, Unit.Team.ENEMY, pos)
		# Apply level scaling: each level above 1 boosts stats
		var lvl: int = entry.get("level", 1)
		if lvl > 1:
			var scale_factor := 1.0 + (lvl - 1) * 0.25
			unit.damage = int(ceil(unit.damage * scale_factor))
			unit.max_hp = int(ceil(unit.max_hp * scale_factor))
			unit.current_hp = unit.max_hp
			unit.armor = int(ceil(unit.armor * scale_factor)) if unit.armor > 0 else 0
			unit.attacks_per_second *= 1.0 + (lvl - 1) * 0.1
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
	shop_bar.position = Vector2(30, 428)
	shop_bar.add_theme_constant_override("separation", 8)
	ui_layer.add_child(shop_bar)

	for i in range(HERO_SHOP_SLOTS + UPGRADE_SHOP_SLOTS):
		var btn := Button.new()
		if i < HERO_SHOP_SLOTS:
			btn.custom_minimum_size = Vector2(140, 90)
		else:
			btn.custom_minimum_size = Vector2(120, 90)
		var idx := i
		btn.pressed.connect(func(): _on_shop_card_pressed(idx))
		shop_bar.add_child(btn)
		shop_buttons.append(btn)

	# Insert separator after hero cards
	var sep := VSeparator.new()
	shop_bar.add_child(sep)
	shop_bar.move_child(sep, HERO_SHOP_SLOTS)

	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(90, 90)
	reroll_button.text = "Re-roll\n(%dg)" % GameManager.REROLL_COST
	reroll_button.pressed.connect(_on_reroll_pressed)
	shop_bar.add_child(reroll_button)

	freeze_button = Button.new()
	freeze_button.custom_minimum_size = Vector2(50, 90)
	freeze_button.text = "F\nFreeze"
	freeze_button.pressed.connect(_on_freeze_pressed)
	shop_bar.add_child(freeze_button)

	sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(50, 90)
	sell_button.text = "X\nSell"
	sell_button.pressed.connect(_on_sell_pressed)
	shop_bar.add_child(sell_button)

	# Confirm bar (Buy / Cancel) — hidden until a shop card is selected
	shop_confirm_bar = HBoxContainer.new()
	shop_confirm_bar.add_theme_constant_override("separation", 6)
	shop_confirm_bar.visible = false
	ui_layer.add_child(shop_confirm_bar)

	buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(60, 30)
	buy_button.pressed.connect(_confirm_shop_purchase)
	shop_confirm_bar.add_child(buy_button)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(60, 30)
	cancel_button.pressed.connect(_cancel_shop_selection)
	shop_confirm_bar.add_child(cancel_button)

func _roll_shop() -> void:
	_cancel_shop_selection()
	shop_slots.clear()
	for i in range(HERO_SHOP_SLOTS):
		var data: UnitData = hero_pool.pick_random()
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
		if slot.sold:
			btn.text = "SOLD"
			btn.disabled = true
		elif slot.type == "hero":
			var data: UnitData = slot.data
			var label := "%dg [F:%d]\n\n%s\n%s" % [data.farm_cost, data.pop_cost, data.unit_class, data.unit_name]
			if _find_player_unit_by_class(data.unit_class):
				label += "\n\nAuto: Use as EXP\n(Shift: new copy)"
			btn.text = label
			btn.disabled = false
		else:
			var upgrade: Dictionary = slot.data
			var class_text := ""
			if upgrade.has("class_req"):
				class_text = "\n(%s only)" % upgrade.class_req
			btn.text = "%dg\n\n%s\n%s\n%s%s" % [upgrade.cost, upgrade.name, upgrade.rarity, upgrade.desc, class_text]
			btn.disabled = false
			if upgrade.rarity == "Rare":
				btn.modulate = Color(0.85, 0.6, 1.0)
			elif upgrade.rarity == "Epic":
				btn.modulate = Color(1.0, 0.7, 0.3)
		if i == _selected_shop_slot and not slot.sold:
			btn.modulate = btn.modulate.lightened(0.35)

	reroll_button.text = "Re-roll\n(%dg)" % GameManager.REROLL_COST
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
	shop_confirm_bar.visible = false
	_hide_info_panel()
	_update_shop_display()

func _confirm_shop_purchase() -> void:
	if _selected_shop_slot < 0:
		return
	var idx := _selected_shop_slot
	var slot: Dictionary = shop_slots[idx]
	_selected_shop_slot = -1
	shop_confirm_bar.visible = false
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
	if merge_target and not Input.is_key_pressed(KEY_SHIFT):
		if not GameManager.spend_gold(slot.cost):
			return
		_grant_xp(merge_target, 1)
		slot.sold = true
		board.select_unit(merge_target)
		_show_info_panel(merge_target)
		_update_shop_display()
		_update_ui()
		return

	# Spawn new unit — check farm budget
	if _get_farms_used() + data.pop_cost > GameManager.farms:
		return
	if not GameManager.spend_gold(slot.cost):
		return

	var default_pos := board.snap_to_grid(Vector2(
		randf_range(60, Board.DIVIDER_X - 60),
		randf_range(60, Board.ARENA_HEIGHT - 60)
	))
	_spawn_unit(data, Unit.Team.PLAYER, default_pos)
	slot.sold = true
	_update_shop_display()
	_update_ui()

func _find_player_unit_by_class(unit_class: String) -> Unit:
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		if unit.unit_data.unit_class == unit_class:
			return unit
	return null

func _buy_upgrade(idx: int) -> void:
	var slot: Dictionary = shop_slots[idx]

	if not GameManager.spend_gold(slot.cost):
		return

	slot.sold = true
	_targeting_upgrade = true
	_pending_upgrade_slot = idx
	board.targeting_mode = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	_update_shop_display()
	_update_ui()
	board.queue_redraw()

func _apply_pending_upgrade(unit: Unit) -> void:
	if unit.applied_upgrades.size() >= unit.get_max_upgrades():
		return
	var slot: Dictionary = shop_slots[_pending_upgrade_slot]
	var upgrade: Dictionary = slot.data

	# Validate class restriction
	if upgrade.has("class_req") and unit.unit_data.unit_class != upgrade.class_req:
		return

	_apply_stat_buff(unit, upgrade.stat, upgrade.amount)
	unit.applied_upgrades.append(upgrade.duplicate())

	_targeting_upgrade = false
	_pending_upgrade_slot = -1
	board.targeting_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	board.select_unit(unit)
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
		freeze_button.text = "F\nUnfreeze"
		freeze_button.modulate = Color(0.5, 0.8, 1.0)
	else:
		freeze_button.text = "F\nFreeze"
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
			unit._update_armor_bar()
		"evasion":
			unit.evasion += amount
		"attack_range":
			unit.attack_range += amount
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
			unit.armor += 5
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
			unit.armor += 8
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
			unit.armor += 3
			unit._update_armor_bar()
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

	# Small boost per XP gained (~10% stats per XP point)
	for i in range(xp_gained):
		target.damage = int(ceil(target.damage * 1.10))
		target.max_hp = int(ceil(target.max_hp * 1.10))
		target.attacks_per_second *= 1.05
		target.attack_range *= 1.05
		target.move_speed *= 1.05
		target.armor += 1 if target.armor > 0 else 0
		target.evasion *= 1.05
		target.crit_chance *= 1.05
		target.skill_proc_chance *= 1.05
		target.max_mana = int(ceil(target.max_mana * 1.05))

	# Level-up loop
	while target.xp >= Unit.XP_TO_LEVEL:
		target.xp -= Unit.XP_TO_LEVEL
		target.level += 1
		# Big stat boost on level-up
		target.damage = int(ceil(target.damage * 1.40))
		target.max_hp = int(ceil(target.max_hp * 1.40))
		target.attacks_per_second *= 1.20
		target.attack_range *= 1.15
		target.move_speed *= 1.15
		target.armor += 2 if target.armor > 0 else 0
		target.evasion *= 1.20
		target.crit_chance *= 1.20
		target.skill_proc_chance *= 1.20
		target.max_mana = int(ceil(target.max_mana * 1.20))

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
			"stat_purchases": unit.stat_purchases.duplicate(),
			"applied_upgrades": saved_upgrades,
			"stats": {
				"damage": unit.damage,
				"max_hp": unit.max_hp,
				"attacks_per_second": unit.attacks_per_second,
				"attack_range": unit.attack_range,
				"move_speed": unit.move_speed,
				"armor": unit.armor,
				"evasion": unit.evasion,
				"crit_chance": unit.crit_chance,
				"skill_proc_chance": unit.skill_proc_chance,
				"max_mana": unit.max_mana,
				"mana_cost_per_attack": unit.mana_cost_per_attack,
				"mana_regen_per_second": unit.mana_regen_per_second,
			}
		})

func _restore_squad() -> void:
	for entry in player_squad:
		var unit := _spawn_unit(entry.data, Unit.Team.PLAYER, entry.position)
		unit.xp = entry.get("xp", 0)
		unit.level = entry.get("level", 1)
		unit.necromancy_stacks = entry.get("necromancy_stacks", 0)
		unit.primed = entry.get("primed", false)
		unit.stat_purchases = entry.get("stat_purchases", {}).duplicate()
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
			unit.move_speed = s.move_speed
			unit.armor = s.armor
			unit.evasion = s.evasion
			unit.crit_chance = s.crit_chance
			unit.skill_proc_chance = s.skill_proc_chance
			unit.max_mana = s.max_mana
			unit.current_mana = 0
			unit.mana_cost_per_attack = s.mana_cost_per_attack
			unit.mana_regen_per_second = s.mana_regen_per_second
			unit.health_bar.max_value = s.max_hp
			unit.health_bar.value = s.max_hp
			unit.update_scale()

# ── Unit Spawning ───────────────────────────────────────────

func _spawn_unit(data: UnitData, team: Unit.Team, pos: Vector2) -> Unit:
	var unit: Unit = unit_scene.instantiate()
	unit.setup(data, team, pos)
	board.add_unit(unit)
	return unit

func _on_summon_requested(data: UnitData, team: Unit.Team, pos: Vector2, summoner: Unit) -> void:
	var archer := _spawn_unit(data, team, pos)
	# Summoned archers are weaker than recruited ones (60% base stats)
	archer.damage = int(ceil(archer.damage * 0.6))
	archer.max_hp = int(ceil(archer.max_hp * 0.6))
	archer.current_hp = archer.max_hp
	archer.attacks_per_second *= 0.8
	archer.health_bar.max_value = archer.max_hp
	archer.health_bar.value = archer.current_hp
	# Scale summoned archer stats based on the summoner's merge count and stat purchases
	var total_purchases: int = 0
	for key in summoner.stat_purchases:
		total_purchases += summoner.stat_purchases[key]
	var power: float = (summoner.level - 1) * 5.0 + summoner.xp + total_purchases
	if power > 0:
		var scale_factor := 1.0 + power * 0.08
		archer.damage = int(ceil(archer.damage * scale_factor))
		archer.max_hp = int(ceil(archer.max_hp * scale_factor))
		archer.current_hp = archer.max_hp
		archer.attacks_per_second *= 1.0 + power * 0.03
		archer.health_bar.max_value = archer.max_hp
		archer.health_bar.value = archer.current_hp
		archer.update_scale()
	# Necromancy: each stack gives summoned archers 15% of the summoner's bonus stats (max 3 stacks)
	if summoner.necromancy_stacks > 0:
		var effective_stacks := mini(summoner.necromancy_stacks, 3)
		var pct := effective_stacks * 0.15
		var bonus_hp := summoner.max_hp - summoner.unit_data.max_hp
		var bonus_atk_spd := summoner.attacks_per_second - summoner.unit_data.attacks_per_second
		var bonus_armor := summoner.armor - summoner.unit_data.armor
		var bonus_evasion := summoner.evasion - summoner.unit_data.evasion
		var bonus_crit := summoner.crit_chance - summoner.unit_data.crit_chance
		archer.max_hp += int(ceil(bonus_hp * pct))
		archer.current_hp = archer.max_hp
		archer.attacks_per_second += bonus_atk_spd * pct
		archer.armor += int(ceil(bonus_armor * pct))
		archer.evasion += bonus_evasion * pct
		archer.crit_chance += bonus_crit * pct
		archer.health_bar.max_value = archer.max_hp
		archer.health_bar.value = archer.current_hp
		archer._update_armor_bar()

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

func _on_combat_ended(player_won: bool) -> void:
	GameManager.end_battle(player_won)
	if player_won:
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "DEFEAT!"
		result_label.add_theme_color_override("font_color", Color.RED)
	_update_ui()

	if GameManager.lives > 0 and GameManager.current_round < GameManager.MAX_ROUNDS:
		get_tree().create_timer(2.0).timeout.connect(_start_next_round)
	elif GameManager.current_round >= GameManager.MAX_ROUNDS and player_won:
		result_label.text = "GAME COMPLETE!"

func _start_next_round() -> void:
	board.clear_all()
	board.deselect()
	_hide_info_panel()
	result_label.text = ""
	GameManager.advance_round()

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

# ── Farm Helpers ─────────────────────────────────────────────

func _get_farms_used() -> int:
	var total := 0
	for unit in board.get_units_on_team(Unit.Team.PLAYER):
		total += unit.unit_data.pop_cost
	return total

func _on_buy_farm_pressed() -> void:
	if GameManager.current_phase != GameManager.Phase.PREP:
		return
	GameManager.buy_farm()
	_update_ui()

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
	var header_text := "%s\n%s  (Cost: %dg  Farms: %d)" % [unit.unit_data.unit_name, unit.unit_data.unit_class, unit.unit_data.farm_cost, unit.unit_data.pop_cost]
	header_text += "\nLevel %d  xp %d/%d" % [unit.level, unit.xp, Unit.XP_TO_LEVEL]
	header.text = header_text
	info_panel.add_child(header)

	info_panel.add_child(HSeparator.new())

	# Stats with upgrade buttons
	_add_stat_row(unit, "damage", "Damage", "%d" % unit.damage, can_buy, 1.0)
	_add_stat_row(unit, "attacks_per_second", "Atk/Sec", "%.2f" % unit.attacks_per_second, can_buy, 0.1)
	_add_stat_display("Ability CD", "%.1fs" % unit.ability_cooldown)
	_add_stat_row(unit, "max_hp", "Health", "%d/%d" % [unit.current_hp, unit.max_hp], can_buy, 10.0)
	_add_stat_row(unit, "max_mana", "Mana", "%d/%d" % [unit.current_mana, unit.max_mana], can_buy, 2.0)
	_add_stat_row(unit, "armor", "Armor", "%d" % unit.armor, can_buy, 1.0)
	_add_stat_row(unit, "evasion", "Evasion", "%.0f%%" % unit.evasion, can_buy, 2.0)
	_add_stat_row(unit, "attack_range", "Atk Range", "%.0f" % unit.attack_range, can_buy, 20.0)
	_add_stat_row(unit, "move_speed", "Move Speed", "%.0f" % unit.move_speed, can_buy, 5.0)
	_add_stat_row(unit, "crit_chance", "Crit", "%.0f%%" % unit.crit_chance, can_buy, 1.0)
	_add_stat_row(unit, "skill_proc_chance", "Skill Proc", "%.0f%%" % unit.skill_proc_chance, can_buy, 1.0)

	# Applied upgrades section
	info_panel.add_child(HSeparator.new())
	var upgrades_header := Label.new()
	upgrades_header.add_theme_font_size_override("font_size", 14)
	upgrades_header.text = "Upgrades (%d/%d):" % [unit.applied_upgrades.size(), unit.get_max_upgrades()]
	info_panel.add_child(upgrades_header)
	for upg in unit.applied_upgrades:
		var upg_lbl := Label.new()
		upg_lbl.add_theme_font_size_override("font_size", 12)
		upg_lbl.text = "  %s — %s" % [upg.name, upg.desc]
		info_panel.add_child(upg_lbl)

	info_panel.add_child(HSeparator.new())

	# Ability / Skill / Boosted
	var extras := Label.new()
	extras.add_theme_font_size_override("font_size", 12)
	var text := "Ability: %s" % unit.unit_data.ability_name
	if unit.unit_data.skill_name != "":
		text += "\nSkill: %s" % unit.unit_data.skill_name
	if unit.unit_data.boosted_stats.size() > 0:
		text += "\nBoosted: %s" % ", ".join(unit.unit_data.boosted_stats)
	extras.text = text
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
		info_panel.add_child(header)

		info_panel.add_child(HSeparator.new())

		var stats := Label.new()
		stats.add_theme_font_size_override("font_size", 13)
		stats.text = "Damage: %d\nAtk/Sec: %.2f\nAbility CD: %.1fs\nHealth: %d\nMana: %d\nArmor: %d\nEvasion: %.0f%%\nAtk Range: %.0f\nMove Speed: %.0f\nCrit: %.0f%%\nSkill Proc: %.0f%%" % [
			data.damage, data.attacks_per_second, data.ability_cooldown,
			data.max_hp, data.max_mana, data.armor, data.evasion,
			data.attack_range, data.move_speed, data.crit_chance, data.skill_proc_chance
		]
		info_panel.add_child(stats)

		info_panel.add_child(HSeparator.new())

		var extras := Label.new()
		extras.add_theme_font_size_override("font_size", 12)
		var text := "Ability: %s" % data.ability_name
		if data.skill_name != "":
			text += "\nSkill: %s" % data.skill_name
		if data.boosted_stats.size() > 0:
			text += "\nBoosted: %s" % ", ".join(data.boosted_stats)
		extras.text = text
		info_panel.add_child(extras)
	else:
		var upgrade: Dictionary = slot.data
		var header := Label.new()
		header.add_theme_font_size_override("font_size", 16)
		header.text = "%s\n%s  (Cost: %dg)" % [upgrade.name, upgrade.rarity, upgrade.cost]
		info_panel.add_child(header)

		info_panel.add_child(HSeparator.new())

		var desc := Label.new()
		desc.add_theme_font_size_override("font_size", 13)
		var desc_text := "Effect: %s" % upgrade.desc
		if upgrade.has("class_req"):
			desc_text += "\nRequires: %s" % upgrade.class_req
		desc.text = desc_text
		info_panel.add_child(desc)

func _hide_info_panel() -> void:
	info_scroll.visible = false
	_info_unit = null
