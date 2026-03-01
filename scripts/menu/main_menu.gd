extends Control

var settings_overlay: ColorRect

func _ready() -> void:
	_build_main_buttons()
	_build_settings_overlay()

func _build_main_buttons() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

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
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	vbox.add_child(single_player)

	var multiplayer_btn := Button.new()
	multiplayer_btn.text = "Multiplayer (Coming Soon)"
	multiplayer_btn.custom_minimum_size = Vector2(260, 50)
	multiplayer_btn.disabled = true
	vbox.add_child(multiplayer_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(260, 50)
	settings_btn.pressed.connect(func(): settings_overlay.visible = true)
	vbox.add_child(settings_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(260, 50)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

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
	panel.custom_minimum_size = Vector2(420, 400)
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

	# ── Back Button ──
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.pressed.connect(func(): settings_overlay.visible = false)
	vbox.add_child(back_btn)

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

func _create_checkbox(label_text: String, initial: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = initial
	cb.toggled.connect(on_toggle)
	return cb
