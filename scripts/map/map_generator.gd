class_name MapGenerator extends RefCounted

# Node type weights per act: [BATTLE, ELITE, REST, SHOP, TREASURE, UNKNOWN]
const ACT_WEIGHTS := [
	[50, 10, 12, 10, 5, 13],  # Act 1
	[45, 15, 12, 10, 5, 13],  # Act 2
	[40, 20, 12, 10, 5, 13],  # Act 3
]

# Maps weight index to NodeType
const WEIGHT_TYPES: Array = [
	MapData.NodeType.BATTLE,
	MapData.NodeType.ELITE,
	MapData.NodeType.REST,
	MapData.NodeType.SHOP,
	MapData.NodeType.TREASURE,
	MapData.NodeType.UNKNOWN,
]

static func generate() -> Dictionary:
	var map := {"acts": [], "current_node_id": -1, "current_act": 1, "available_node_ids": [], "visited_node_ids": []}
	var global_id := 0

	for act_idx in range(3):
		var act_num := act_idx + 1
		var num_floors: int = MapData.ACT_FLOORS[act_idx]
		var act_data := {"act_number": act_num, "nodes": []}
		var floors_nodes: Array = []  # Array of arrays, one per floor

		# Create nodes for each floor
		for floor_idx in range(num_floors):
			var floor_nodes: Array = []
			if floor_idx == num_floors - 1:
				# Boss floor: single node
				var node := _create_node(global_id, act_num, floor_idx, 0, MapData.NodeType.BOSS)
				floor_nodes.append(node)
				global_id += 1
			else:
				var num_cols: int = randi_range(MapData.COLUMNS_MIN, MapData.COLUMNS_MAX)
				for col in range(num_cols):
					var node_type := _pick_node_type(act_idx, floor_idx, num_floors)
					var node := _create_node(global_id, act_num, floor_idx, col, node_type)
					floor_nodes.append(node)
					global_id += 1
			floors_nodes.append(floor_nodes)

		# Floor 0: always BATTLE
		for node in floors_nodes[0]:
			node["type"] = MapData.NodeType.BATTLE

		# No ELITE on floor 0 of act 1
		if act_idx == 0:
			for node in floors_nodes[0]:
				if node["type"] == MapData.NodeType.ELITE:
					node["type"] = MapData.NodeType.BATTLE

		# Connect floors
		for floor_idx in range(num_floors - 1):
			var current_floor: Array = floors_nodes[floor_idx]
			var next_floor: Array = floors_nodes[floor_idx + 1]
			_connect_floors(current_floor, next_floor)

		# Constraint: guarantee at least 1 REST per act (floors 1 to N-2)
		var has_rest := false
		for floor_idx in range(1, num_floors - 1):
			for node in floors_nodes[floor_idx]:
				if node["type"] == MapData.NodeType.REST:
					has_rest = true
					break
			if has_rest:
				break
		if not has_rest and num_floors > 2:
			# Place a REST on a random mid-floor node
			var mid_floor: int = randi_range(1, num_floors - 2)
			var rand_node: Dictionary = floors_nodes[mid_floor][randi_range(0, floors_nodes[mid_floor].size() - 1)]
			rand_node["type"] = MapData.NodeType.REST

		# Constraint: floor before boss (N-2) has at least 1 REST or SHOP
		if num_floors >= 3:
			var pre_boss_floor: Array = floors_nodes[num_floors - 2]
			var has_rest_or_shop := false
			for node in pre_boss_floor:
				if node["type"] == MapData.NodeType.REST or node["type"] == MapData.NodeType.SHOP:
					has_rest_or_shop = true
					break
			if not has_rest_or_shop:
				pre_boss_floor[randi_range(0, pre_boss_floor.size() - 1)]["type"] = MapData.NodeType.REST

		# Constraint: no consecutive REST on any single path
		_fix_consecutive_rest(floors_nodes)

		# Flatten nodes into act_data
		for floor_nodes in floors_nodes:
			for node in floor_nodes:
				act_data["nodes"].append(node)

		map["acts"].append(act_data)

	# Set initial available nodes (floor 0 of act 1)
	var first_act: Dictionary = map["acts"][0]
	for node in first_act["nodes"]:
		if node["floor"] == 0:
			map["available_node_ids"].append(node["id"])

	# Assign layout positions
	_assign_positions(map)

	return map


static func _create_node(id: int, act: int, floor_idx: int, column: int, type: MapData.NodeType) -> Dictionary:
	return {
		"id": id,
		"act": act,
		"floor": floor_idx,
		"column": column,
		"type": type,
		"connections": [],
		"visited": false,
		"position": {"x": 0.0, "y": 0.0},
	}


static func _pick_node_type(act_idx: int, floor_idx: int, num_floors: int) -> MapData.NodeType:
	var weights: Array = ACT_WEIGHTS[act_idx]
	var total := 0
	for w in weights:
		total += w
	var roll := randi_range(0, total - 1)
	var acc := 0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc:
			return WEIGHT_TYPES[i]
	return MapData.NodeType.BATTLE


static func _connect_floors(current_floor: Array, next_floor: Array) -> void:
	var cur_count: int = current_floor.size()
	var nxt_count: int = next_floor.size()

	# Track which next_floor nodes have incoming connections
	var incoming := {}
	for node in next_floor:
		incoming[node["id"]] = 0

	# Each current node connects to 1-2 next nodes, preferring same/adjacent column
	for node in current_floor:
		var col: int = node["column"]
		var candidates: Array = []

		# Prefer same column and adjacent columns
		for nxt_node in next_floor:
			var nxt_col: int = nxt_node["column"]
			var dist := absi(nxt_col - col)
			if dist <= 1:
				candidates.append(nxt_node)

		# Fallback: if no candidates within range, use closest
		if candidates.is_empty():
			candidates = next_floor.duplicate()

		# Connect to 1-2 candidates
		candidates.shuffle()
		var num_connections := mini(randi_range(1, 2), candidates.size())
		for i in range(num_connections):
			var target_id: int = candidates[i]["id"]
			if target_id not in node["connections"]:
				node["connections"].append(target_id)
				incoming[target_id] = incoming.get(target_id, 0) + 1

	# Ensure every next_floor node has at least 1 incoming connection
	for nxt_node in next_floor:
		if incoming.get(nxt_node["id"], 0) == 0:
			# Connect from the closest current node
			var best_node: Dictionary = current_floor[0]
			var best_dist := 999
			for cur_node in current_floor:
				var dist := absi(cur_node["column"] - nxt_node["column"])
				if dist < best_dist:
					best_dist = dist
					best_node = cur_node
			if nxt_node["id"] not in best_node["connections"]:
				best_node["connections"].append(nxt_node["id"])


static func _fix_consecutive_rest(floors_nodes: Array) -> void:
	for floor_idx in range(floors_nodes.size() - 1):
		for node in floors_nodes[floor_idx]:
			if node["type"] != MapData.NodeType.REST:
				continue
			# Check if any connected node on next floor is also REST
			for conn_id in node["connections"]:
				for nxt_node in floors_nodes[floor_idx + 1]:
					if nxt_node["id"] == conn_id and nxt_node["type"] == MapData.NodeType.REST:
						# Change the next one to BATTLE
						nxt_node["type"] = MapData.NodeType.BATTLE


static func _assign_positions(map: Dictionary) -> void:
	var y_offset := 0.0
	var floor_spacing := 120.0
	var col_spacing := 140.0
	var margin_x := 100.0
	var act_gap := 80.0

	for act_data in map["acts"]:
		var act_nodes: Array = act_data["nodes"]
		# Group nodes by floor
		var floor_groups := {}
		for node in act_nodes:
			var f: int = node["floor"]
			if f not in floor_groups:
				floor_groups[f] = []
			floor_groups[f].append(node)

		var num_floors: int = MapData.ACT_FLOORS[act_data["act_number"] - 1]
		# Draw from bottom to top (floor 0 at bottom)
		for floor_idx in range(num_floors):
			if floor_idx not in floor_groups:
				continue
			var nodes: Array = floor_groups[floor_idx]
			var total_width := (nodes.size() - 1) * col_spacing
			var start_x := margin_x + (3 * col_spacing - total_width) / 2.0
			for i in range(nodes.size()):
				nodes[i]["position"]["x"] = start_x + i * col_spacing
				nodes[i]["position"]["y"] = y_offset + (num_floors - 1 - floor_idx) * floor_spacing

		y_offset += num_floors * floor_spacing + act_gap


# ── Helpers for map state management ──

static func get_node_by_id(map: Dictionary, node_id: int) -> Dictionary:
	for act_data in map["acts"]:
		for node in act_data["nodes"]:
			if node["id"] == node_id:
				return node
	return {}


static func mark_node_visited(map: Dictionary, node_id: int) -> void:
	var node := get_node_by_id(map, node_id)
	if node.is_empty():
		return
	node["visited"] = true
	if node_id not in map["visited_node_ids"]:
		map["visited_node_ids"].append(node_id)


static func update_available_nodes(map: Dictionary, completed_node_id: int) -> void:
	var node := get_node_by_id(map, completed_node_id)
	if node.is_empty():
		return

	# Remove current from available
	map["available_node_ids"].erase(completed_node_id)

	var act_num: int = node["act"]
	var node_floor: int = node["floor"]

	# Remove all other available nodes on the same floor (player committed to this path)
	var act_data: Dictionary = map["acts"][act_num - 1]
	for n in act_data["nodes"]:
		if n["floor"] == node_floor and n["id"] != completed_node_id:
			map["available_node_ids"].erase(n["id"])

	# If this was the boss node, advance to next act
	if node["type"] == MapData.NodeType.BOSS:
		if act_num < 3:
			# Unlock floor 0 of next act
			var next_act: Dictionary = map["acts"][act_num]
			for n in next_act["nodes"]:
				if n["floor"] == 0:
					map["available_node_ids"].append(n["id"])
			map["current_act"] = act_num + 1
		return

	# Otherwise unlock connected nodes
	for conn_id in node["connections"]:
		if conn_id not in map["visited_node_ids"] and conn_id not in map["available_node_ids"]:
			map["available_node_ids"].append(conn_id)


static func sanitize_after_json(map: Dictionary) -> void:
	# JSON parse turns all ints into floats — convert them back
	map["current_node_id"] = int(map.get("current_node_id", -1))
	map["current_act"] = int(map.get("current_act", 1))

	var new_available: Array = []
	for id in map.get("available_node_ids", []):
		new_available.append(int(id))
	map["available_node_ids"] = new_available

	var new_visited: Array = []
	for id in map.get("visited_node_ids", []):
		new_visited.append(int(id))
	map["visited_node_ids"] = new_visited

	for act_data in map.get("acts", []):
		act_data["act_number"] = int(act_data.get("act_number", 1))
		for node in act_data.get("nodes", []):
			node["id"] = int(node.get("id", 0))
			node["act"] = int(node.get("act", 1))
			node["floor"] = int(node.get("floor", 0))
			node["column"] = int(node.get("column", 0))
			node["type"] = int(node.get("type", 0))
			var new_conns: Array = []
			for c in node.get("connections", []):
				new_conns.append(int(c))
			node["connections"] = new_conns


static func is_run_complete(map: Dictionary) -> bool:
	# Check if act 3 boss has been visited
	if map["acts"].size() < 3:
		return false
	var act3: Dictionary = map["acts"][2]
	for node in act3["nodes"]:
		if node["type"] == MapData.NodeType.BOSS and node["visited"]:
			return true
	return false
