class_name MapCanvas extends Control

var overlay = null  # MapOverlay reference

func _draw() -> void:
	if not overlay or overlay.map_data.is_empty():
		return

	var map: Dictionary = overlay.map_data
	var available: Array = map.get("available_node_ids", [])
	var visited: Array = map.get("visited_node_ids", [])

	# Build id -> position lookup
	var positions := {}
	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			positions[node["id"]] = Vector2(node["position"]["x"], node["position"]["y"])

	# Draw act divider labels
	for act_idx in range(map["acts"].size()):
		var act_data: Dictionary = map["acts"][act_idx]
		var act_names := ["I", "II", "III"]
		var min_y := 99999.0
		for node in act_data["nodes"]:
			var ny: float = node["position"]["y"]
			if ny < min_y:
				min_y = ny
		var label_pos := Vector2(250, min_y - 35)
		draw_string(ThemeDB.fallback_font, label_pos, "— ACT %s —" % act_names[act_idx],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.7, 0.65, 0.5, 0.8))

	# Draw connections — two passes: default first, then visited path on top
	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			var from_pos: Vector2 = positions.get(node["id"], Vector2.ZERO)
			for conn_id in node["connections"]:
				var to_pos: Vector2 = positions.get(conn_id, Vector2.ZERO)
				# Skip visited path connections (drawn in second pass)
				if node["id"] in visited and conn_id in visited:
					continue
				var line_color: Color
				if (node["id"] in visited or node["id"] in available) and conn_id in available:
					line_color = Color(1.0, 1.0, 1.0, 0.6)
				else:
					line_color = Color(0.3, 0.3, 0.3, 0.4)
				_draw_dashed_line(from_pos, to_pos, line_color, 2.0, 8.0, 4.0)

	# Second pass: draw visited path as solid bright lines
	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			if node["id"] not in visited:
				continue
			var from_pos: Vector2 = positions.get(node["id"], Vector2.ZERO)
			for conn_id in node["connections"]:
				if conn_id in visited:
					var to_pos: Vector2 = positions.get(conn_id, Vector2.ZERO)
					draw_line(from_pos, to_pos, Color(0.9, 0.8, 0.4, 0.8), 3.0)

	# Draw node circles
	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			var pos := Vector2(node["position"]["x"], node["position"]["y"])
			var ntype: int = node["type"]
			var node_color: Color = MapData.NODE_COLORS.get(ntype, Color.WHITE)
			var nid: int = node["id"]

			if nid in visited:
				draw_circle(pos, 30.0, node_color.darkened(0.4) * Color(1, 1, 1, 0.5))
				draw_arc(pos, 30.0, 0, TAU, 32, Color(0.9, 0.8, 0.4, 0.7), 2.0)
				var check_start := pos + Vector2(-7, 1)
				var check_mid := pos + Vector2(-2, 6)
				var check_end := pos + Vector2(8, -6)
				draw_line(check_start, check_mid, Color(0.9, 0.85, 0.4, 0.9), 2.5)
				draw_line(check_mid, check_end, Color(0.9, 0.85, 0.4, 0.9), 2.5)
			elif nid in available:
				draw_circle(pos, 34.0, node_color * Color(1, 1, 1, 0.15))
				draw_arc(pos, 32.0, 0, TAU, 32, node_color.lightened(0.3), 2.5)
			else:
				draw_circle(pos, 30.0, node_color.darkened(0.6) * Color(1, 1, 1, 0.25))


func _draw_dashed_line(from: Vector2, to: Vector2, col: Color, w: float, dash_len: float, gap_len: float) -> void:
	var dir := (to - from)
	var length := dir.length()
	if length < 1.0:
		return
	dir = dir / length
	var p := 0.0
	while p < length:
		var end_p := minf(p + dash_len, length)
		draw_line(from + dir * p, from + dir * end_p, col, w)
		p = end_p + gap_len
