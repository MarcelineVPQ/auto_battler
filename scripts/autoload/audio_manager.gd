extends Node

# Pool of AudioStreamPlayers for overlapping sounds
const POOL_SIZE: int = 8
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

# Preloaded sound effects — keys match the names used in play() calls
# Replace these placeholder paths with your actual .wav / .ogg files
var _sounds: Dictionary = {}

# Sound file mapping — edit paths here once you drop in audio files
const SOUND_PATHS: Dictionary = {
	# Combat
	"hit": "res://assets/audio/hit.wav",
	"crit": "res://assets/audio/crit.wav",
	"miss": "res://assets/audio/miss.wav",
	"ability": "res://assets/audio/ability.wav",
	"heal": "res://assets/audio/heal.wav",
	"poison": "res://assets/audio/poison.wav",
	"curse": "res://assets/audio/curse.wav",
	"summon": "res://assets/audio/summon.wav",
	"death": "res://assets/audio/death.wav",
	# Shop / UI
	"buy": "res://assets/audio/buy.wav",
	"sell": "res://assets/audio/sell.wav",
	"reroll": "res://assets/audio/reroll.wav",
	"upgrade": "res://assets/audio/upgrade.wav",
	"warning": "res://assets/audio/warning.wav",
	# Game flow
	"round_start": "res://assets/audio/round_start.wav",
	"victory": "res://assets/audio/victory.wav",
	"defeat": "res://assets/audio/defeat.wav",
	"game_over": "res://assets/audio/game_over.wav",
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
