extends Node

var settings_path: String:
	get: return ProfileManager.get_profile_path("settings.cfg")

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var screen_shake: bool = true
var show_damage_numbers: bool = true
var resolution: Vector2i = Vector2i(1280, 720)

func _ready() -> void:
	ProfileManager.profile_changed.connect(_on_profile_changed)
	load_settings()
	_apply_audio()
	_apply_graphics()

func _on_profile_changed(_profile_id: String) -> void:
	load_settings()
	_apply_audio()
	_apply_graphics()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	save_settings()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_graphics()
	save_settings()

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	_apply_graphics()
	save_settings()

func set_screen_shake(enabled: bool) -> void:
	screen_shake = enabled
	save_settings()

func set_show_damage_numbers(enabled: bool) -> void:
	show_damage_numbers = enabled
	save_settings()

func set_resolution(res: Vector2i) -> void:
	resolution = res
	_apply_graphics()
	save_settings()

func _apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
		AudioServer.set_bus_mute(master_idx, master_volume <= 0.0)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
		AudioServer.set_bus_mute(sfx_idx, sfx_volume <= 0.0)

func _apply_graphics() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		var screen_size := DisplayServer.screen_get_size()
		var win_pos := (screen_size - resolution) / 2
		DisplayServer.window_set_position(win_pos)
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("graphics", "fullscreen", fullscreen)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "resolution_x", resolution.x)
	config.set_value("graphics", "resolution_y", resolution.y)
	config.set_value("auxiliary", "screen_shake", screen_shake)
	config.set_value("auxiliary", "show_damage_numbers", show_damage_numbers)
	config.save(settings_path)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	master_volume = config.get_value("audio", "master_volume", 1.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	fullscreen = config.get_value("graphics", "fullscreen", false)
	vsync = config.get_value("graphics", "vsync", true)
	resolution.x = config.get_value("graphics", "resolution_x", 1280)
	resolution.y = config.get_value("graphics", "resolution_y", 720)
	screen_shake = config.get_value("auxiliary", "screen_shake", true)
	show_damage_numbers = config.get_value("auxiliary", "show_damage_numbers", true)
