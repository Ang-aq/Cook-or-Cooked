extends Control

@onready var score_label: Label = $VBox/ScoreLabel
@onready var highscore_label: Label = $VBox/HighscoreLabel
@onready var restart_button: Button = $Button
@onready var reason_label: Label = $ReasonLabel

func _ready() -> void:
	# load saved scores
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load("user://scores.cfg")

	var last: int = 0
	var high: int = 0
	var reason: String = ""

	if err == OK:
		last = int(cfg.get_value("scores", "last_score", 0))
		high = int(cfg.get_value("scores", "high_score", 0))
		reason = str(cfg.get_value("scores", "last_fail_reason", ""))

	score_label.text = "Score: %d" % last
	highscore_label.text = "High Score: %d" % high
	reason_label.text = reason

	# connect pressed safely
	var pressed_callable := Callable(self, "_on_restart_pressed")
	if not restart_button.is_connected("pressed", pressed_callable):
		restart_button.pressed.connect(pressed_callable)

func _on_restart_pressed() -> void:
	# Reset LevelManager to the first level (index 0) so "Try Again" starts the game fresh
	if LevelManager != null:
		LevelManager.current_level = 0
	else:
		push_warning("LevelManager autoload not found — couldn't reset current_level.")
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
