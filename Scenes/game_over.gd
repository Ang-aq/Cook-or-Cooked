extends Control

@onready var score_label: Label = $VBox/ScoreLabel
@onready var highscore_label: Label = $VBox/HighscoreLabel
@onready var restart_button: Button = $Button

func _ready() -> void:
	# load saved scores
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load("user://scores.cfg")
	var last: int = 0
	var high: int = 0
	if err == OK:
		last = int(cfg.get_value("scores", "last_score", 0))
		high = int(cfg.get_value("scores", "high_score", 0))

	score_label.text = "Score: %d" % last
	highscore_label.text = "High Score: %d" % high

	# connect pressed safely
	var pressed_callable := Callable(self, "_on_restart_pressed")
	if not restart_button.is_connected("pressed", pressed_callable):
		restart_button.pressed.connect(pressed_callable)

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
