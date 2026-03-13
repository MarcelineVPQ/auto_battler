class_name MapOverlay extends ColorRect

signal node_selected(node_id: int)

const NODE_CLICK_SIZE := Vector2(58, 58)

var map_data: Dictionary = {}
var _canvas: MapCanvas
var _scroll: ScrollContainer
var _node_buttons: Dictionary = {}  # node_id -> Button
var _header_label: Label
var _lives_label: Label
var _gold_label: Label
var _pulse_tweens: Array = []

func _init() -> void:
	color = Color(0.05, 0.05, 0.08, 0.95)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func build() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# Header
	var header := _build_header()
	root_vbox.add_child(header)

	# Scroll area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(_scroll)

	_canvas = MapCanvas.new()
	_canvas.overlay = self
	_scroll.add_child(_canvas)

	# Footer legend
	var footer := _build_legend()
	root_vbox.add_child(footer)


func _build_header() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	_header_label = Label.new()
	_header_label.text = "Act I"
	_header_label.add_theme_font_size_override("font_size", 22)
	_header_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	hbox.add_child(_header_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_lives_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hbox.add_child(_gold_label)

	return panel


func _build_legend() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	var types_to_show := [
		MapData.NodeType.BATTLE, MapData.NodeType.ELITE, MapData.NodeType.BOSS,
		MapData.NodeType.REST, MapData.NodeType.SHOP, MapData.NodeType.TREASURE,
		MapData.NodeType.UNKNOWN,
	]
	for t in types_to_show:
		var lbl := Label.new()
		lbl.text = "%s %s" % [MapData.NODE_SYMBOLS[t], MapData.NODE_TYPE_NAMES[t]]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", MapData.NODE_COLORS[t])
		hbox.add_child(lbl)

	return panel


func refresh(map: Dictionary) -> void:
	map_data = map
	_clear_nodes()

	# Update header
	var act_names := ["I", "II", "III"]
	var act_idx: int = clampi(map.get("current_act", 1) - 1, 0, 2)
	_header_label.text = "Act %s — Choose Your Path" % act_names[act_idx]
	_lives_label.text = "Lives: %d" % GameManager.lives
	_gold_label.text = "Gold: %d" % GameManager.gold

	# Calculate canvas size
	var max_y := 0.0
	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			var ny: float = node["position"]["y"]
			if ny > max_y:
				max_y = ny
	_canvas.custom_minimum_size = Vector2(600, max_y + 100)

	# Create node buttons
	var available: Array = map.get("available_node_ids", [])
	var visited: Array = map.get("visited_node_ids", [])

	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			var btn := Button.new()
			var nid: int = node["id"]
			var ntype: int = node["type"]
			btn.custom_minimum_size = NODE_CLICK_SIZE
			btn.position = Vector2(node["position"]["x"] - NODE_CLICK_SIZE.x / 2, node["position"]["y"] - NODE_CLICK_SIZE.y / 2)
			btn.text = MapData.NODE_SYMBOLS.get(ntype, "?")
			btn.add_theme_font_size_override("font_size", 24)

			# Style the button
			var btn_style := StyleBoxFlat.new()
			btn_style.set_corner_radius_all(29)
			btn_style.set_content_margin_all(0)
			var node_color: Color = MapData.NODE_COLORS.get(ntype, Color.WHITE)

			if nid in visited:
				btn_style.bg_color = node_color.darkened(0.5)
				btn_style.border_color = Color(0.8, 0.8, 0.8, 0.6)
				btn_style.set_border_width_all(2)
				btn.modulate = Color(0.7, 0.7, 0.7, 0.9)
				btn.disabled = true
				btn.text = MapData.NODE_SYMBOLS.get(ntype, "?")
			elif nid in available:
				btn_style.bg_color = node_color.darkened(0.25)
				btn_style.border_color = node_color.lightened(0.4)
				btn_style.set_border_width_all(3)
				btn.modulate = Color.WHITE
				btn.disabled = false
				# Pulse animation
				var tween := create_tween()
				tween.set_loops()
				tween.tween_property(btn, "modulate:a", 0.8, 0.6).set_trans(Tween.TRANS_SINE)
				tween.tween_property(btn, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
				_pulse_tweens.append(tween)
			else:
				btn_style.bg_color = node_color.darkened(0.6)
				btn_style.border_color = node_color.darkened(0.3)
				btn_style.set_border_width_all(1)
				btn.modulate = Color(0.5, 0.5, 0.5, 0.6)
				btn.disabled = true

			btn.add_theme_stylebox_override("normal", btn_style)
			btn.add_theme_stylebox_override("hover", btn_style)
			btn.add_theme_stylebox_override("pressed", btn_style)
			btn.add_theme_stylebox_override("disabled", btn_style)

			var node_id := nid
			btn.pressed.connect(func(): _on_node_clicked(node_id))
			btn.tooltip_text = MapData.NODE_TYPE_NAMES.get(ntype, "Unknown")

			_canvas.add_child(btn)
			_node_buttons[nid] = btn

	_canvas.queue_redraw()

	# Auto-scroll to available nodes area
	await get_tree().process_frame
	_auto_scroll_to_available()


func _auto_scroll_to_available() -> void:
	if map_data.is_empty():
		return
	var available: Array = map_data.get("available_node_ids", [])
	if available.is_empty():
		return
	# Find the y position of the first available node
	var target_y := 0.0
	for act_data in map_data["acts"]:
		for node in act_data["nodes"]:
			if node["id"] in available:
				target_y = node["position"]["y"]
				break
	# Scroll to center that position
	var scroll_y := maxf(0, target_y - _scroll.size.y / 2)
	_scroll.scroll_vertical = int(scroll_y)


func _on_node_clicked(node_id: int) -> void:
	node_selected.emit(node_id)


func _clear_nodes() -> void:
	for tween in _pulse_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_pulse_tweens.clear()
	for btn in _node_buttons.values():
		if is_instance_valid(btn):
			btn.queue_free()
	_node_buttons.clear()
