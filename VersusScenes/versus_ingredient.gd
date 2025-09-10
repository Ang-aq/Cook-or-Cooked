extends "res://Scenes/Ingredients/Ingredient.gd"

var reserved_by: int = 0

func reserve(player_id: int) -> bool:
	if reserved_by != 0 and reserved_by != player_id:
		return false
	reserved_by = player_id
	return true

func get_reserved_player() -> int:
	return reserved_by

func play_slash_sequence(sequence: Array) -> void:
	# Run the base chopping logic (very important: sets is_chopped, emits signals, etc.)
	super.play_slash_sequence(sequence)
	
	# Add color tint based on who reserved
	var slash_sprite: AnimatedSprite2D = $AnimatedSprite2D/Slash
	match reserved_by:
		1: slash_sprite.modulate = Color.html("#4a59e0") # custom blue for P1
		2: slash_sprite.modulate = Color.html("#db4430") # custom red for P2
		_: slash_sprite.modulate = Color(1, 1, 1)        # fallback
