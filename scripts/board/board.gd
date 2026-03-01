class_name Board
extends Node2D

const ARENA_WIDTH: float = 960.0
const ARENA_HEIGHT: float = 480.0
const DIVIDER_X: float = ARENA_WIDTH / 2.0

# Placement grid (8x8 within each half — 60x60 cells)
const GRID_COLS: int = 8
const GRID_ROWS: int = 8
const GRID_CELL_W: float = DIVIDER_X / GRID_COLS   # 60
const GRID_CELL_H: float = ARENA_HEIGHT / GRID_ROWS # 60
const GRID_DOT_RADIUS: float = 5.0

var all_units: Array[Unit] = []
var selected_unit: Unit = null
var merge_highlight_unit: Unit = null
var show_grid: bool = false
var targeting_mode: bool = false

@onready var units_container: Node2D = $Units

func _process(_delta: float) -> void:
	if selected_unit and is_instance_valid(selected_unit) and not selected_unit.is_dead:
		queue_redraw()

func _draw() -> void:
	# Arena background
	var arena_rect := Rect2(0, 0, ARENA_WIDTH, ARENA_HEIGHT)

	# Player half (left) — slightly lighter
	var player_half := Rect2(0, 0, DIVIDER_X, ARENA_HEIGHT)
	draw_rect(player_half, Color(0.3, 0.18, 0.12), true)

	# Enemy half (right) — darker tint
	var enemy_half := Rect2(DIVIDER_X, 0, DIVIDER_X, ARENA_HEIGHT)
	draw_rect(enemy_half, Color(0.25, 0.15, 0.1), true)

	# Arena border
	draw_rect(arena_rect, Color(0.4, 0.3, 0.2), false, 3.0)

	# Center divider line (vertical)
	draw_line(
		Vector2(DIVIDER_X, 0),
		Vector2(DIVIDER_X, ARENA_HEIGHT),
		Color(0.5, 0.4, 0.3, 0.3), 1.0
	)

	# Draw placement grid dots when dragging
	if show_grid:
		for col in range(GRID_COLS):
			for row in range(GRID_ROWS):
				# Player grid dots (left half)
				var dot_pos := _grid_cell_center(col, row)
				var occupied := _is_grid_slot_occupied(col, row)
				if occupied:
					draw_circle(dot_pos, GRID_DOT_RADIUS, Color(1, 1, 1, 0.1))
				else:
					draw_circle(dot_pos, GRID_DOT_RADIUS, Color(1, 1, 1, 0.35))
					draw_arc(dot_pos, GRID_DOT_RADIUS, 0, TAU, 16, Color(1, 1, 1, 0.5), 1.0)
				# Enemy grid dots (right half, reddish tint)
				var enemy_dot := _enemy_grid_cell_center(col, row)
				var e_occupied := _is_enemy_grid_slot_occupied(col, row)
				if e_occupied:
					draw_circle(enemy_dot, GRID_DOT_RADIUS, Color(1, 0.4, 0.3, 0.1))
				else:
					draw_circle(enemy_dot, GRID_DOT_RADIUS, Color(1, 0.4, 0.3, 0.25))
					draw_arc(enemy_dot, GRID_DOT_RADIUS, 0, TAU, 16, Color(1, 0.4, 0.3, 0.35), 1.0)

	# Draw green rings around player units during upgrade targeting
	if targeting_mode:
		for unit in all_units:
			if unit.is_dead or unit.team != Unit.Team.PLAYER:
				continue
			draw_arc(unit.position, 28.0, 0, TAU, 32, Color(0.2, 1.0, 0.3, 0.7), 2.0)

	# Draw gold ring around merge target
	if merge_highlight_unit and is_instance_valid(merge_highlight_unit) and not merge_highlight_unit.is_dead:
		var m_pos := merge_highlight_unit.position
		draw_arc(m_pos, 32.0, 0, TAU, 32, Color(1.0, 0.84, 0.0, 0.9), 3.0)
		draw_arc(m_pos, 36.0, 0, TAU, 32, Color(1.0, 0.84, 0.0, 0.4), 1.5)

	# Draw range circles for selected unit
	if selected_unit and is_instance_valid(selected_unit) and not selected_unit.is_dead:
		var local_pos := selected_unit.position
		# Attack range — solid blue circle
		draw_arc(local_pos, selected_unit.attack_range, 0, TAU, 64, Color(0.5, 0.8, 1.0, 0.4), 2.0)
		draw_string(
			ThemeDB.fallback_font,
			local_pos + Vector2(-40, selected_unit.attack_range + 16),
			"Attack Range",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(0.5, 0.8, 1.0, 0.6)
		)
		# Ability range — dashed gold circle
		var abl_r: float = selected_unit.ability_range
		var dash_count := 24
		var dash_arc := TAU / float(dash_count) * 0.6
		var gap_arc := TAU / float(dash_count) * 0.4
		var abl_color := Color(1.0, 0.82, 0.3, 0.45)
		for i in dash_count:
			var start_angle := float(i) * (dash_arc + gap_arc)
			draw_arc(local_pos, abl_r, start_angle, start_angle + dash_arc, 8, abl_color, 2.0)
		draw_string(
			ThemeDB.fallback_font,
			local_pos + Vector2(-40, -abl_r - 6),
			"Ability Range",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12,
			Color(1.0, 0.82, 0.3, 0.6)
		)

# Returns the center position of a grid cell
func _grid_cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		col * GRID_CELL_W + GRID_CELL_W / 2.0,
		row * GRID_CELL_H + GRID_CELL_H / 2.0
	)

# Check if a grid slot is occupied by a player unit (excluding the dragged unit)
func _is_grid_slot_occupied(col: int, row: int, exclude: Unit = null) -> bool:
	var center := _grid_cell_center(col, row)
	for unit in all_units:
		if unit == exclude or unit.is_dead or unit.team != Unit.Team.PLAYER:
			continue
		if unit.position.distance_to(center) < GRID_CELL_W * 0.4:
			return true
	return false

# Snap a position to the nearest grid cell center
func snap_to_grid(pos: Vector2, exclude: Unit = null) -> Vector2:
	var best_pos := pos
	var best_dist := INF
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			if _is_grid_slot_occupied(col, row, exclude):
				continue
			var center := _grid_cell_center(col, row)
			var dist := pos.distance_to(center)
			if dist < best_dist:
				best_dist = dist
				best_pos = center
	return best_pos

# Returns the center position of an enemy grid cell (right half)
func _enemy_grid_cell_center(col: int, row: int) -> Vector2:
	return Vector2(
		DIVIDER_X + col * GRID_CELL_W + GRID_CELL_W / 2.0,
		row * GRID_CELL_H + GRID_CELL_H / 2.0
	)

# Check if an enemy grid slot is occupied
func _is_enemy_grid_slot_occupied(col: int, row: int, exclude: Unit = null) -> bool:
	var center := _enemy_grid_cell_center(col, row)
	for unit in all_units:
		if unit == exclude or unit.is_dead or unit.team != Unit.Team.ENEMY:
			continue
		if unit.position.distance_to(center) < GRID_CELL_W * 0.4:
			return true
	return false

# Snap a position to the nearest enemy grid cell center
func snap_to_enemy_grid(pos: Vector2, exclude: Unit = null) -> Vector2:
	var best_pos := pos
	var best_dist := INF
	for col in range(GRID_COLS):
		for row in range(GRID_ROWS):
			if _is_enemy_grid_slot_occupied(col, row, exclude):
				continue
			var center := _enemy_grid_cell_center(col, row)
			var dist := pos.distance_to(center)
			if dist < best_dist:
				best_dist = dist
				best_pos = center
	return best_pos

func add_unit(unit: Unit) -> void:
	all_units.append(unit)
	if unit.get_parent() != units_container:
		units_container.add_child(unit)

func remove_unit(unit: Unit) -> void:
	all_units.erase(unit)
	if selected_unit == unit:
		selected_unit = null
		queue_redraw()

func get_units_on_team(team: Unit.Team) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in all_units:
		if u.team == team and not u.is_dead:
			result.append(u)
	return result

func find_nearest_enemy(unit: Unit) -> Unit:
	var enemy_team := Unit.Team.PLAYER if unit.team == Unit.Team.ENEMY else Unit.Team.ENEMY
	var enemies := get_units_on_team(enemy_team)
	var nearest: Unit = null
	var best_dist: float = INF
	for enemy in enemies:
		var dist := unit.position.distance_to(enemy.position)
		if dist < best_dist:
			best_dist = dist
			nearest = enemy
	return nearest

func get_unit_at(local_pos: Vector2, radius: float = 30.0, exclude: Unit = null) -> Unit:
	var closest: Unit = null
	var closest_dist: float = radius
	for unit in all_units:
		if unit.is_dead or unit == exclude:
			continue
		var dist := unit.position.distance_to(local_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit
	return closest

func is_in_player_half(local_pos: Vector2) -> bool:
	return local_pos.x >= 0 and local_pos.x <= DIVIDER_X \
		and local_pos.y >= 0 and local_pos.y <= ARENA_HEIGHT

func clamp_to_player_half(local_pos: Vector2, margin: float = 25.0) -> Vector2:
	return Vector2(
		clampf(local_pos.x, margin, DIVIDER_X - margin),
		clampf(local_pos.y, margin, ARENA_HEIGHT - margin)
	)

func select_unit(unit: Unit) -> void:
	selected_unit = unit
	queue_redraw()

func deselect() -> void:
	selected_unit = null
	queue_redraw()

func clear_all() -> void:
	for unit in all_units.duplicate():
		if is_instance_valid(unit):
			unit.queue_free()
	all_units.clear()
	selected_unit = null
	queue_redraw()
