extends Node
class_name SFXManager

# General SFX manager for all sound effects
var active_players: Array = []
var default_volume_db: float = -10.0
var music_volume_db: float = -10.0

# library
var sfx_library: Dictionary = { # USE OGGS OR LOOP MIGHT NOT WORK
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
	"boil": preload("res://Audio/bubbles-72783.ogg"),
	"sad": preload("res://Audio/failed.ogg"),
	"countdown": preload("res://Audio/countdown.ogg"),
	"menu": preload("res://Audio/click1.ogg"),
	"select": preload("res://Audio/select.ogg"),
}

# single audio player used for BGM
var music_player: AudioStreamPlayer
# When an intro is playing, _pending_loop_stream holds the stream to start when the intro finishes
var _pending_loop_stream: AudioStream = null
# fallback timer (only used if `finished` signal isn't available)
var _intro_end_timer: Timer = null

func _ready() -> void:
	# create one music player and keep it
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.volume_db = music_volume_db
	music_player.autoplay = false
	# connect finished signal so we can swap automatically from intro -> loop
	if music_player.has_signal("finished"):
		music_player.finished.connect(Callable(self, "_on_music_player_finished"))

# -------------------------
# SFX functions (unchanged)
# -------------------------
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

func _remove_and_free_player(player: AudioStreamPlayer) -> void:
	if active_players.has(player):
		active_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()

# -------------------------
# BGM functions (new + updated)
# -------------------------

# Simple BGM play (keeps older signature): play a stream (optionally loop)
func play_bgm(stream: AudioStream, loop: bool = true) -> void:
	if music_player == null:
		return
	_pending_loop_stream = null
	_cancel_intro_timer()
	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = music_volume_db
	music_player.play()

# The new helper: play an intro stream once, then immediately start the loop stream
func play_bgm_with_intro(intro_stream: AudioStream, loop_stream: AudioStream) -> void:
	if music_player == null:
		return
	# Stop existing playback and any pending intro
	_pending_loop_stream = null
	_cancel_intro_timer()
	music_player.stop()
	_pending_loop_stream = loop_stream
	music_player.stream = intro_stream
	music_player.volume_db = music_volume_db
	music_player.play()

	# If finished signal doesn't exist or if the stream length is 0, fallback to a Timer
	# (Most builds do provide finished, but this fallback is safe)
	if not music_player.has_signal("finished"):
		var len := 0.0
		if intro_stream != null:
			len = intro_stream.get_length()
		_cancel_intro_timer()
		_intro_end_timer = Timer.new()
		_intro_end_timer.wait_time = max(0.01, len)
		_intro_end_timer.one_shot = true
		_intro_end_timer.autostart = true
		add_child(_intro_end_timer)
		_intro_end_timer.timeout.connect(Callable(self, "_on_intro_timer_timeout"))

# Stop BGM altogether and cancel pending intro -> loop
func stop_bgm() -> void:
	if music_player != null:
		music_player.stop()
	_pending_loop_stream = null
	_cancel_intro_timer()

# Called when music_player emits finished (intro finished)
func _on_music_player_finished() -> void:
	if _pending_loop_stream != null:
		var stream: AudioStream = _pending_loop_stream
		_pending_loop_stream = null
		music_player.stream = stream
		music_player.volume_db = music_volume_db
		music_player.play()

# fallback timer ended (if finished signal wasn't available)
func _on_intro_timer_timeout() -> void:
	_cancel_intro_timer()
	_on_music_player_finished()

func _cancel_intro_timer() -> void:
	if _intro_end_timer and is_instance_valid(_intro_end_timer):
		_intro_end_timer.stop()
		_intro_end_timer.queue_free()
		_intro_end_timer = null

# -------------------------
# Volume helpers
# -------------------------
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

func set_music_volume(db: float) -> void:
	music_volume_db = db
	if music_player != null:
		music_player.volume_db = music_volume_db

func get_music_volume() -> float:
	return music_volume_db

func get_sfx_volume() -> float:
	return default_volume_db
