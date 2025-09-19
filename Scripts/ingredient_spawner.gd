# ingredient for tutorial
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

	ingredient.position = Vector2(400, -50)

	if stop_in_middle:
		var tween = get_tree().create_tween()
		tween.tween_property(ingredient, "position:y", 200, 1.0)
