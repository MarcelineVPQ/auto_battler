class_name UnitData
extends Resource

@export var unit_name: String = ""
@export var unit_class: String = ""
@export var farm_cost: int = 1

# Combat stats
@export var max_hp: int = 60
@export var damage: int = 4
@export var attacks_per_second: float = 0.5
@export var attack_range: float = 100.0   # pixels (circular radius)
@export var move_speed: float = 60.0      # pixels per combat tick
@export var armor: int = 0
@export var evasion: float = 0.0          # percentage 0-100
@export var crit_chance: float = 3.0      # percentage 0-100
@export var skill_proc_chance: float = 5.0 # percentage 0-100

# Mana / Ability
@export var max_mana: int = 5
@export var mana_cost_per_attack: int = 5
@export var mana_regen_per_second: float = 2.5
@export var ability_name: String = ""
@export var ability_cooldown: float = 5.0

# Skill (passive — not all heroes have one)
@export var skill_name: String = ""

# Boosted stats (display only for now)
@export var boosted_stats: PackedStringArray = []

@export var texture: Texture2D
