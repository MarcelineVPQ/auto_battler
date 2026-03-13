extends Control

var settings_overlay: ColorRect
var leaderboard_overlay: ColorRect
var leaderboard_entries_container: VBoxContainer
var leaderboard_loading_label: Label
var leaderboard_title: Label
var ranked_btn: Button
var sp_continue_btn: Button
var pvp_continue_btn: Button
var status_label: Label
var profile_dropdown: OptionButton
var profile_create_overlay: ColorRect

func _ready() -> void:
	_build_main_buttons()
	_build_settings_overlay()
	_build_leaderboard_overlay()
	_build_profile_create_overlay()
	# Update ranked button state when auth completes (only if BackendManager is loaded)
	var bm = Engine.get_singleton("BackendManager") if Engine.has_singleton("BackendManager") else null
	if bm == null:
		bm = get_node_or_null("/root/BackendManager")
	if bm:
		bm.auth_completed.connect(_on_auth_completed)
		bm.connection_changed.connect(_on_connection_changed)
		bm.leaderboard_fetched.connect(_on_leaderboard_fetched)
	_update_status()

func _build_main_buttons() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Profile selector row
	var profile_row := HBoxContainer.new()
	profile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	profile_row.add_theme_constant_override("separation", 4)
	vbox.add_child(profile_row)

	profile_dropdown = OptionButton.new()
	profile_dropdown.custom_minimum_size = Vector2(180, 36)
	profile_row.add_child(profile_dropdown)
	_populate_profile_dropdown()
	profile_dropdown.item_selected.connect(_on_profile_selected)

	var add_profile_btn := Button.new()
	add_profile_btn.text = "+"
	add_profile_btn.custom_minimum_size = Vector2(36, 36)
	add_profile_btn.pressed.connect(func(): profile_create_overlay.visible = true)
	profile_row.add_child(add_profile_btn)

	var title := Label.new()
	title.text = "Auto Battler"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var single_player := Button.new()
	single_player.text = "Single Player"
	single_player.custom_minimum_size = Vector2(260, 50)
	single_player.pressed.connect(func():
		GameManager.set_meta("ranked_mode", false)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	vbox.add_child(single_player)

	# Continue button for Single Player
	sp_continue_btn = Button.new()
	sp_continue_btn.text = "Continue"
	sp_continue_btn.custom_minimum_size = Vector2(220, 36)
	sp_continue_btn.visible = GameManager.has_save_for_mode(false)
	sp_continue_btn.pressed.connect(func():
		GameManager.set_meta("ranked_mode", false)
		GameManager.set_meta("loading_save", true)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	vbox.add_child(sp_continue_btn)

	ranked_btn = Button.new()
	ranked_btn.text = "Ranked PvP"
	ranked_btn.custom_minimum_size = Vector2(260, 50)
	ranked_btn.disabled = true  # Enabled when BackendManager authenticates
	ranked_btn.pressed.connect(func():
		GameManager.set_meta("ranked_mode", true)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	vbox.add_child(ranked_btn)

	# Continue button for Ranked PvP
	pvp_continue_btn = Button.new()
	pvp_continue_btn.text = "Continue"
	pvp_continue_btn.custom_minimum_size = Vector2(220, 36)
	pvp_continue_btn.visible = false
	pvp_continue_btn.pressed.connect(func():
		GameManager.set_meta("ranked_mode", true)
		GameManager.set_meta("loading_save", true)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	vbox.add_child(pvp_continue_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(260, 50)
	settings_btn.pressed.connect(func(): settings_overlay.visible = true)
	vbox.add_child(settings_btn)

	var leaderboard_btn := Button.new()
	leaderboard_btn.text = "Leaderboard"
	leaderboard_btn.custom_minimum_size = Vector2(260, 50)
	leaderboard_btn.pressed.connect(_on_leaderboard_pressed)
	vbox.add_child(leaderboard_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(260, 50)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

	# Online status label
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(status_label)

func _build_settings_overlay() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.color = Color(0, 0, 0, 0.8)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.visible = false
	add_child(settings_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 500)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# ── Audio Section ──
	var audio_label := Label.new()
	audio_label.text = "Audio"
	audio_label.add_theme_font_size_override("font_size", 18)
	audio_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(audio_label)

	vbox.add_child(_create_slider("Master Volume", SettingsManager.master_volume, func(val: float):
		SettingsManager.set_master_volume(val)
	))
	vbox.add_child(_create_slider("SFX Volume", SettingsManager.sfx_volume, func(val: float):
		SettingsManager.set_sfx_volume(val)
	))

	# ── Graphics Section ──
	var gfx_label := Label.new()
	gfx_label.text = "Graphics"
	gfx_label.add_theme_font_size_override("font_size", 18)
	gfx_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(gfx_label)

	vbox.add_child(_create_checkbox("Fullscreen", SettingsManager.fullscreen, func(toggled: bool):
		SettingsManager.set_fullscreen(toggled)
	))
	vbox.add_child(_create_checkbox("VSync", SettingsManager.vsync, func(toggled: bool):
		SettingsManager.set_vsync(toggled)
	))
	vbox.add_child(_create_resolution_picker())

	# ── Auxiliary Section ──
	var aux_label := Label.new()
	aux_label.text = "Auxiliary"
	aux_label.add_theme_font_size_override("font_size", 18)
	aux_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(aux_label)

	vbox.add_child(_create_checkbox("Screen Shake", SettingsManager.screen_shake, func(toggled: bool):
		SettingsManager.set_screen_shake(toggled)
	))
	vbox.add_child(_create_checkbox("Damage Numbers", SettingsManager.show_damage_numbers, func(toggled: bool):
		SettingsManager.set_show_damage_numbers(toggled)
	))

	# Combat timer slider (30s–300s)
	var timer_hbox := HBoxContainer.new()
	timer_hbox.add_theme_constant_override("separation", 10)

	var timer_label := Label.new()
	timer_label.text = "Combat Timer"
	timer_label.custom_minimum_size = Vector2(140, 0)
	timer_hbox.add_child(timer_label)

	var timer_slider := HSlider.new()
	timer_slider.min_value = 30.0
	timer_slider.max_value = 300.0
	timer_slider.step = 10.0
	timer_slider.value = SettingsManager.combat_timer
	timer_slider.custom_minimum_size = Vector2(180, 20)
	timer_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_hbox.add_child(timer_slider)

	var timer_value_label := Label.new()
	timer_value_label.text = "%ds" % int(SettingsManager.combat_timer)
	timer_value_label.custom_minimum_size = Vector2(35, 0)
	timer_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_hbox.add_child(timer_value_label)

	timer_slider.value_changed.connect(func(val: float):
		timer_value_label.text = "%ds" % int(val)
		SettingsManager.set_combat_timer(val)
	)
	vbox.add_child(timer_hbox)

	# ── Back Button ──
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.pressed.connect(func(): settings_overlay.visible = false)
	vbox.add_child(back_btn)

# ── Leaderboard Overlay ──

func _build_leaderboard_overlay() -> void:
	leaderboard_overlay = ColorRect.new()
	leaderboard_overlay.color = Color(0, 0, 0, 0.8)
	leaderboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leaderboard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	leaderboard_overlay.visible = false
	add_child(leaderboard_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leaderboard_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 500)
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

	leaderboard_title = Label.new()
	leaderboard_title.text = "Leaderboard"
	leaderboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_title.add_theme_font_size_override("font_size", 28)
	leaderboard_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(leaderboard_title)

	leaderboard_loading_label = Label.new()
	leaderboard_loading_label.text = "Loading..."
	leaderboard_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_loading_label.add_theme_font_size_override("font_size", 14)
	leaderboard_loading_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(leaderboard_loading_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 360)
	vbox.add_child(scroll)

	leaderboard_entries_container = VBoxContainer.new()
	leaderboard_entries_container.add_theme_constant_override("separation", 4)
	leaderboard_entries_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(leaderboard_entries_container)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 36)
	close_btn.pressed.connect(func(): leaderboard_overlay.visible = false)
	vbox.add_child(close_btn)

func _on_leaderboard_pressed() -> void:
	leaderboard_overlay.visible = true
	leaderboard_loading_label.visible = true
	# Clear old entries
	for child in leaderboard_entries_container.get_children():
		child.queue_free()
	var bm = get_node_or_null("/root/BackendManager")
	if bm:
		bm.fetch_leaderboard()
	else:
		# No backend — show local profiles directly
		_on_leaderboard_fetched(ProfileManager.get_all_profile_stats())

func _on_leaderboard_fetched(entries: Array) -> void:
	leaderboard_loading_label.visible = false
	for child in leaderboard_entries_container.get_children():
		child.queue_free()

	var is_local: bool = not entries.is_empty() and entries[0].get("is_local", false)
	leaderboard_title.text = "Leaderboard (Local)" if is_local else "Leaderboard"

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No data available"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		leaderboard_entries_container.add_child(empty_label)
		return
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var rank_label := Label.new()
		rank_label.text = "#%d" % entry.rank
		rank_label.custom_minimum_size = Vector2(40, 0)
		rank_label.add_theme_font_size_override("font_size", 14)
		if entry.rank <= 3:
			rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		row.add_child(rank_label)

		var entry_is_self: bool = entry.get("is_self", false)

		var name_label := Label.new()
		name_label.text = str(entry.player_name) + (" (You)" if entry_is_self else "")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 14)
		if entry_is_self:
			name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		row.add_child(name_label)

		if is_local:
			var wl_label := Label.new()
			wl_label.text = "%dW / %dL" % [entry.get("wins", 0), entry.get("losses", 0)]
			wl_label.custom_minimum_size = Vector2(80, 0)
			wl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			wl_label.add_theme_font_size_override("font_size", 14)
			wl_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			row.add_child(wl_label)

		var elo_label := Label.new()
		elo_label.text = str(entry.score)
		elo_label.custom_minimum_size = Vector2(60, 0)
		elo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elo_label.add_theme_font_size_override("font_size", 14)
		elo_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		row.add_child(elo_label)

		leaderboard_entries_container.add_child(row)

# ── Helpers ──

func _create_slider(label_text: String, initial: float, on_change: Callable) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	slider.custom_minimum_size = Vector2(180, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(int(initial * 100))
	value_label.custom_minimum_size = Vector2(35, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float):
		value_label.text = str(int(val * 100))
	)

	return hbox

func _create_resolution_picker() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = "Resolution"
	label.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_idx := 0
	for i in SettingsManager.RESOLUTIONS.size():
		var res: Vector2i = SettingsManager.RESOLUTIONS[i]
		option.add_item("%dx%d" % [res.x, res.y])
		if res == SettingsManager.resolution:
			current_idx = i
	option.selected = current_idx
	option.item_selected.connect(func(idx: int):
		SettingsManager.set_resolution(SettingsManager.RESOLUTIONS[idx])
	)
	hbox.add_child(option)

	return hbox

func _create_checkbox(label_text: String, initial: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = initial
	cb.toggled.connect(on_toggle)
	return cb

func _on_auth_completed(_success: bool) -> void:
	_update_status()

func _on_connection_changed(_online: bool) -> void:
	_update_status()

func _update_status() -> void:
	var bm = get_node_or_null("/root/BackendManager")
	if bm and bm.is_online and bm.is_authenticated:
		ranked_btn.disabled = false
		pvp_continue_btn.visible = GameManager.has_save_for_mode(true)
		if status_label:
			status_label.text = "Online | ELO: %d" % bm.player_rating
			status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		ranked_btn.disabled = true
		pvp_continue_btn.visible = false
		if status_label:
			status_label.text = "Offline | AI Mode Only"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))

# ── Profile System ───────────────────────────────────────────

func _populate_profile_dropdown() -> void:
	profile_dropdown.clear()
	var profiles := ProfileManager.list_profiles()
	var selected_idx := 0
	for i in range(profiles.size()):
		profile_dropdown.add_item(profiles[i].name, i)
		profile_dropdown.set_item_metadata(i, profiles[i].id)
		if profiles[i].id == ProfileManager.active_profile_id:
			selected_idx = i
	profile_dropdown.selected = selected_idx

func _on_profile_selected(idx: int) -> void:
	var id: String = profile_dropdown.get_item_metadata(idx)
	ProfileManager.switch_profile(id)
	_refresh_continue_buttons()

func _refresh_continue_buttons() -> void:
	sp_continue_btn.visible = GameManager.has_save_for_mode(false)
	_update_status()

func _build_profile_create_overlay() -> void:
	profile_create_overlay = ColorRect.new()
	profile_create_overlay.color = Color(0, 0, 0, 0.8)
	profile_create_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_create_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	profile_create_overlay.visible = false
	add_child(profile_create_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile_create_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 280)
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

	var title := Label.new()
	title.text = "New Profile"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	var name_label := Label.new()
	name_label.text = "Profile Name"
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Profile Name"
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(300, 36)
	vbox.add_child(name_edit)

	var class_label := Label.new()
	class_label.text = "Hero Class (optional)"
	class_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(class_label)

	var class_dropdown := OptionButton.new()
	class_dropdown.custom_minimum_size = Vector2(300, 36)
	class_dropdown.add_item("None")
	for class_name_key in HeroVariants.NAME_POOLS.keys():
		class_dropdown.add_item(class_name_key)
	vbox.add_child(class_dropdown)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.pressed.connect(func():
		name_edit.text = ""
		class_dropdown.selected = 0
		profile_create_overlay.visible = false
	)
	btn_row.add_child(cancel_btn)

	var create_btn := Button.new()
	create_btn.text = "Create"
	create_btn.custom_minimum_size = Vector2(120, 36)
	create_btn.pressed.connect(func():
		var pname := name_edit.text.strip_edges()
		if pname == "":
			return
		var hero_class := ""
		if class_dropdown.selected > 0:
			hero_class = class_dropdown.get_item_text(class_dropdown.selected)
		var new_id := ProfileManager.create_profile(pname, hero_class)
		ProfileManager.switch_profile(new_id)
		_populate_profile_dropdown()
		_refresh_continue_buttons()
		name_edit.text = ""
		class_dropdown.selected = 0
		profile_create_overlay.visible = false
	)
	btn_row.add_child(create_btn)
