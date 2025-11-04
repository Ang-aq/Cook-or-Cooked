extends Control

@onready var title_label: Label = $Title
@onready var score_label: Label = $StatsContainer/ScoreLabel
@onready var reason_label: Label = $StatsContainer/ReasonLabel
@onready var continue_label: Label = $ContinueLabel

var input_locked := true

func _ready() -> void:
	_load_scores()
	title_label.modulate.a = 0.0
	reason_label.modulate.a = 0.0
	score_label.modulate.a = 0.0
	continue_label.modulate.a = 0.0
	_play_intro()

func _load_scores() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://scores.cfg")
	var last := int(cfg.get_value("scores", "last_score", 0))
	var reason := str(cfg.get_value("scores", "last_fail_reason", ""))
	score_label.text = "Score: %d" % last
	reason_label.text = reason

func _play_intro() -> void:
	MusicManager.play_sfx("sad")
	var tween := create_tween()

	tween.tween_property(title_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	var tween2 := create_tween()
	tween2.tween_property(reason_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween2.finished

	var tween3 := create_tween()
	tween3.tween_property(score_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween3.finished

	var tween4 := create_tween()
	tween4.tween_property(continue_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween4.finished

	_start_continue_blink()

	input_locked = false

func _start_continue_blink() -> void:
	var tween := create_tween()
	tween.set_loops()  # infinite loops
	tween.tween_property(continue_label, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(continue_label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event.is_pressed() and not event.is_echo():
		MusicManager.play_sfx("level_up")
		_go_to_title()

func _go_to_title() -> void:
	LevelManager.current_level = 0
	get_tree().change_scene_to_file("res://Scenes/titlescreen.tscn")
