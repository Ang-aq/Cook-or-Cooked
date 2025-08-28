extends CanvasLayer

# Path to your main game scene
@export var main_scene_path: String = "res://Scenes/instructions.tscn"

func _unhandled_input(event: InputEvent) -> void:
	# Any key, mouse, or controller input triggers the main game
	if event.is_pressed():
		_go_to_main_scene()

func _go_to_main_scene() -> void:
	var main_scene = load(main_scene_path).instantiate()
	
	# Add main scene to the root
	get_tree().root.add_child(main_scene)
	
	# Remove the title screen
	queue_free()
