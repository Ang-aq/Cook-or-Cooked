extends Node

# Example: different levels have different requirements
var levels := [
	{   # Level 1
		"Potato": {"combo": ["↑","↓","Z"], "amount": 2},
		"Onion":  {"combo": ["←","→","Z"], "amount": 1},
		"Meat": {"combo": ["→","↑","Z"], "amount": 5}
	},
	{   # Level 2
		"Potato": {"combo": ["↑","↓","Z"], "amount": 5},
		"Carrot": {"combo": ["↑","↑","Z"], "amount": 3},
		"Onion":  {"combo": ["←","→","Z"], "amount": 2}
	}
]

var current_level := 0

func get_current_requirements() -> Dictionary:
	return levels[current_level]

func next_level():
	if current_level < levels.size() - 1:
		current_level += 1
	else:
		print("Game complete!") # or trigger win screen
