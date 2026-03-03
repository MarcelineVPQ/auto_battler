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
	# Class-specific ability sounds
	"ability_melee": "res://assets/audio/ability_melee.mp3",
	"ability_stealth": "res://assets/audio/ability_stealth.mp3",
	"ability_ranged": "res://assets/audio/ability_ranged.mp3",
	"ability_holy": "res://assets/audio/ability_holy.mp3",
	"ability_dark": "res://assets/audio/ability_dark.mp3",
	"ability_nature": "res://assets/audio/ability_nature.mp3",
	# Shop / UI
	"buy": "res://assets/audio/buy.mp3",
	"sell": "res://assets/audio/sell.mp3",
	"reroll": "res://assets/audio/reroll.mp3",
	"upgrade": "res://assets/audio/upgrade.mp3",
	"warning": "res://assets/audio/warning.mp3",
	"coin": "res://assets/audio/coin.mp3",
	# Music
	"battle_music": "res://assets/audio/battle_music.mp3",
	# Game flow
	"round_start": "res://assets/audio/round_start.mp3",
	"victory": "res://assets/audio/victory.mp3",
	"defeat": "res://assets/audio/defeat.mp3",
	"game_over": "res://assets/audio/game_over.mp3",
}

var _music_player: AudioStreamPlayer

func _ready() -> void:
	# Build player pool
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)

	# Dedicated music player (separate from SFX pool)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "SFX"
	add_child(_music_player)

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

func play_music(sound_name: String, volume_db: float = -10.0) -> void:
	if not _sounds.has(sound_name):
		return
	_music_player.stream = _sounds[sound_name]
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
