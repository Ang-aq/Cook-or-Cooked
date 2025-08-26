extends Node

var music_player: AudioStreamPlayer

func _ready():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.volume_db = -20  # 0 = default, -10 = quieter, -80 = silent

	var music_stream = load("res://Audio/Music.ogg") as AudioStream
	music_player.stream = music_stream

	#Play music
	music_player.play()

	# Make it persist across scenes 
	music_player.autoplay = true
	music_player.bus = "Master" 
