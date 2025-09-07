extends "res://Scenes/Ingredients/Ingredient.gd"

# Which player reserved this ingredient (0 = unreserved, 1 = Player 1, 2 = Player 2)
var reserved_by: int = 0

# Called from VersusMain when a player submits the correct combo
func reserve(player_id: int) -> bool:
	# Already reserved by someone else?
	if reserved_by != 0 and reserved_by != player_id:
		return false
	reserved_by = player_id
	return true

# Override play_slash_sequence to respect reservations
func play_slash_sequence(sequence: Array) -> void:
	if reserved_by == 0:
		# If not reserved yet, fall back to original behavior
		reserved_by = 999 # safety marker if called directly
	super.play_slash_sequence(sequence)

# Convenience getter
func get_reserved_player() -> int:
	return reserved_by
