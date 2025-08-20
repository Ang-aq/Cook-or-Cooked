extends CharacterBody2D

@export var speed: float = 100.0
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Make sure pest is tagged correctly
	add_to_group("pests")

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		velocity = direction.normalized() * speed
		move_and_slide()
