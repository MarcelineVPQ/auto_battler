class_name HeroVariants

const NAME_POOLS: Dictionary = {
	"Warlock": ["Garalt", "Mordith", "Vexara", "Thane", "Noctis", "Zareth"],
	"Priest": ["Helena", "Amara", "Solene", "Briseia", "Theron", "Luciel"],
	"Tank": ["Dorian", "Bulvar", "Ironhide", "Magnus", "Hector", "Brant"],
	"Herbalist": ["Sage", "Willow", "Briar", "Fern", "Thistle", "Rowan"],
	"Grunt": ["Korg", "Grok", "Thud", "Borak", "Ruk", "Varn"],
	"Archer": ["Lyra", "Aelin", "Faelyn", "Sera", "Ithrin", "Veyra"],
	"Assassin": ["Shade", "Whisper", "Nyx", "Veil", "Dusk", "Sable"],
	"Summoner": ["Nyx", "Elara", "Omen", "Riven", "Azura", "Conjura"],
	"Paladin": ["Cedric", "Aldric", "Gavriel", "Lucan", "Seraphel", "Orin"],
}

const ABILITY_VARIANTS: Dictionary = {
	"Warlock": [
		{"key": "warlock_curse", "name": "Vulnerable Curse", "desc": "Enemies within 200px get +20 crit vulnerability"},
		{"key": "warlock_drain", "name": "Soul Drain", "desc": "Steal HP from nearest enemy (dmg x2.0 as heal + damage)"},
		{"key": "warlock_bolt", "name": "Shadow Bolt", "desc": "Heavy single-target nuke (dmg x4.0 to nearest)"},
	],
	"Priest": [
		{"key": "priest_heal", "name": "Holy Armor", "desc": "Heal all allies for dmg x4.0"},
		{"key": "priest_shield", "name": "Divine Shield", "desc": "Weakest ally gains +50% max HP as temporary armor"},
		{"key": "priest_purify", "name": "Purify", "desc": "Lowest-HP ally: heal for dmg x8.0, remove crit vulnerability"},
	],
	"Tank": [
		{"key": "tank_bash", "name": "Shield Bash", "desc": "Deal armor + damage to nearest enemy"},
		{"key": "tank_taunt", "name": "Taunt", "desc": "Enemies in 150px forced to target this unit, gain +15 armor"},
		{"key": "tank_fortify", "name": "Fortify", "desc": "Gain armor equal to 50% max HP, reduce move speed to 0 for 1 tick"},
	],
	"Herbalist": [
		{"key": "herbalist_poison", "name": "Magic Potions", "desc": "Poison all enemies for dmg x0.5"},
		{"key": "herbalist_regen", "name": "Rejuvenation", "desc": "Heal all allies for dmg x2.0"},
		{"key": "herbalist_burst", "name": "Noxious Burst", "desc": "Enemies within 150px take dmg x2.0"},
	],
	"Grunt": [
		{"key": "grunt_frenzy", "name": "Frenzy", "desc": "Attack speed x1.3 permanently"},
		{"key": "grunt_warcry", "name": "War Cry", "desc": "All allies gain +3 damage permanently"},
		{"key": "grunt_cleave", "name": "Cleave", "desc": "Hit all enemies within 100px for dmg x1.5"},
	],
	"Archer": [
		{"key": "archer_volley", "name": "Volley", "desc": "Hit all enemies for dmg x0.4"},
		{"key": "archer_pierce", "name": "Piercing Shot", "desc": "Single target dmg x3.0, ignores armor"},
		{"key": "archer_mark", "name": "Marked Target", "desc": "Nearest enemy takes +30% more damage from all sources"},
	],
	"Assassin": [
		{"key": "assassin_shadow", "name": "Shadowstrike", "desc": "+50% crit chance on next hit"},
		{"key": "assassin_poison", "name": "Poison Blade", "desc": "Next 3 attacks deal bonus dmg x0.8 each"},
		{"key": "assassin_vanish", "name": "Vanish", "desc": "+80% evasion for 3 seconds + guaranteed crit on next hit"},
	],
	"Summoner": [
		{"key": "summoner_archer", "name": "Summon Archer", "desc": "Spawn an archer minion"},
		{"key": "summoner_guardian", "name": "Summon Guardian", "desc": "Spawn a tank minion (high HP, low damage)"},
		{"key": "summoner_familiar", "name": "Arcane Familiar", "desc": "Spawn a mage minion that deals AoE damage"},
	],
	"Paladin": [
		{"key": "paladin_aegis", "name": "Holy Aegis", "desc": "Restore armor + damage buff to allies"},
		{"key": "paladin_smite", "name": "Smite", "desc": "Deal (dmg + armor) x2.0 to nearest enemy, heal self for 50%"},
		{"key": "paladin_consecrate", "name": "Consecrate", "desc": "Deal dmg x1.5 to enemies within 120px, heal allies in range"},
	],
}

static func random_name(unit_class: String) -> String:
	var pool: Array = NAME_POOLS.get(unit_class, [])
	if pool.is_empty():
		return unit_class
	return pool.pick_random()

static func random_ability(unit_class: String) -> Dictionary:
	var variants: Array = ABILITY_VARIANTS.get(unit_class, [])
	if variants.is_empty():
		return {"key": "", "name": "", "desc": ""}
	return variants.pick_random()
