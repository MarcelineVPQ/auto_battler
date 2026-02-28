extends Node2D

@onready var board: Board = $Board
@onready var combat_system: CombatSystem = $CombatSystem
@onready var ready_button: Button = $UI/SidePanel/ReadyButton
@onready var result_label: Label = $UI/ResultLabel
@onready var round_label: Label = $UI/TopBar/RoundLabel
@onready var lives_label: Label = $UI/SidePanel/LivesLabel
@onready var gold_label: Label = $UI/SidePanel/GoldLabel
@onready var cap_label: Label = $UI/SidePanel/CapLabel
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
	{"name": "Primed", "cost": 5, "rarity": "Normal", "desc": "+4% skill proc", "stat": "skill_proc_chance", "amount": 4.0},
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
	{"name": "Necromancy", "cost": 8, "rarity": "Rare", "desc": "Summoner: archers inherit stats", "stat": "necromancy", "amount": 1.0},
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

# Currently shown info unit (for refreshing)
var _info_unit: Unit = null

func _ready() -> void:
	combat_system.setup(board)
	combat_system.combat_ended.connect(_on_combat_ended)
	combat_system.summon_requested.connect(_on_summon_requested)
	ready_button.pressed.connect(_on_ready_pressed)

	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.gold_changed.connect(func(_g): _update_ui())
	GameManager.lives_changed.connect(func(_l): _update_ui())
	GameManager.game_over.connect(_on_game_over)

	_build_wave_select_ui()
	_build_shop_bar()
	_hide_info_panel()
	_hide_shop()

	GameManager.advance_round()

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
		btn.text = "%s\n\n%s\n\n%d units\nStrategy: %s" % [
			wave.name, wave.enemy_text, wave.total_units, wave.strategy
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
	# Aggressive enemy count scaling: starts at 1, reaches ~20 by round 20
	var min_enemies := clampi(ceili(round_num * 0.6), 1, 16)
	var max_enemies := clampi(ceili(round_num * 1.1), 1, 22)
	var enemy_count := randi_range(min_enemies, max_enemies)

	# Enemy level scales with rounds
	var base_level := clampi(ceili(round_num / 3.0), 1, 7)

	# Pick a strategy and build composition from its weights
	var strat: Dictionary = wave_strategies.pick_random()
	var weighted_pool: Array[UnitData] = _build_weighted_pool(strat.weights)

	var enemies: Array[Dictionary] = []
	# Group enemies by class+level for display
	var counts: Dictionary = {}
	for j in range(enemy_count):
		var data: UnitData = weighted_pool.pick_random()
		# Vary level slightly: base_level +/- 1
		var lvl := clampi(base_level + randi_range(-1, 1), 1, 10)
		enemies.append({"data": data, "level": lvl})
		var key := "%s Lv%d" % [data.unit_class, lvl]
		counts[key] = counts.get(key, 0) + 1

	var enemy_text := ""
	for key in counts:
		enemy_text += "%dx %s\n" % [counts[key], key]

	return {
		"name": strat.label,
		"strategy": strat.strategy,
		"enemies": enemies,
		"total_units": enemy_count,
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
	shop_bar.position = Vector2(30, 445)
	shop_bar.add_theme_constant_override("separation", 8)
	ui_layer.add_child(shop_bar)

	for i in range(HERO_SHOP_SLOTS + UPGRADE_SHOP_SLOTS):
		var btn := Button.new()
		if i < HERO_SHOP_SLOTS:
			btn.custom_minimum_size = Vector2(140, 130)
		else:
			btn.custom_minimum_size = Vector2(120, 130)
		var idx := i
		btn.pressed.connect(func(): _on_shop_card_pressed(idx))
		shop_bar.add_child(btn)
		shop_buttons.append(btn)

	# Insert separator after hero cards
	var sep := VSeparator.new()
	shop_bar.add_child(sep)
	shop_bar.move_child(sep, HERO_SHOP_SLOTS)

	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(90, 130)
	reroll_button.text = "Re-roll\n(%dg)" % GameManager.REROLL_COST
	reroll_button.pressed.connect(_on_reroll_pressed)
	shop_bar.add_child(reroll_button)

	freeze_button = Button.new()
	freeze_button.custom_minimum_size = Vector2(50, 130)
	freeze_button.text = "F\nFreeze"
	freeze_button.pressed.connect(_on_freeze_pressed)
	shop_bar.add_child(freeze_button)

	sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(50, 130)
	sell_button.text = "X\nSell"
	sell_button.pressed.connect(_on_sell_pressed)
	shop_bar.add_child(sell_button)

func _roll_shop() -> void:
	shop_slots.clear()
	for i in range(HERO_SHOP_SLOTS):
		var data: UnitData = hero_pool.pick_random()
		shop_slots.append({"type": "hero", "data": data, "cost": data.farm_cost, "sold": false})
	for i in range(UPGRADE_SHOP_SLOTS):
		var upgrade: Dictionary = upgrade_pool.pick_random()
		shop_slots.append({"type": "upgrade", "data": upgrade, "cost": upgrade.cost, "sold": false})
	_update_shop_display()

func _update_shop_display() -> void:
	for i in range(shop_slots.size()):
		var slot: Dictionary = shop_slots[i]
		var btn: Button = shop_buttons[i]
		if slot.sold:
			btn.text = "SOLD"
			btn.disabled = true
		elif slot.type == "hero":
			var data: UnitData = slot.data
			btn.text = "%dg\n\n%s\n%s" % [data.farm_cost, data.unit_class, data.unit_name]
			btn.disabled = false
		else:
			var upgrade: Dictionary = slot.data
			btn.text = "%dg\n\n%s\n%s\n%s" % [upgrade.cost, upgrade.name, upgrade.rarity, upgrade.desc]
			btn.disabled = false

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
	if slot.type == "hero":
		_buy_hero(idx)
	else:
		_buy_upgrade(idx)

func _buy_hero(idx: int) -> void:
	var slot: Dictionary = shop_slots[idx]
	var data: UnitData = slot.data
	var player_count := board.get_units_on_team(Unit.Team.PLAYER).size()

	if player_count >= GameManager.squad_cap:
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
			unit.current_mana = unit.max_mana
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
	var xp_gained := 1 + consumed.xp
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
	target.current_mana = target.max_mana

	# Update visuals
	target.health_bar.max_value = target.max_hp
	target.health_bar.value = target.current_hp
	target._update_armor_bar()
	target.update_scale()

	# Remove consumed unit
	board.remove_unit(consumed)
	consumed.queue_free()

	# Select merged unit and show updated stats
	board.select_unit(target)
	_show_info_panel(target)
	_update_ui()

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
			unit.current_mana = s.max_mana
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
	# Scale summoned archer stats based on the summoner's merge count and stat purchases
	var total_purchases: int = 0
	for key in summoner.stat_purchases:
		total_purchases += summoner.stat_purchases[key]
	var power: float = (summoner.level - 1) * 5.0 + summoner.xp + total_purchases
	if power > 0:
		var scale_factor := 1.0 + power * 0.15
		archer.damage = int(ceil(archer.damage * scale_factor))
		archer.max_hp = int(ceil(archer.max_hp * scale_factor))
		archer.current_hp = archer.max_hp
		archer.attacks_per_second *= 1.0 + power * 0.05
		archer.health_bar.max_value = archer.max_hp
		archer.health_bar.value = archer.current_hp
		archer.update_scale()
	# Necromancy: each stack gives summoned archers 25% of the summoner's bonus stats
	if summoner.necromancy_stacks > 0:
		var pct := summoner.necromancy_stacks * 0.25
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
	_save_squad()
	_hide_shop()
	_hide_info_panel()
	result_label.text = ""
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
	_update_ui()

func _on_game_over() -> void:
	result_label.text = "GAME OVER"
	result_label.add_theme_color_override("font_color", Color.RED)
	ready_button.disabled = true
	_hide_shop()

# ── UI Updates ──────────────────────────────────────────────

func _update_ui() -> void:
	round_label.text = "Round %d/%d" % [GameManager.current_round, GameManager.MAX_ROUNDS]
	lives_label.text = "Lives: %d" % GameManager.lives
	gold_label.text = "Gold: %d" % GameManager.gold
	var player_count := board.get_units_on_team(Unit.Team.PLAYER).size()
	cap_label.text = "Squad: %d" % player_count

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
	var header_text := "%s\n%s  (Cost: %dg)" % [unit.unit_data.unit_name, unit.unit_data.unit_class, unit.unit_data.farm_cost]
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

func _hide_info_panel() -> void:
	info_scroll.visible = false
	_info_unit = null
