extends Node

var levels := [
	{   # Level 1
		"requirements": {
			"Spring Onion":  {"combo": ["←","→","Z"], "amount": 1},
			"Meat":   {"combo": ["→","↑","Z"], "amount": 3},
		},
		"dish_texture": preload("res://Sprites/Ingredients/yakitori.png"),
		"dish_name": "Beef Yakitori",
		"time_limit": 60
	},
	{   # Level 2
		"requirements": {
			"Potato": {"combo": ["↑","↓","Z"], "amount": 3},
			"Carrot": {"combo": ["↑","↑","↑","Z"], "amount": 3},
			"Onion":  {"combo": ["←","→","↓","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Ingredients/beefCurry.png"),
		"dish_name": "Beef Curry",
		"time_limit": 50
	},
	{	# Level 3
		"requirements": {
			"Potato": {"combo": ["↑","↓","↑","Z"], "amount": 5},
			"Carrot": {"combo": ["↑","↑","↑","↑","Z"], "amount": 3},
			"Onion":  {"combo": ["←","→","→","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Ingredients/shrimpCurry.png"),
		"dish_name": "Shrimp Curry",
		"time_limit": 40
	},
	{	# Level 4
		"requirements": {
			"Meat": {"combo": ["→","↑","↑","Z"], "amount": 4},
			"Tomato": {"combo": ["←","→","←","→","Z"], "amount": 2},
			"Onion":  {"combo": ["←","→","→","Z"], "amount": 2},
			"GreenBean":  {"combo": ["↓","↓","→","Z"], "amount": 2}
		},
		"dish_texture": preload("res://Sprites/Sinigang.png"),
		"dish_name": "Sinigang!?",
		"time_limit": 40
	},
	{   # Level 5 (Boss Fight)
	"requirements": {},   # no ingredients
	"dish_texture": preload("res://Sprites/Pests/shiba1.png"),
	"dish_name": "Shiba Showdown",
	"time_limit": 90,
	"is_boss": true
	}
]

var current_level: int = 0

func get_current_requirements() -> Dictionary:
	return levels[current_level]["requirements"]

func has_requirement_for(ingredient: String) -> bool:
	return get_current_requirements().has(ingredient)

func get_requirement_for(ingredient: String) -> Dictionary:
	if has_requirement_for(ingredient):
		return get_current_requirements()[ingredient]
	return {}

func get_current_dish() -> Dictionary:
	var dish = levels[current_level]
	return {
		"texture": dish["dish_texture"],
		"name": dish["dish_name"],
		"time_limit": dish["time_limit"],
		"is_boss": dish.get("is_boss", false)
	}

func next_level() -> void:
	if levels.size() == 0:
		return

	if current_level >= levels.size() - 1:
		var main_node = get_node_or_null("/root/Main")
		if main_node:
			var final_score = main_node._calculate_score()
			main_node._save_score(final_score, "Completed all levels")
		get_tree().change_scene_to_file("res://Scenes/demo_complete.tscn")
	else:
		# Advance to next level
		current_level += 1
