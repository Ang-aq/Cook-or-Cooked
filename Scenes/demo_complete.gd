extends Control
@onready var score_label: Label = $ScoreLabel
@onready var title_button: Button = $BackButton

func _ready() -> void:
	# focus the button for keyboard/gamepad
	$ToTitle.grab_focus()
	var cfg = ConfigFile.new()
	cfg.load("user://scores.cfg")
	var last_score: int = int(cfg.get_value("scores", "last_score", 0))
	score_label.text = "Final Score: %d" % last_score

func _on_to_title_pressed() -> void:
	# Reset level progress so new run starts from the beginning
	LevelManager.current_level = 0
	
	# Optionally reset saved state
	if get_tree().has_group("Game"):
		for g in get_tree().get_nodes_in_group("Game"):
			g.saved_hearts = g.max_hearts
			g.saved_combo = 0
	
	get_tree().change_scene_to_file("res://Scenes/titlescreen.tscn")
