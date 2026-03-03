extends Node

signal profile_changed(profile_id: String)

const PROFILES_CFG_PATH: String = "user://profiles.cfg"
const PROFILES_DIR: String = "user://profiles/"

var active_profile_id: String = ""
var _profiles: Array[Dictionary] = []  # [{id, name, hero_class}]


func _ready() -> void:
	_ensure_profiles_dir()
	if _load_profiles_cfg():
		return
	# First launch or missing config — check for legacy files to migrate
	if _has_legacy_files():
		_migrate_legacy()
	else:
		_create_default_profile()


# ── Public API ───────────────────────────────────────────────

func get_profile_path(filename: String) -> String:
	return PROFILES_DIR + active_profile_id + "/" + filename


func list_profiles() -> Array[Dictionary]:
	return _profiles.duplicate()


func create_profile(profile_name: String, hero_class: String = "") -> String:
	var id := _generate_id(profile_name)
	var dir_path := PROFILES_DIR + id + "/"
	DirAccess.make_dir_recursive_absolute(dir_path)

	# Write profile.cfg
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "name", profile_name)
	cfg.set_value("profile", "hero_class", hero_class)
	cfg.set_value("stats", "wins", 0)
	cfg.set_value("stats", "losses", 0)
	cfg.set_value("stats", "highest_round", 0)
	cfg.save(dir_path + "profile.cfg")

	_profiles.append({"id": id, "name": profile_name, "hero_class": hero_class})
	_save_profiles_cfg()
	return id


func switch_profile(id: String) -> void:
	if id == active_profile_id:
		return
	active_profile_id = id
	_save_profiles_cfg()
	profile_changed.emit(id)


func delete_profile(id: String) -> void:
	# Don't delete the last profile
	if _profiles.size() <= 1:
		return
	# Remove directory
	var dir_path := PROFILES_DIR + id + "/"
	_remove_dir_recursive(dir_path)
	# Remove from list
	for i in range(_profiles.size()):
		if _profiles[i].id == id:
			_profiles.remove_at(i)
			break
	# If we deleted the active profile, switch to the first remaining one
	if active_profile_id == id:
		active_profile_id = _profiles[0].id
	_save_profiles_cfg()
	if id == active_profile_id:
		profile_changed.emit(active_profile_id)


func get_active_profile_name() -> String:
	for p in _profiles:
		if p.id == active_profile_id:
			return p.name
	return "Default"


func record_win(round_reached: int) -> void:
	var cfg_path := get_profile_path("profile.cfg")
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	var wins: int = cfg.get_value("stats", "wins", 0) + 1
	var highest: int = cfg.get_value("stats", "highest_round", 0)
	cfg.set_value("stats", "wins", wins)
	if round_reached > highest:
		cfg.set_value("stats", "highest_round", round_reached)
	cfg.save(cfg_path)


func record_loss(round_reached: int) -> void:
	var cfg_path := get_profile_path("profile.cfg")
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	var losses: int = cfg.get_value("stats", "losses", 0) + 1
	var highest: int = cfg.get_value("stats", "highest_round", 0)
	cfg.set_value("stats", "losses", losses)
	if round_reached > highest:
		cfg.set_value("stats", "highest_round", round_reached)
	cfg.save(cfg_path)


# ── Internal ─────────────────────────────────────────────────

func _ensure_profiles_dir() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILES_DIR)


func _generate_id(profile_name: String) -> String:
	var raw := "%s_%d" % [profile_name, Time.get_unix_time_from_system()]
	return raw.md5_text().left(8)


func _load_profiles_cfg() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILES_CFG_PATH) != OK:
		return false
	active_profile_id = cfg.get_value("global", "active_profile_id", "")
	var count: int = cfg.get_value("profiles", "count", 0)
	_profiles.clear()
	for i in range(count):
		var id: String = cfg.get_value("profiles", "id_%d" % i, "")
		var pname: String = cfg.get_value("profiles", "name_%d" % i, "Default")
		var hero_class: String = cfg.get_value("profiles", "hero_class_%d" % i, "")
		if id != "":
			_profiles.append({"id": id, "name": pname, "hero_class": hero_class})
	if active_profile_id == "" and not _profiles.is_empty():
		active_profile_id = _profiles[0].id
	return not _profiles.is_empty()


func _save_profiles_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("global", "active_profile_id", active_profile_id)
	cfg.set_value("profiles", "count", _profiles.size())
	for i in range(_profiles.size()):
		cfg.set_value("profiles", "id_%d" % i, _profiles[i].id)
		cfg.set_value("profiles", "name_%d" % i, _profiles[i].name)
		cfg.set_value("profiles", "hero_class_%d" % i, _profiles[i].get("hero_class", ""))
	cfg.save(PROFILES_CFG_PATH)


func _create_default_profile() -> void:
	var id := create_profile("Default")
	active_profile_id = id
	_save_profiles_cfg()


func _has_legacy_files() -> bool:
	return (FileAccess.file_exists("user://settings.cfg")
		or FileAccess.file_exists("user://auth.cfg")
		or FileAccess.file_exists("user://savegame.json")
		or FileAccess.file_exists("user://offline_queue.json")
		or FileAccess.file_exists("user://opponent_cache.json"))


func _migrate_legacy() -> void:
	var id := create_profile("Default")
	active_profile_id = id
	var dir_path := PROFILES_DIR + id + "/"

	var legacy_files := {
		"user://settings.cfg": "settings.cfg",
		"user://auth.cfg": "auth.cfg",
		"user://savegame.json": "savegame.json",
		"user://offline_queue.json": "offline_queue.json",
		"user://opponent_cache.json": "opponent_cache.json",
	}
	var dir := DirAccess.open("user://")
	if dir:
		for src in legacy_files:
			if FileAccess.file_exists(src):
				dir.rename(src, dir_path + legacy_files[src])

	_save_profiles_cfg()


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	# Remove the now-empty directory
	DirAccess.remove_absolute(path)
