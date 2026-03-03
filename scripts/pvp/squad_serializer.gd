class_name SquadSerializer
extends RefCounted

## Converts between in-game squad format and JSON-safe dictionaries
## for uploading to and downloading from Supabase.

# Maps unit_class strings to their .tres resource paths.
const CLASS_TO_RESOURCE: Dictionary = {
	"Grunt": "res://resources/units/grunt.tres",
	"Priest": "res://resources/units/priest.tres",
	"Tank": "res://resources/units/tank.tres",
	"Herbalist": "res://resources/units/herbalist.tres",
	"Warlock": "res://resources/units/warlock.tres",
	"Archer": "res://resources/units/archer.tres",
	"Assassin": "res://resources/units/assassin.tres",
	"Summoner": "res://resources/units/summoner.tres",
	"Paladin": "res://resources/units/paladin.tres",
	"SkeletonArcher": "res://resources/units/skeleton_archer.tres",
}


## Convert in-memory player_squad array to a JSON-safe array of dicts.
## Replaces UnitData resource references with unit_class strings,
## Vector2 positions with {x, y} dicts.
static func squad_to_json(player_squad: Array) -> Array:
	var result: Array = []
	for entry in player_squad:
		var unit_data: UnitData = entry.get("data")
		if not unit_data:
			continue
		var json_entry: Dictionary = {
			"unit_class": unit_data.unit_class,
			"position": {"x": entry.position.x, "y": entry.position.y},
			"level": entry.get("level", 1),
			"xp": entry.get("xp", 0),
			"display_name": entry.get("display_name", ""),
			"ability_key": entry.get("ability_key", ""),
			"instance_ability_name": entry.get("instance_ability_name", ""),
			"instance_ability_desc": entry.get("instance_ability_desc", ""),
			"necromancy_stacks": entry.get("necromancy_stacks", 0),
			"primed": entry.get("primed", false),
			"poison_power": entry.get("poison_power", 0),
			"thorns_slow": entry.get("thorns_slow", false),
			"lifesteal_pct": entry.get("lifesteal_pct", 0.0),
			"last_stand": entry.get("last_stand", false),
			"relentless": entry.get("relentless", false),
			"sepsis_spread": entry.get("sepsis_spread", 0),
			"living_shield_max": entry.get("living_shield_max", 0),
			"invincible_max": entry.get("invincible_max", 0),
			"haymaker_counter": entry.get("haymaker_counter", 0),
			"legion_master": entry.get("legion_master", false),
		}
		if entry.has("stats"):
			json_entry["stats"] = entry.stats.duplicate()
		if entry.has("applied_upgrades"):
			var upgrades: Array = []
			for upg in entry.applied_upgrades:
				upgrades.append(upg.duplicate())
			json_entry["applied_upgrades"] = upgrades
		result.append(json_entry)
	return result


## Convert a JSON array back to the in-memory squad format.
## Restores UnitData resource references from unit_class strings.
static func json_to_squad(json_array: Array) -> Array:
	var result: Array = []
	for entry in json_array:
		var unit_class: String = entry.get("unit_class", "")
		var data := get_unit_data(unit_class)
		if not data:
			continue
		var pos_dict: Dictionary = entry.get("position", {"x": 0, "y": 0})
		var squad_entry: Dictionary = {
			"data": data,
			"position": Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0)),
			"level": entry.get("level", 1),
			"xp": entry.get("xp", 0),
			"display_name": entry.get("display_name", ""),
			"ability_key": entry.get("ability_key", ""),
			"instance_ability_name": entry.get("instance_ability_name", ""),
			"instance_ability_desc": entry.get("instance_ability_desc", ""),
			"necromancy_stacks": entry.get("necromancy_stacks", 0),
			"primed": entry.get("primed", false),
			"poison_power": entry.get("poison_power", 0),
			"thorns_slow": entry.get("thorns_slow", false),
			"lifesteal_pct": entry.get("lifesteal_pct", 0.0),
			"last_stand": entry.get("last_stand", false),
			"relentless": entry.get("relentless", false),
			"sepsis_spread": entry.get("sepsis_spread", 0),
			"living_shield_max": entry.get("living_shield_max", 0),
			"invincible_max": entry.get("invincible_max", 0),
			"haymaker_counter": entry.get("haymaker_counter", 0),
			"legion_master": entry.get("legion_master", false),
		}
		if entry.has("stats"):
			squad_entry["stats"] = entry.stats.duplicate()
		if entry.has("applied_upgrades"):
			var upgrades: Array = []
			for upg in entry.applied_upgrades:
				upgrades.append(upg.duplicate())
			squad_entry["applied_upgrades"] = upgrades
		else:
			squad_entry["applied_upgrades"] = []
		result.append(squad_entry)
	return result


## Convert a snapshot JSON array into enemy units for spawning.
## Returns array of dicts with {data: UnitData, stats: Dictionary, ...}
## ready for _spawn_opponent_squad() to use.
static func json_to_wave_enemies(json_array: Array) -> Array:
	return json_to_squad(json_array)


## Calculate total DPS of a squad JSON for matchmaking metadata.
static func calculate_squad_dps(json_array: Array) -> float:
	var total := 0.0
	for entry in json_array:
		if entry.has("stats"):
			var s: Dictionary = entry.stats
			total += s.get("damage", 0) * s.get("attacks_per_second", 0.5)
	return total


## Look up UnitData resource by class name string.
static func get_unit_data(unit_class: String) -> UnitData:
	var path: String = CLASS_TO_RESOURCE.get(unit_class, "")
	if path == "":
		return null
	return load(path) as UnitData
