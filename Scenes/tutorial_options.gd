extends Control

@export var tutorial_scene_path: String = "res://Scenes/tutorial.tscn"
@export var main_scene_path: String = "res://Scenes/main.tscn"

@onready var yes_button: Button = $Yes
@onready var no_button: Button = $No

func _ready() -> void:
	# Make buttons mouse-only (ignore keyboard/gamepad input)
	yes_button.focus_mode = Control.FOCUS_NONE
	no_button.focus_mode = Control.FOCUS_NONE
	
	# Connect mouse clicks
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)

func _on_yes_pressed() -> void:
	_disable_buttons()
	get_tree().change_scene_to_file(tutorial_scene_path)

func _on_no_pressed() -> void:
	_disable_buttons()
	get_tree().change_scene_to_file(main_scene_path)

func _disable_buttons() -> void:
	yes_button.disabled = true
	no_button.disabled = true

# Handle keyboard input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_Y:
				_on_yes_pressed()
			KEY_N:
				_on_no_pressed()
