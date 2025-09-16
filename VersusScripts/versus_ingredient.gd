extends "res://Scripts/Ingredient.gd"

@export var base_fall_speed: float = 120.0
var fall_speed: float = 120.0
var reserved_by: int = 0
	
@onready var chopped: Node2D = $Chopped

func _ready() -> void:
	movement_enabled = false
	speed = 0
	fall_speed = base_fall_speed

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
	
	is_chopped = true

func set_fall_speed(s: float) -> void:
	fall_speed = s
	speed = 0
	movement_enabled = false

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta

func _finish_chop() -> void:
	super._finish_chop()
	speed = 0
	movement_enabled = false
