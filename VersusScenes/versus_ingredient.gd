extends "res://Scenes/Ingredients/Ingredient.gd"

@export var base_fall_speed: float = 120.0
var fall_speed: float = 120.0
var reserved_by: int = 0

func reserve(player_id: int) -> bool:
	if reserved_by != 0 and reserved_by != player_id:
		return false
	reserved_by = player_id
	return true

func get_reserved_player() -> int:
	return reserved_by

func play_slash_sequence(sequence: Array) -> void:
	super.play_slash_sequence(sequence)
	
	var slash_sprite: AnimatedSprite2D = $AnimatedSprite2D/Slash
	match reserved_by:
		1: slash_sprite.modulate = Color.html("#4a59e0") 
		2: slash_sprite.modulate = Color.html("#db4430") 
		_: slash_sprite.modulate = Color(1, 1, 1)    
		
func set_fall_speed(s: float) -> void:
	fall_speed = s

func _physics_process(delta: float) -> void:
	# simple vertical movement; if you have collision handling use move_and_collide/move_and_slide
	position.y += fall_speed * delta
