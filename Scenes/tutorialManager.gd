extends Node

@onready var tutorial_dialog: TutorialDialog = $TutorialDialog
@onready var meat: AnimatedSprite2D = $Meat
@onready var indicator: Node2D = $Indicator

# Arrow input combo
var arrow_combo: Array[String] = ["ui_up", "ui_right", "ui_down", "ui_left"]
var player_progress: int = 0
var waiting_for_input: bool = false
var meat_falling: bool = false

# Meat fall settings
@export var fall_speed: float = 160.0
@export var stop_y: float = 400.0
@export var start_x: float = 300.0
@export var start_y: float = -50.0

@export var main_scene_path: String = "res://Scenes/main.tscn"

func _ready() -> void:
	tutorial_dialog.dialogue_finished.connect(_on_dialogue_finished)

	var lines: Array[String] = [
		"Oh hello, you must be the chef's new apprentice!",
		"I work here too. I'll teach you the basics of this place.",
		"First is to collect ingredients. Look, there's one now!"
	]
	var portraits: Array[Texture] = [
		load("res://Sprites/Portrait1.png"),
		load("res://Sprites/Portrait2.png"),
		load("res://Sprites/Portrait3.png")
	]

	tutorial_dialog.start_dialogue(lines, portraits)

	meat.visible = false
	indicator.visible = false

func _on_dialogue_finished() -> void:
	_start_meat_tutorial()

func _start_meat_tutorial() -> void:
	meat.position = Vector2(start_x, start_y)
	meat.visible = true
	meat.play("Meat")
	meat_falling = true
	waiting_for_input = false
	player_progress = 0

func _process(delta: float) -> void:
	if meat_falling:
		meat.position.y += fall_speed * delta
		if meat.position.y >= stop_y:
			meat.position.y = stop_y
			meat_falling = false
			_show_arrow_prompt()

func _show_arrow_prompt() -> void:
	# Show indicator above meat
	indicator.position = meat.position + Vector2(0, -40)
	indicator.visible = true
	player_progress = 0
	waiting_for_input = true

	# Move dialogue UI to top
	tutorial_dialog.get_node("UI").position = Vector2(100, -60)
	tutorial_dialog.get_node("Transition").position = Vector2(420, 68)

	# Show instruction
	var prompt: Array[String] = ["Use arrow keys to chop ingredients"]
	var portraits: Array[Texture] = [load("res://Sprites/Portrait1.png")]
	tutorial_dialog.start_dialogue(prompt, portraits)

func _input(event: InputEvent) -> void:
	if not waiting_for_input:
		return
	if not event.is_pressed() or event.is_echo() or event is InputEventMouseButton:
		return

	var matched_action := ""
	for action in arrow_combo:
		if event.is_action_pressed(action):
			matched_action = action
			break

	if matched_action == "":
		player_progress = 0
		var bad_prompt: Array[String] = ["Please use only arrow keys!"]
		var portraits: Array[Texture] = [load("res://Sprites/Portrait2.png")]
		tutorial_dialog.start_dialogue(bad_prompt, portraits)
		return

	var expected = arrow_combo[player_progress]
	if matched_action == expected:
		player_progress += 1
		if player_progress >= arrow_combo.size():
			_on_combo_success()
	else:
		player_progress = 0
		var wrong_prompt: Array[String] = ["Wrong order, try: ↑ → ↓ ←"]
		var portraits: Array[Texture] = [load("res://Sprites/Portrait2.png")]
		tutorial_dialog.start_dialogue(wrong_prompt, portraits)

func _on_combo_success() -> void:
	waiting_for_input = false
	indicator.visible = false

	var success_lines: Array[String] = ["Perfect! You did it. Time to move on to the real kitchen."]
	var portraits: Array[Texture] = [load("res://Sprites/Portrait1.png")]
	tutorial_dialog.dialogue_finished.connect(_go_to_main_game)
	tutorial_dialog.start_dialogue(success_lines, portraits)

func _go_to_main_game() -> void:
	get_tree().change_scene_to_file(main_scene_path)
