extends Node

## Central Nakama networking autoload.
## Handles device auth, squad snapshot upload/download,
## rating updates via RPC, and offline fallback.
## Drop-in replacement for the Supabase version — same signals & properties.

# ── Nakama Configuration ──
# Point to your Nakama server. Default: local Docker.
const NAKAMA_HOST: String = "127.0.0.1"
const NAKAMA_PORT: int = 7350
const NAKAMA_SERVER_KEY: String = "defaultkey"
const NAKAMA_USE_SSL: bool = false

var _base_url: String:
	get:
		var scheme := "https" if NAKAMA_USE_SSL else "http"
		return "%s://%s:%d" % [scheme, NAKAMA_HOST, NAKAMA_PORT]

# ── Signals (unchanged from Supabase version) ──
signal auth_completed(success: bool)
signal opponents_fetched(opponents: Array)
signal rating_updated(new_rating: int)
signal connection_changed(is_online: bool)
signal squad_uploaded(success: bool)
signal leaderboard_fetched(entries: Array)

# ── Public State (unchanged) ──
var is_authenticated: bool = false
var is_online: bool = false
var player_id: String = ""
var player_rating: int = EloCalculator.DEFAULT_RATING
var player_name: String = ""

# ── Internal Auth State ──
var _session_token: String = ""
var _refresh_token: String = ""
var _device_id: String = ""

var auth_save_path: String:
	get: return ProfileManager.get_profile_path("auth.cfg")
var offline_queue_path: String:
	get: return ProfileManager.get_profile_path("offline_queue.json")
const CONNECTIVITY_CHECK_INTERVAL: float = 60.0

# ── HTTP Request Nodes ──
var http_auth: HTTPRequest
var http_upload: HTTPRequest
var http_fetch: HTTPRequest
var http_rpc: HTTPRequest

# ── Offline Queue ──
var offline_queue: Array = []

# ── Opponent Cache ──
var opponent_cache: OpponentCache = null

# ── Pending result buffer (merges update_rating + update_win_loss) ──
var _pending_result: Dictionary = {}

# ── Timers ──
var connectivity_timer: Timer


func _ready() -> void:
	http_auth = HTTPRequest.new()
	http_auth.name = "HTTPAuth"
	add_child(http_auth)

	http_upload = HTTPRequest.new()
	http_upload.name = "HTTPUpload"
	add_child(http_upload)

	http_fetch = HTTPRequest.new()
	http_fetch.name = "HTTPFetch"
	add_child(http_fetch)

	http_rpc = HTTPRequest.new()
	http_rpc.name = "HTTPRPC"
	add_child(http_rpc)

	opponent_cache = OpponentCache.new(ProfileManager.get_profile_path("opponent_cache.json"))

	_load_offline_queue()

	ProfileManager.profile_changed.connect(_on_profile_changed)

	connectivity_timer = Timer.new()
	connectivity_timer.wait_time = CONNECTIVITY_CHECK_INTERVAL
	connectivity_timer.autostart = true
	connectivity_timer.timeout.connect(_on_connectivity_check)
	add_child(connectivity_timer)

	_load_auth()
	if _session_token != "":
		# Try using existing session; if it fails we'll re-auth
		_check_session()
	else:
		authenticate_anonymous()


func _on_profile_changed(_profile_id: String) -> void:
	is_authenticated = false
	is_online = false
	player_id = ""
	player_rating = EloCalculator.DEFAULT_RATING
	player_name = ""
	_session_token = ""
	_refresh_token = ""
	_device_id = ""
	offline_queue.clear()
	opponent_cache = OpponentCache.new(ProfileManager.get_profile_path("opponent_cache.json"))
	_load_offline_queue()
	_load_auth()
	if _session_token != "":
		_check_session()
	else:
		authenticate_anonymous()


# ── Nakama Headers ──

func _get_basic_auth() -> String:
	return Marshalls.utf8_to_base64("%s:" % NAKAMA_SERVER_KEY)

func _get_auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Basic %s" % _get_basic_auth(),
		"Content-Type: application/json",
	])

func _get_headers() -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Bearer %s" % _session_token,
		"Content-Type: application/json",
	])


# ── Auth Persistence ──

func _load_auth() -> void:
	var config := ConfigFile.new()
	if config.load(auth_save_path) != OK:
		return
	player_id = config.get_value("auth", "player_id", "")
	_session_token = config.get_value("auth", "session_token", "")
	_refresh_token = config.get_value("auth", "refresh_token", "")
	_device_id = config.get_value("auth", "device_id", "")
	player_rating = config.get_value("auth", "rating", EloCalculator.DEFAULT_RATING)
	player_name = config.get_value("auth", "player_name", "")

func _save_auth() -> void:
	var config := ConfigFile.new()
	config.set_value("auth", "player_id", player_id)
	config.set_value("auth", "session_token", _session_token)
	config.set_value("auth", "refresh_token", _refresh_token)
	config.set_value("auth", "device_id", _device_id)
	config.set_value("auth", "rating", player_rating)
	config.set_value("auth", "player_name", player_name)
	config.save(auth_save_path)


# ── Device ID ──

func _get_or_create_device_id() -> String:
	if _device_id != "":
		return _device_id
	# Generate a stable UUID for this device
	var uuid := ""
	for i in range(32):
		uuid += "%x" % (randi() % 16)
	_device_id = "%s-%s-%s-%s-%s" % [uuid.substr(0, 8), uuid.substr(8, 4), uuid.substr(12, 4), uuid.substr(16, 4), uuid.substr(20, 12)]
	return _device_id


# ── Anonymous Authentication (Device Auth) ──

func authenticate_anonymous() -> void:
	var device_id := _get_or_create_device_id()
	var url := "%s/v2/account/authenticate/device?create=true" % _base_url
	var body := JSON.stringify({"id": device_id})
	http_auth.request_completed.connect(_on_auth_completed, CONNECT_ONE_SHOT)
	http_auth.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, body)

func _on_auth_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("[BackendManager] Auth failed: result=%d, code=%d" % [result, response_code])
		_set_offline()
		auth_completed.emit(false)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_set_offline()
		auth_completed.emit(false)
		return

	var data: Dictionary = json.data
	_session_token = data.get("token", "")
	_refresh_token = data.get("refresh_token", "")

	if _session_token == "":
		_set_offline()
		auth_completed.emit(false)
		return

	_extract_user_id_from_token()
	if player_name == "":
		player_name = "Player_%s" % player_id.left(4).to_upper()
	_save_auth()
	_set_online()
	is_authenticated = true
	auth_completed.emit(true)

	# Push display name to Nakama, re-auth for fresh JWT, then write leaderboard
	_update_account_name()
	_flush_offline_queue()


func _check_session() -> void:
	# Lightweight account fetch to verify the session is still valid
	var url := "%s/v2/account" % _base_url
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		req.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
			# Session valid — extract player info
			var json := JSON.new()
			if json.parse(body_bytes.get_string_from_utf8()) == OK:
				var account: Dictionary = json.data
				var user: Dictionary = account.get("user", {})
				if user.has("id"):
					player_id = user.id
				if user.get("display_name", "") != "":
					player_name = user.display_name
			_save_auth()
			_set_online()
			is_authenticated = true
			auth_completed.emit(true)
			_update_account_name()
			_flush_offline_queue()
		else:
			# Session expired — try refresh or re-auth
			_refresh_session()
	, CONNECT_ONE_SHOT)
	req.request(url, _get_headers(), HTTPClient.METHOD_GET)


func _refresh_session() -> void:
	if _refresh_token == "":
		authenticate_anonymous()
		return

	var url := "%s/v2/account/session/refresh" % _base_url
	var body := JSON.stringify({"token": _session_token, "vars": {}})
	var headers := PackedStringArray([
		"Authorization: Basic %s" % _get_basic_auth(),
		"Content-Type: application/json",
	])
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, body_bytes: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			print("[BackendManager] Session refresh failed, re-authenticating")
			authenticate_anonymous()
			return
		var json := JSON.new()
		if json.parse(body_bytes.get_string_from_utf8()) != OK:
			authenticate_anonymous()
			return
		var data: Dictionary = json.data
		_session_token = data.get("token", _session_token)
		_refresh_token = data.get("refresh_token", _refresh_token)
		_extract_user_id_from_token()
		_save_auth()
		_set_online()
		is_authenticated = true
		auth_completed.emit(true)
		_update_account_name()
		_flush_offline_queue()
	, CONNECT_ONE_SHOT)
	req.request(url, headers, HTTPClient.METHOD_POST, body)


func _extract_user_id_from_token() -> void:
	# JWT is header.payload.signature — decode the payload for uid
	if _session_token == "":
		return
	var parts := _session_token.split(".")
	if parts.size() < 2:
		return
	# Base64url decode the payload
	var payload_b64 := parts[1]
	# Pad to multiple of 4
	while payload_b64.length() % 4 != 0:
		payload_b64 += "="
	# Replace URL-safe chars
	payload_b64 = payload_b64.replace("-", "+").replace("_", "/")
	var decoded := Marshalls.base64_to_utf8(payload_b64)
	var json := JSON.new()
	if json.parse(decoded) == OK:
		var claims: Dictionary = json.data
		if claims.has("uid"):
			player_id = claims.uid


func _submit_initial_rating() -> void:
	# Write current rating to the leaderboard so the player is discoverable
	_call_rpc("record_result", {
		"new_rating": player_rating,
		"won": true,  # Doesn't matter for initial — just sets the score
	}, func(_r, c, _h, _b):
		if c < 200 or c >= 300:
			print("[BackendManager] Initial rating submit failed: code=%d" % c)
	)


func _update_account_name() -> void:
	# Push profile name to Nakama so leaderboards show it
	var profile_name := ProfileManager.get_active_profile_name()
	player_name = profile_name
	_save_auth()
	var url := "%s/v2/account" % _base_url
	var body := JSON.stringify({"username": profile_name})
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray):
		req.queue_free()
		if response_code >= 200 and response_code < 300:
			# Name set — re-authenticate to get a fresh JWT with the new username
			_re_auth_and_submit()
		else:
			# Username taken — retry with player ID suffix
			var fallback_name := profile_name + "_" + player_id.left(4)
			var req2 := HTTPRequest.new()
			add_child(req2)
			req2.request_completed.connect(func(_r2: int, rc2: int, _h2: PackedStringArray, _b2: PackedByteArray):
				req2.queue_free()
				_re_auth_and_submit()
			, CONNECT_ONE_SHOT)
			req2.request(url, _get_headers(), HTTPClient.METHOD_PUT, JSON.stringify({"username": fallback_name}))
	, CONNECT_ONE_SHOT)
	req.request(url, _get_headers(), HTTPClient.METHOD_PUT, body)


func _re_auth_and_submit() -> void:
	# Re-authenticate to get a fresh JWT with the updated username, then write to leaderboard
	var device_id := _get_or_create_device_id()
	var url := "%s/v2/account/authenticate/device?create=true" % _base_url
	var body := JSON.stringify({"id": device_id})
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, resp_body: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			return
		var json := JSON.new()
		if json.parse(resp_body.get_string_from_utf8()) != OK:
			return
		var data: Dictionary = json.data
		_session_token = data.get("token", _session_token)
		_refresh_token = data.get("refresh_token", _refresh_token)
		_save_auth()
		# Now submit rating with the fresh token (correct username in JWT)
		_submit_initial_rating()
	, CONNECT_ONE_SHOT)
	req.request(url, _get_auth_headers(), HTTPClient.METHOD_POST, body)


# ── Squad Snapshot Upload ──

func upload_squad_snapshot(squad_json: Array, round_num: int) -> void:
	if not is_online or not is_authenticated:
		_queue_offline({
			"type": "upload_squad",
			"squad_json": squad_json,
			"round_num": round_num,
			"rating": player_rating,
		})
		squad_uploaded.emit(false)
		return

	var total_dps := SquadSerializer.calculate_squad_dps(squad_json)
	# Nakama storage write: PUT /v2/storage
	var url := "%s/v2/storage" % _base_url
	var body := JSON.stringify({
		"objects": [{
			"collection": "squad_snapshots",
			"key": "current",
			"value": JSON.stringify({
				"player_name": player_name,
				"round_number": round_num,
				"rating_at_time": player_rating,
				"squad_json": squad_json,
				"squad_size": squad_json.size(),
				"total_dps": total_dps,
			}),
			"permission_read": 2,  # Public read
			"permission_write": 1,  # Owner write
		}],
	})
	http_upload.request_completed.connect(_on_upload_completed, CONNECT_ONE_SHOT)
	http_upload.request(url, _get_headers(), HTTPClient.METHOD_PUT, body)

func _on_upload_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("[BackendManager] Squad upload failed: result=%d, code=%d" % [result, response_code])
		_set_offline()
		squad_uploaded.emit(false)
		return
	squad_uploaded.emit(true)


# ── Fetch Opponents ──

func fetch_opponents(rating: int, _round_num: int) -> void:
	if not is_online or not is_authenticated:
		var cached: Array = opponent_cache.get_opponents_for_rating(rating, 9)
		if not cached.is_empty():
			opponents_fetched.emit(cached)
		else:
			opponents_fetched.emit([])
		return

	_call_rpc_on("find_opponents", {
		"rating": rating,
		"range": 200,
	}, http_fetch, _on_fetch_completed)

func _on_fetch_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("[BackendManager] Fetch opponents failed: result=%d, code=%d" % [result, response_code])
		_set_offline()
		var cached: Array = opponent_cache.get_opponents_for_rating(player_rating, 9)
		opponents_fetched.emit(cached)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		opponents_fetched.emit([])
		return

	# Nakama RPC wraps the response in {"payload": "..."}
	var wrapper = json.data
	var data = _unwrap_rpc_response(wrapper)
	if not data is Array:
		opponents_fetched.emit([])
		return

	if not data.is_empty():
		opponent_cache.add_opponents(data)

	opponents_fetched.emit(data)


# ── Rating Update ──

func update_rating(new_rating: int) -> void:
	player_rating = new_rating
	_save_auth()

	# Buffer the rating — it will be sent with the next update_win_loss call
	_pending_result["new_rating"] = new_rating

	if not is_online or not is_authenticated:
		# Queue will be flushed by _flush_record_result via update_win_loss
		return


func update_win_loss(won: bool) -> void:
	_pending_result["won"] = won

	if not is_online or not is_authenticated:
		# Queue the merged result
		_queue_offline({
			"type": "record_result",
			"new_rating": _pending_result.get("new_rating", player_rating),
			"won": won,
		})
		_pending_result.clear()
		return

	_flush_record_result()


func _flush_record_result() -> void:
	if _pending_result.is_empty():
		return
	var payload := {
		"new_rating": _pending_result.get("new_rating", player_rating),
		"won": _pending_result.get("won", false),
	}
	_pending_result.clear()
	print("[BackendManager] Submitting result: rating=%d won=%s online=%s" % [payload.new_rating, str(payload.won), str(is_online)])

	_call_rpc("record_result", payload, func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			print("[BackendManager] record_result RPC failed: result=%d, code=%d" % [result, response_code])
			_set_offline()
			return
		print("[BackendManager] Rating submitted successfully: %d" % player_rating)
		rating_updated.emit(player_rating)
	)


# ── RPC Helpers ──

func _call_rpc(rpc_id: String, payload: Dictionary, callback: Callable) -> void:
	var url := "%s/v2/rpc/%s" % [_base_url, rpc_id]
	# Nakama gRPC-gateway maps HTTP body directly to Rpc.payload (a string field),
	# so the body must be a JSON-encoded string (double-encoded JSON).
	var body := JSON.stringify(JSON.stringify(payload))
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, resp_body: PackedByteArray):
		req.queue_free()
		if response_code < 200 or response_code >= 300:
			print("[BackendManager] RPC %s failed: code=%d body=%s" % [rpc_id, response_code, resp_body.get_string_from_utf8().left(200)])
		callback.call(result, response_code, headers, resp_body)
	, CONNECT_ONE_SHOT)
	req.request(url, _get_headers(), HTTPClient.METHOD_POST, body)


func _call_rpc_on(rpc_id: String, payload: Dictionary, http_node: HTTPRequest, callback: Callable) -> void:
	var url := "%s/v2/rpc/%s" % [_base_url, rpc_id]
	var body := JSON.stringify(JSON.stringify(payload))
	http_node.request_completed.connect(callback, CONNECT_ONE_SHOT)
	http_node.request(url, _get_headers(), HTTPClient.METHOD_POST, body)


func _unwrap_rpc_response(wrapper) -> Variant:
	# Nakama wraps RPC responses as {"payload": "<json string>"}
	if wrapper is Dictionary and wrapper.has("payload"):
		var inner_str: String = wrapper.payload
		var json := JSON.new()
		if json.parse(inner_str) == OK:
			return json.data
	# If it's already unwrapped (direct array/dict), return as-is
	return wrapper


func _clean_display_name(raw_name: String) -> String:
	# Strip "_xxxx" device ID suffixes from usernames (e.g. "Ironjaw_c14a" -> "Ironjaw")
	var parts := raw_name.rsplit("_", true, 1)
	if parts.size() == 2 and parts[1].length() == 4:
		return parts[0].left(20)
	return raw_name.left(20)


# ── Leaderboard ──

func fetch_leaderboard() -> void:
	if not is_online or not is_authenticated:
		leaderboard_fetched.emit(ProfileManager.get_all_profile_stats())
		return
	var url := "%s/v2/leaderboard/elo_ratings?limit=20" % _base_url
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			leaderboard_fetched.emit([])
			return
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			leaderboard_fetched.emit([])
			return
		var data: Dictionary = json.data if json.data is Dictionary else {}
		var records: Array = data.get("records", [])
		var entries: Array = []
		for i in records.size():
			var record: Dictionary = records[i]
			entries.append({
				"rank": i + 1,
				"player_name": _clean_display_name(record.get("username", record.get("owner_id", "Unknown"))),
				"score": int(record.get("score", 0)),
				"is_self": record.get("owner_id", "") == player_id,
			})
		leaderboard_fetched.emit(entries)
	, CONNECT_ONE_SHOT)
	req.request(url, _get_headers(), HTTPClient.METHOD_GET)


# ── Online/Offline State ──

func _set_online() -> void:
	if not is_online:
		is_online = true
		connection_changed.emit(true)

func _set_offline() -> void:
	if is_online:
		is_online = false
		connection_changed.emit(false)

func _on_connectivity_check() -> void:
	if is_authenticated and not is_online:
		var url := "%s/healthcheck" % _base_url
		var req := HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray):
			req.queue_free()
			if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
				_set_online()
				_flush_offline_queue()
		, CONNECT_ONE_SHOT)
		req.request(url, PackedStringArray(), HTTPClient.METHOD_GET)


# ── Offline Queue ──

func _queue_offline(request: Dictionary) -> void:
	offline_queue.append(request)
	_save_offline_queue()

func _save_offline_queue() -> void:
	var file := FileAccess.open(offline_queue_path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(offline_queue))
	file.close()

func _load_offline_queue() -> void:
	offline_queue.clear()
	if not FileAccess.file_exists(offline_queue_path):
		return
	var file := FileAccess.open(offline_queue_path, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	if json.data is Array:
		offline_queue = json.data

func _flush_offline_queue() -> void:
	if offline_queue.is_empty():
		return
	var queue_copy := offline_queue.duplicate()
	offline_queue.clear()
	_save_offline_queue()

	for request in queue_copy:
		match request.get("type", ""):
			"upload_squad":
				upload_squad_snapshot(
					request.get("squad_json", []),
					request.get("round_num", 1)
				)
			"record_result":
				_pending_result = {
					"new_rating": request.get("new_rating", player_rating),
					"won": request.get("won", false),
				}
				_flush_record_result()
			# Legacy queue types (from old Supabase backend)
			"update_rating":
				update_rating(request.get("rating", player_rating))
			"update_win_loss":
				update_win_loss(request.get("won", false))
