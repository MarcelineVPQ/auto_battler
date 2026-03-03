class_name OpponentCache
extends RefCounted

## Local cache of opponent snapshots for offline fallback.
## Stores up to MAX_ENTRIES snapshots in user://opponent_cache.json.
## Entries expire after EXPIRY_HOURS.

const MAX_ENTRIES: int = 30
const EXPIRY_HOURS: int = 48

var cache_path: String = "user://opponent_cache.json"
var entries: Array = []


func _init(path: String = "user://opponent_cache.json") -> void:
	cache_path = path
	load_cache()


## Load cached entries from disk.
func load_cache() -> void:
	entries.clear()
	if not FileAccess.file_exists(cache_path):
		return
	var file := FileAccess.open(cache_path, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data = json.data
	if data is Array:
		entries = data
	_purge_expired()


## Save current entries to disk.
func save_cache() -> void:
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(entries))
	file.close()


## Add opponent snapshots to cache (from a successful fetch).
func add_opponents(opponents: Array) -> void:
	var now := Time.get_unix_time_from_system()
	for opp in opponents:
		var cached: Dictionary = opp.duplicate(true)
		cached["cached_at"] = now
		entries.append(cached)
	# Trim to max size — remove oldest first
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	save_cache()


## Remove entries older than EXPIRY_HOURS.
func _purge_expired() -> void:
	var now := Time.get_unix_time_from_system()
	var cutoff := now - (EXPIRY_HOURS * 3600)
	var fresh: Array = []
	for entry in entries:
		if entry.get("cached_at", 0) >= cutoff:
			fresh.append(entry)
	entries = fresh


## Get cached opponents closest to the given rating.
## Returns up to `count` entries sorted by rating proximity.
func get_opponents_for_rating(rating: int, count: int = 3) -> Array:
	_purge_expired()
	if entries.is_empty():
		return []

	# Sort by distance to target rating
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a, b):

		var dist_a: int = abs(a.get("rating_at_time", 1000) - rating)
		var dist_b: int = abs(b.get("rating_at_time", 1000) - rating)
		return dist_a < dist_b
	)

	var result: Array = []
	for i in range(mini(count, sorted.size())):
		result.append(sorted[i])
	return result


## Check if cache has any usable entries.
func has_entries() -> bool:
	_purge_expired()
	return not entries.is_empty()


## Clear entire cache.
func clear() -> void:
	entries.clear()
	save_cache()
