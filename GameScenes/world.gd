extends Node2D

@export var PestScene: PackedScene
@export var spawn_interval: float = 2.0   # seconds between spawns
var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	spawn_pest()
#	$SpawnTimer.wait_time = spawn_interval
#	$SpawnTimer.start()

func _on_SpawnTimer_timeout() -> void:
	spawn_pest()

func spawn_pest() -> void:
	# var pest_instance = PestScene.instantiate()

	# Randomly pick which edge of the screen to spawn from
	var edge = randi() % 4
	var spawn_position: Vector2
	var dir: Vector2

	match edge:
		0: # Top
			spawn_position = Vector2(randi_range(0, screen_size.x), -20)
			dir = Vector2(0, 1)
		1: # Bottom
			spawn_position = Vector2(randi_range(0, screen_size.x), screen_size.y + 20)
			dir = Vector2(0, -1)
		2: # Left
			spawn_position = Vector2(-20, randi_range(0, screen_size.y))
			dir = Vector2(1, 0)
		3: # Right
			spawn_position = Vector2(screen_size.x + 20, randi_range(0, screen_size.y))
			dir = Vector2(-1, 0)

	#pest_instance.position = spawn_position
	#pest_instance.direction = dir

	#add_child(pest_instance)
