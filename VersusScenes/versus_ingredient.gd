# res://Scripts/VersusIngredient.gd
extends "res://Scenes/Ingredients/Ingredient.gd"

var reserved_by: int = 0

func reserve(player_id: int) -> bool:
	if reserved_by != 0 and reserved_by != player_id:
		return false
	reserved_by = player_id
	return true

func get_reserved_player() -> int:
	return reserved_by
