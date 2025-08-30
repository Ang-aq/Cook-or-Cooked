extends Node2D

@export var MeatScene: PackedScene
@export var SpringOnionScene: PackedScene

func spawn_ingredient(type: String, stop_in_middle: bool = false):
	var ingredient: Node2D

	match type:
		#"Meat":
			#ingredient = MeatScene.instantiate()
		#"SpringOnion":
			#ingredient = SpringOnionScene.instantiate()
		_:
			return

	add_child(ingredient)

	# Start above screen
	ingredient.position = Vector2(400, -50) # adjust X for your scene

	if stop_in_middle:
		# Tween it to stop at middle
		var tween = get_tree().create_tween()
		tween.tween_property(ingredient, "position:y", 200, 1.0) # stops mid-screen
