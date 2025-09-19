extends Node2D

func _ready() -> void:
	$Button.enabled = true

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/titlescreen.tscn")
	$Button.disabled = true
	pass # Replace with function body.
