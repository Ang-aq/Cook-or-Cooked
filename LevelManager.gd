extends Node

var levels := [
	{   # Level 1
		"requirements": {
			"Onion":  {"combo": ["←","→","Z"], "amount": 1},
			"Meat":   {"combo": ["→","↑","Z"], "amount": 3},
		},
		"dish_texture": preload("res://Sprites/Ingredients/yakitori.png"),
		"dish_name": "Beef Yakitori",
		"time_limit": 60
	},
	{   # Level 2
		"requirements": {
			"Potato": {"combo": ["↑","↓","Z"], "amount": 3},
			"Carrot": {"combo": ["↑","↑","↓","Z"], "amount": 3},
			"Onion":  {"combo": ["←","→","↓","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Ingredients/beefCurry.png"),
		"dish_name": "Beef Curry",
		"time_limit": 50
	},
	{	# Level 3
		"requirements": {
			"Potato": {"combo": ["↑","↓","↑","Z"], "amount": 5},
			"Carrot": {"combo": ["↑","↑","↑","Z"], "amount": 3},
			"Onion":  {"combo": ["←","→","→","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Ingredients/shrimpCurry.png"),
		"dish_name": "Shrimp Curry",
		"time_limit": 40
	}
]

var current_level: int = 0

# --- Helpers for current level ---
func get_current_requirements() -> Dictionary:
	return levels[current_level]["requirements"]

func has_requirement_for(ingredient: String) -> bool:
	return get_current_requirements().has(ingredient)

func get_requirement_for(ingredient: String) -> Dictionary:
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
	if levels.size() == 0:
		return

	if current_level >= levels.size() - 1:
		# Last level finished → calculate score and go to demo_complete
		var main_node = get_node_or_null("/root/Main")
		if main_node:
			var final_score = main_node._calculate_score()
			main_node._save_score(final_score, "Completed all levels")
		get_tree().change_scene_to_file("res://Scenes/demo_complete.tscn")
	else:
		# Advance to next level
		current_level += 1
