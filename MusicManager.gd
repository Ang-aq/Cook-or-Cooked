extends Node
class_name SFXManager

var music_player: AudioStreamPlayer
var active_players: Array = []
var default_volume_db: float = -10.0

var sfx_library: Dictionary = {
#	"mosquito_hit": preload("res://Sounds/mosquito_hit.wav"),
#	"pest_attack": preload("res://Sounds/pest_attack.wav"),
#	"ingredient_collect": preload("res://Sounds/ingredient_collect.wav"),
	"level_up": preload("res://Audio/LevelUp.ogg"),
	"chop": preload("res://Audio/Cut.ogg")
}

func _ready(): 
	music_player = AudioStreamPlayer.new() 
	add_child(music_player) 
	music_player.volume_db = -20 # 0 = default, -10 = quieter, -80 = silent
	var music_stream = load("res://Sprites/Background.ogg") as AudioStream 
	music_player.stream = music_stream
	
	# bg music
	music_player.play()
	
	# Make it persist across scenes
	music_player.autoplay = true 
	music_player.bus = "Master"

func play_sfx(sfx_name: String, loop: bool = false) -> void:
	if not sfx_library.has(sfx_name):
		push_warning("SFXManager: Sound not found: %s" % sfx_name)
		return

	var player := AudioStreamPlayer.new()
	var stream: AudioStream = sfx_library[sfx_name]

	# Enable looping if supported
	if loop:
		if stream is AudioStreamWAV:
			stream.loop_enabled = true
		elif stream is AudioStreamOggVorbis:
			stream.loop_enabled = true

	player.stream = stream
	player.volume_db = default_volume_db
	player.autoplay = false
	add_child(player)

	player.play()
	active_players.append(player)

	if not loop:
		# Free the player when the sound finishes
		var duration = player.stream.get_length()
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.autostart = true
		add_child(timer)
		timer.timeout.connect(Callable(self, "_remove_player").bind(player))
		timer.timeout.connect(Callable(player, "queue_free"))

func stop(sfx_name: String) -> void:
	for player in active_players.duplicate():
		if player.stream == sfx_library.get(sfx_name, null):
			player.stop()
			player.queue_free()
			active_players.erase(player)

func _remove_player(player: AudioStreamPlayer) -> void:
	if active_players.has(player):
		active_players.erase(player)
