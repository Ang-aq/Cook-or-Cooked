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

func _unhandled_input(event: InputEvent) -> void:
	if restart_button.disabled:
		return
	if event.is_action_pressed("joystickStart"):  # Z
		_on_restart_pressed()

func _on_restart_pressed() -> void:
	if restart_button.disabled:
		return
	# fixes glitch where the game would start from the level you died
	LevelManager.current_level = 0
	restart_button.disabled = true
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
