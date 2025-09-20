extends Node2D
@onready var button: Button = $Button
func _ready() -> void:
	button.disabled = false

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/titlescreen.tscn")
	button.disabled = true
	pass # Replace with function body.
