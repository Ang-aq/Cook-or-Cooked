extends Node

var levels := [
	{   # Level 1
		"requirements": {
			"Potato": {"combo": ["↑","↓","Z"], "amount": 2},
			"Onion":  {"combo": ["←","→","Z"], "amount": 2},
			"Meat":   {"combo": ["→","↑","Z"], "amount": 3},
			"Carrot": {"combo": ["↑","↑","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Ingredients/shrimpCurry.png"),
		"dish_name": "Japanese Curry",
		"time_limit": 60   # seconds
	},
	{   # Level 2
		"requirements": {
			"Potato": {"combo": ["↑","↓","Z"], "amount": 5},
			"Carrot": {"combo": ["↑","↑","Z"], "amount": 3},
			"Onion":  {"combo": ["←","→","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Ingredients/shrimpCurry.png"),
		"dish_name": "Shrimp Curry",
		"time_limit": 50   # seconds
	}
]

var current_level: int = 0


# --- Helpers for accessing current level data ---

func get_current_requirements() -> Dictionary:
	return levels[current_level]["requirements"]

func has_requirement_for(ingredient: String) -> bool:
	return get_current_requirements().has(ingredient)

func get_requirement_for(ingredient: String) -> Dictionary:
	# Returns {} if ingredient doesn't exist to avoid crashes
	if has_requirement_for(ingredient):
		return get_current_requirements()[ingredient]
	return {}

func get_current_dish() -> Dictionary:
	return {
		"texture": levels[current_level]["dish_texture"],
		"name": levels[current_level]["dish_name"],
		"time_limit": levels[current_level]["time_limit"]
	}


# --- Level progression ---

func next_level() -> void:
	current_level += 1
	if current_level >= levels.size():
		current_level = 0  # or emit_signal("game_complete")
