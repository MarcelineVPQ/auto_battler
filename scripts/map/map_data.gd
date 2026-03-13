class_name MapData extends RefCounted

enum NodeType { BATTLE, ELITE, BOSS, REST, SHOP, TREASURE, UNKNOWN }

# Floors per act (boss is last floor of each act)
const ACT_FLOORS := [6, 7, 7]
const COLUMNS_MIN := 3
const COLUMNS_MAX := 4

const NODE_SYMBOLS := {
	NodeType.BATTLE: "⚔",
	NodeType.ELITE: "💀",
	NodeType.BOSS: "👑",
	NodeType.REST: "🔥",
	NodeType.SHOP: "💰",
	NodeType.TREASURE: "🎁",
	NodeType.UNKNOWN: "?",
}

const NODE_COLORS := {
	NodeType.BATTLE: Color(0.8, 0.3, 0.3),
	NodeType.ELITE: Color(1.0, 0.6, 0.2),
	NodeType.BOSS: Color(1.0, 0.2, 0.2),
	NodeType.REST: Color(0.3, 0.8, 0.4),
	NodeType.SHOP: Color(1.0, 0.85, 0.2),
	NodeType.TREASURE: Color(0.65, 0.45, 0.85),
	NodeType.UNKNOWN: Color(0.4, 0.7, 1.0),
}

const NODE_TYPE_NAMES := {
	NodeType.BATTLE: "Battle",
	NodeType.ELITE: "Elite",
	NodeType.BOSS: "Boss",
	NodeType.REST: "Rest",
	NodeType.SHOP: "Shop",
	NodeType.TREASURE: "Treasure",
	NodeType.UNKNOWN: "Unknown",
}

# Maps (act, floor) to effective round 1-20 for wave generation
static func get_effective_round(act: int, floor_in_act: int) -> int:
	match act:
		1: return clampi(floor_in_act + 1, 1, 6)
		2: return clampi(floor_in_act + 7, 7, 13)
		3: return clampi(floor_in_act + 14, 14, 20)
	return 1

# Budget multiplier for elite/boss waves
static func get_budget_multiplier(node_type: NodeType) -> float:
	match node_type:
		NodeType.ELITE: return 1.5
		NodeType.BOSS: return 2.0
		_: return 1.0

static func get_level_bonus(node_type: NodeType) -> int:
	match node_type:
		NodeType.ELITE: return 1
		NodeType.BOSS: return 2
		_: return 0
