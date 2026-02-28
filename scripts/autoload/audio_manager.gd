extends Node

# Pool of AudioStreamPlayers for overlapping sounds
const POOL_SIZE: int = 8
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

# Preloaded sound effects — keys match the names used in play() calls
# Replace these placeholder paths with your actual .mp3 / .ogg files
var _sounds: Dictionary = {}

# Sound file mapping — edit paths here once you drop in audio files
const SOUND_PATHS: Dictionary = {
	# Combat
	"hit": "res://assets/audio/hit.mp3",
	"crit": "res://assets/audio/crit.mp3",
	"miss": "res://assets/audio/miss.mp3",
	"ability": "res://assets/audio/ability.mp3",
	"heal": "res://assets/audio/heal.mp3",
	"poison": "res://assets/audio/poison.mp3",
	"curse": "res://assets/audio/curse.mp3",
	"summon": "res://assets/audio/summon.mp3",
	"death": "res://assets/audio/death.mp3",
	# Shop / UI
	"buy": "res://assets/audio/buy.mp3",
	"sell": "res://assets/audio/sell.mp3",
	"reroll": "res://assets/audio/reroll.mp3",
	"upgrade": "res://assets/audio/upgrade.mp3",
	"warning": "res://assets/audio/warning.mp3",
	# Game flow
	"round_start": "res://assets/audio/round_start.mp3",
	"victory": "res://assets/audio/victory.mp3",
	"defeat": "res://assets/audio/defeat.mp3",
	"game_over": "res://assets/audio/game_over.mp3",
}

func _ready() -> void:
	# Build player pool
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

	# Preload all sounds that exist on disk
	for key in SOUND_PATHS:
		var path: String = SOUND_PATHS[key]
		if ResourceLoader.exists(path):
			_sounds[key] = load(path)

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		return
	var player := _players[_next_player]
	player.stream = _sounds[sound_name]
	player.volume_db = volume_db
	player.play()
	_next_player = (_next_player + 1) % POOL_SIZE
