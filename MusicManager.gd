extends Node
class_name SFXManager

# General SFX manager for all sound effects
var active_players: Array = []
var default_volume_db: float = -10.0

# SFX library: add new sounds here
var sfx_library: Dictionary = {
	"level_up": preload("res://Audio/LevelUp.ogg"),
	"chop": preload("res://Audio/Cut.ogg"),
	"mosquito": preload("res://Audio/mosquito.ogg"),
	"slash": preload("res://Audio/slash.ogg"),
	"wrong": preload("res://Audio/heart.ogg"),
	"splat": preload("res://Audio/Splat.ogg"),
	"crossout": preload("res://Audio/crossout.ogg"),
	"powerup": preload("res://Audio/powerup.ogg"),
	"sauce_hot": preload("res://Audio/powerup.ogg"),
	"sauce_soy": preload("res://Audio/powerup.ogg"),
	"sauce_sweet": preload("res://Audio/powerup.ogg"),
	"sauce_mystery": preload("res://Audio/powerup.ogg"),
	"menu": preload("res://Audio/MenuPop.ogg"),
	"boil": preload("res://Audio/bubbles-72783.ogg"),
	"sad": preload("res://Audio/failed.ogg"),
	"countdown": preload("res://Audio/countdown.ogg"),
}

var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.volume_db = 5
	music_player.bus = "Master"
	music_player.autoplay = false  # Play manually

# Play a sound effect
func play_sfx(sfx_name: String, loop: bool = false) -> void:
	if not sfx_library.has(sfx_name):
		push_warning("SFXManager: Sound not found: %s" % sfx_name)
		return

	var stream: AudioStream = sfx_library[sfx_name]
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(player)
	
	player.stream = stream
	player.volume_db = default_volume_db
	player.autoplay = false
	player.bus = "Master"

	# Enable looping if requested (works for WAV or OGG)
	if loop:
		if stream is AudioStreamWAV:
			stream.loop_enabled = true
		elif stream is AudioStreamOggVorbis:
			stream.loop_enabled = true

	player.play()
	active_players.append(player)

	if not loop:
		var duration: float = 0.0
		if player.stream != null:
			duration = player.stream.get_length()
		var timer: Timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		timer.autostart = true
		add_child(timer)
		timer.timeout.connect(Callable(self, "_remove_and_free_player").bind(player))

# Stop a specific sound effect
func stop_sfx(sfx_name: String) -> void:
	for player in active_players.duplicate():
		if player.stream == sfx_library.get(sfx_name, null):
			player.stop()
			player.queue_free()
			active_players.erase(player)

func stop_all_sfx() -> void:
	for player in active_players.duplicate():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	active_players.clear()

# Internal: remove and free the player
func _remove_and_free_player(player: AudioStreamPlayer) -> void:
	if active_players.has(player):
		active_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()

func play_bgm(stream: AudioStream, loop: bool = true) -> void:
	if music_player == null:
		return
	music_player.stop()
	music_player.stream = stream
	music_player.play()

func stop_bgm() -> void:
	if music_player != null:
		music_player.stop()

func set_all_sfx_volume(db: float) -> void:
	default_volume_db = db
	for player in active_players:
		if is_instance_valid(player):
			player.volume_db = db

func set_sfx_volume_for(sfx_name: String, db: float) -> void:
	if not sfx_library.has(sfx_name):
		push_warning("SFXManager: Sound not found: %s" % sfx_name)
		return

	var stream: AudioStream = sfx_library[sfx_name]
	for player in active_players:
		if is_instance_valid(player) and player.stream == stream:
			player.volume_db = db
