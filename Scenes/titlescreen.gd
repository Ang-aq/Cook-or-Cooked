extends CanvasLayer

# Path to your main game scene
@export var main_scene_path: String = "res://Scenes/tutorial.tscn"

func _unhandled_input(event: InputEvent) -> void:	
	# Only respond to keyboard or joystick input, ignore mouse
	if event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		_go_to_main_scene()

func _go_to_main_scene() -> void:
	var main_scene = load(main_scene_path).instantiate()
	
	# Add main scene to the root
	get_tree().root.add_child(main_scene)
	
	# Remove the title screen
	queue_free()
