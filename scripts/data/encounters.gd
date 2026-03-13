class_name Encounters

const ELITES: Array = [
	# E1: "The Iron Phalanx" — Armor stacking wall
	{
		"id": "iron_phalanx",
		"name": "The Iron Phalanx",
		"acts": [1, 2],
		"units": [
			{"class": "Tank", "ability_key": "tank_fortify", "level_offset": 0, "hero_name": "Ironhide", "modifiers": {"thorns_slow": true}},
			{"class": "Tank", "ability_key": "tank_taunt", "level_offset": 0, "hero_name": "Steelward", "modifiers": {}},
			{"class": "Paladin", "ability_key": "paladin_aegis", "level_offset": 0, "hero_name": "Cedric", "modifiers": {"primed": true}},
		],
	},
	# E2: "Venomfang Pack" — Poison attrition
	{
		"id": "venomfang_pack",
		"name": "Venomfang Pack",
		"acts": [1, 2],
		"units": [
			{"class": "Herbalist", "ability_key": "herbalist_poison", "level_offset": 0, "hero_name": "Hemlock", "modifiers": {"poison_power": 3}},
			{"class": "Herbalist", "ability_key": "herbalist_burst", "level_offset": 0, "hero_name": "Nettle", "modifiers": {"poison_power": 3}},
			{"class": "Assassin", "ability_key": "assassin_poison", "level_offset": 0, "hero_name": "Fang", "modifiers": {"poison_power": 5, "primed": true}},
		],
	},
	# E3: "Bloodsworn Brothers" — Lifesteal berserkers
	{
		"id": "bloodsworn_brothers",
		"name": "Bloodsworn Brothers",
		"acts": [1, 2],
		"units": [
			{"class": "Grunt", "ability_key": "grunt_frenzy", "level_offset": 0, "hero_name": "Korg", "modifiers": {"lifesteal_pct": 0.2, "relentless": true}},
			{"class": "Grunt", "ability_key": "grunt_warcry", "level_offset": 0, "hero_name": "Borak", "modifiers": {"lifesteal_pct": 0.2, "relentless": true}},
			{"class": "Grunt", "ability_key": "grunt_cleave", "level_offset": 0, "hero_name": "Thud", "modifiers": {"lifesteal_pct": 0.2, "relentless": true}},
		],
	},
	# E4: "The Shadow Court" — Evasion + burst
	{
		"id": "shadow_court",
		"name": "The Shadow Court",
		"acts": [1, 2],
		"units": [
			{"class": "Assassin", "ability_key": "assassin_shadow", "level_offset": 0, "hero_name": "Shade", "modifiers": {"invincible_max": 2}},
			{"class": "Assassin", "ability_key": "assassin_vanish", "level_offset": 0, "hero_name": "Whisper", "modifiers": {"invincible_max": 2}},
			{"class": "Archer", "ability_key": "archer_mark", "level_offset": 0, "hero_name": "Lyra", "modifiers": {"primed": true}},
		],
	},
	# E5: "The Blight Legion" — Corrosive + poison DOT
	{
		"id": "blight_legion",
		"name": "The Blight Legion",
		"acts": [1, 2, 3],
		"units": [
			{"class": "Herbalist", "ability_key": "herbalist_poison", "level_offset": 0, "hero_name": "Briar", "modifiers": {"corrosive_power": 3, "sepsis_spread": 2}},
			{"class": "Archer", "ability_key": "archer_volley", "level_offset": 0, "hero_name": "Aelin", "modifiers": {"corrosive_power": 2}},
			{"class": "Warlock", "ability_key": "warlock_soulfire", "level_offset": 0, "hero_name": "Vexara", "modifiers": {"poison_power": 4, "hellfire": true}},
		],
	},
	# E6: "Crimson Bulwark" — Unkillable tank + DPS
	{
		"id": "crimson_bulwark",
		"name": "Crimson Bulwark",
		"acts": [1, 2, 3],
		"units": [
			{"class": "Tank", "ability_key": "tank_fortify", "level_offset": 0, "hero_name": "Bulvar", "modifiers": {"living_shield_max": 80, "last_stand": true}},
			{"class": "Priest", "ability_key": "priest_heal", "level_offset": 0, "hero_name": "Solene", "modifiers": {"primed": true}},
			{"class": "Warlock", "ability_key": "warlock_bolt", "level_offset": 0, "hero_name": "Mordith", "modifiers": {"haymaker_counter": 4}},
		],
	},
	# E7: "The Whispering Dead" — Summon spam
	{
		"id": "whispering_dead",
		"name": "The Whispering Dead",
		"acts": [1, 2, 3],
		"units": [
			{"class": "Summoner", "ability_key": "summoner_familiar", "level_offset": 0, "hero_name": "Nyx", "modifiers": {"necromancy_stacks": 3, "legion_master": true, "primed": true}},
			{"class": "Summoner", "ability_key": "summoner_archer", "level_offset": 0, "hero_name": "Omen", "modifiers": {"necromancy_stacks": 3, "legion_master": true, "primed": true}},
			{"class": "Priest", "ability_key": "priest_shield", "level_offset": 0, "hero_name": "Amara", "modifiers": {"living_shield_max": 40}},
		],
	},
	# E8: "Stormwall Vanguard" — Counter-attack wall
	{
		"id": "stormwall_vanguard",
		"name": "Stormwall Vanguard",
		"acts": [1, 2, 3],
		"units": [
			{"class": "Paladin", "ability_key": "paladin_smite", "level_offset": 0, "hero_name": "Aldric", "modifiers": {"thorns_slow": true, "lifesteal_pct": 0.1}},
			{"class": "Paladin", "ability_key": "paladin_consecrate", "level_offset": 0, "hero_name": "Gavriel", "modifiers": {"thorns_slow": true, "lifesteal_pct": 0.1}},
			{"class": "Tank", "ability_key": "tank_bash", "level_offset": 0, "hero_name": "Magnus", "modifiers": {"haymaker_counter": 4, "invincible_max": 3}},
		],
	},
	# E9: "The Deathless Circle" — Layered defenses
	{
		"id": "deathless_circle",
		"name": "The Deathless Circle",
		"acts": [2, 3],
		"units": [
			{"class": "Tank", "ability_key": "tank_fortify", "level_offset": 0, "hero_name": "Gorath", "modifiers": {"living_shield_max": 100, "invincible_max": 3}},
			{"class": "Priest", "ability_key": "priest_heal", "level_offset": 0, "hero_name": "Helena", "modifiers": {"primed": true}},
			{"class": "Paladin", "ability_key": "paladin_aegis", "level_offset": 0, "hero_name": "Lucan", "modifiers": {"last_stand": true}},
			{"class": "Herbalist", "ability_key": "herbalist_regen", "level_offset": 0, "hero_name": "Willow", "modifiers": {"primed": true}},
		],
	},
	# E10: "Hellfire Cabal" — AoE burst
	{
		"id": "hellfire_cabal",
		"name": "Hellfire Cabal",
		"acts": [2, 3],
		"units": [
			{"class": "Warlock", "ability_key": "warlock_soulfire", "level_offset": 0, "hero_name": "Zareth", "modifiers": {"hellfire": true, "primed": true}},
			{"class": "Warlock", "ability_key": "warlock_drain", "level_offset": 0, "hero_name": "Dravyn", "modifiers": {"hellfire": true, "primed": true}},
			{"class": "Warlock", "ability_key": "warlock_bolt", "level_offset": 0, "hero_name": "Sythera", "modifiers": {"hellfire": true, "primed": true}},
			{"class": "Herbalist", "ability_key": "herbalist_burst", "level_offset": 0, "hero_name": "Oleander", "modifiers": {"corrosive_power": 4, "primed": true}},
		],
	},
	# E11: "Phantom Blades" — Assassin swarm
	{
		"id": "phantom_blades",
		"name": "Phantom Blades",
		"acts": [2, 3],
		"units": [
			{"class": "Assassin", "ability_key": "assassin_shadow", "level_offset": 0, "hero_name": "Nyx", "modifiers": {"invincible_max": 2, "relentless": true, "poison_power": 3, "primed": true}},
			{"class": "Assassin", "ability_key": "assassin_poison", "level_offset": 0, "hero_name": "Veil", "modifiers": {"invincible_max": 2, "relentless": true, "poison_power": 3}},
			{"class": "Assassin", "ability_key": "assassin_vanish", "level_offset": 0, "hero_name": "Dusk", "modifiers": {"invincible_max": 2, "relentless": true, "poison_power": 3}},
		],
	},
	# E12: "The Immortal Guard" — Unkillable tank + piercing archers
	{
		"id": "immortal_guard",
		"name": "The Immortal Guard",
		"acts": [2, 3],
		"units": [
			{"class": "Tank", "ability_key": "tank_fortify", "level_offset": 0, "hero_name": "Bastion", "modifiers": {"invincible_max": 5, "living_shield_max": 120, "thorns_slow": true}},
			{"class": "Archer", "ability_key": "archer_pierce", "level_offset": 0, "hero_name": "Faelyn", "modifiers": {"haymaker_counter": 4, "armor_pen": 0.5}},
			{"class": "Archer", "ability_key": "archer_volley", "level_offset": 0, "hero_name": "Sera", "modifiers": {"haymaker_counter": 4, "armor_pen": 0.5}},
			{"class": "Priest", "ability_key": "priest_heal", "level_offset": 0, "hero_name": "Luciel", "modifiers": {"lifesteal_pct": 0.15}},
		],
	},
]

const BOSSES: Array = [
	# B1: "Warlord Grimjaw" — Relentless melee warlord
	{
		"id": "warlord_grimjaw",
		"name": "Warlord Grimjaw",
		"act": 1,
		"units": [
			{"class": "Grunt", "ability_key": "grunt_cleave", "level_offset": 3, "hero_name": "Grimjaw", "is_boss_unit": true, "stat_mult": 2.5, "modifiers": {"relentless": true, "last_stand": true, "lifesteal_pct": 0.15, "haymaker_counter": 4}},
			{"class": "Grunt", "ability_key": "grunt_warcry", "level_offset": 0, "hero_name": "Borak", "modifiers": {"primed": true}},
			{"class": "Grunt", "ability_key": "grunt_frenzy", "level_offset": 0, "hero_name": "Thud", "modifiers": {"primed": true}},
		],
	},
	# B2: "High Priestess Solene" — Undying healer fortress
	{
		"id": "high_priestess_solene",
		"name": "High Priestess Solene",
		"act": 1,
		"units": [
			{"class": "Priest", "ability_key": "priest_heal", "level_offset": 3, "hero_name": "Solene", "is_boss_unit": true, "stat_mult": 2.5, "modifiers": {"primed": true, "living_shield_max": 100, "invincible_max": 3}},
			{"class": "Tank", "ability_key": "tank_taunt", "level_offset": 0, "hero_name": "Dorian", "modifiers": {"thorns_slow": true, "last_stand": true}},
			{"class": "Paladin", "ability_key": "paladin_aegis", "level_offset": 0, "hero_name": "Orin", "modifiers": {"lifesteal_pct": 0.1}},
			{"class": "Herbalist", "ability_key": "herbalist_poison", "level_offset": 0, "hero_name": "Sage", "modifiers": {"poison_power": 2}},
		],
	},
	# B3: "Archlich Nethys" — Summoner flooding the board
	{
		"id": "archlich_nethys",
		"name": "Archlich Nethys",
		"act": 2,
		"units": [
			{"class": "Summoner", "ability_key": "summoner_familiar", "level_offset": 3, "hero_name": "Nethys", "is_boss_unit": true, "stat_mult": 2.0, "modifiers": {"necromancy_stacks": 5, "legion_master": true, "primed": true, "invincible_max": 4, "living_shield_max": 60}},
			{"class": "Warlock", "ability_key": "warlock_soulfire", "level_offset": 0, "hero_name": "Garalt", "modifiers": {"hellfire": true, "corrosive_power": 3}},
			{"class": "Priest", "ability_key": "priest_heal", "level_offset": 0, "hero_name": "Briseia", "modifiers": {"primed": true}},
		],
	},
	# B4: "Voidcaller Mordith" — AoE burst mage
	{
		"id": "voidcaller_mordith",
		"name": "Voidcaller Mordith",
		"act": 2,
		"units": [
			{"class": "Warlock", "ability_key": "warlock_soulfire", "level_offset": 3, "hero_name": "Mordith", "is_boss_unit": true, "stat_mult": 2.5, "modifiers": {"hellfire": true, "primed": true, "corrosive_power": 5, "poison_power": 3, "lifesteal_pct": 0.2}},
			{"class": "Warlock", "ability_key": "warlock_drain", "level_offset": 0, "hero_name": "Dravyn", "modifiers": {"hellfire": true, "primed": true}},
			{"class": "Herbalist", "ability_key": "herbalist_burst", "level_offset": 0, "hero_name": "Hemlock", "modifiers": {"corrosive_power": 3, "primed": true}},
			{"class": "Tank", "ability_key": "tank_fortify", "level_offset": 0, "hero_name": "Thormund", "modifiers": {"thorns_slow": true, "living_shield_max": 80}},
		],
	},
	# B5: "The Eternal Champion" — Unkillable paladin
	{
		"id": "eternal_champion",
		"name": "The Eternal Champion",
		"act": 3,
		"units": [
			{"class": "Paladin", "ability_key": "paladin_smite", "level_offset": 4, "hero_name": "The Eternal Champion", "is_boss_unit": true, "stat_mult": 3.0, "modifiers": {"last_stand": true, "relentless": true, "lifesteal_pct": 0.25, "invincible_max": 5, "haymaker_counter": 4, "thorns_slow": true}},
			{"class": "Priest", "ability_key": "priest_heal", "level_offset": 0, "hero_name": "Celeste", "modifiers": {"primed": true}},
			{"class": "Priest", "ability_key": "priest_purify", "level_offset": 0, "hero_name": "Dianthe", "modifiers": {"primed": true}},
			{"class": "Tank", "ability_key": "tank_fortify", "level_offset": 0, "hero_name": "Rampart", "modifiers": {"living_shield_max": 100, "last_stand": true}},
			{"class": "Archer", "ability_key": "archer_pierce", "level_offset": 0, "hero_name": "Kaelen", "modifiers": {"armor_pen": 0.5, "haymaker_counter": 4, "primed": true}},
		],
	},
	# B6: "The Swarm Mother" — Endless summons + poison
	{
		"id": "swarm_mother",
		"name": "The Swarm Mother",
		"act": 3,
		"units": [
			{"class": "Summoner", "ability_key": "summoner_guardian", "level_offset": 4, "hero_name": "The Swarm Mother", "is_boss_unit": true, "stat_mult": 2.5, "modifiers": {"necromancy_stacks": 8, "legion_master": true, "primed": true, "invincible_max": 6, "living_shield_max": 100}},
			{"class": "Herbalist", "ability_key": "herbalist_poison", "level_offset": 0, "hero_name": "Tansy", "modifiers": {"poison_power": 5, "corrosive_power": 3, "primed": true}},
			{"class": "Herbalist", "ability_key": "herbalist_burst", "level_offset": 0, "hero_name": "Yarrow", "modifiers": {"poison_power": 5, "corrosive_power": 3, "primed": true}},
			{"class": "Warlock", "ability_key": "warlock_soulfire", "level_offset": 0, "hero_name": "Volgrim", "modifiers": {"hellfire": true, "lifesteal_pct": 0.15}},
			{"class": "Assassin", "ability_key": "assassin_shadow", "level_offset": 0, "hero_name": "Eclipse", "modifiers": {"relentless": true, "invincible_max": 3, "poison_power": 4}},
		],
	},
]

static func pick_elite(act: int, seen_ids: Array) -> Dictionary:
	var pool := []
	for e in ELITES:
		if act in e.acts and e.id not in seen_ids:
			pool.append(e)
	if pool.is_empty():
		for e in ELITES:
			if act in e.acts:
				pool.append(e)
	if pool.is_empty():
		return {}
	return pool.pick_random()

static func pick_boss(act: int, seen_ids: Array) -> Dictionary:
	var pool := []
	for b in BOSSES:
		if b.act == act and b.id not in seen_ids:
			pool.append(b)
	if pool.is_empty():
		for b in BOSSES:
			if b.act == act:
				pool.append(b)
	if pool.is_empty():
		return {}
	return pool.pick_random()
