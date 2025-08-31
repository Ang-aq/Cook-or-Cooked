extends Node2D
class_name PowerUpManager

@export var power_up_scene: PackedScene = preload("res://Scenes/sauce_power_up.tscn")
@export var spawn_interval: float = 5.0
var timer: float = 0.0
@export var spawn_y_min: float = 100
@export var spawn_y_max: float = 400
@export var spawn_x_start: float = -50

# Example combos you can set per power-up
var combos_list := [
	["→", "→", "→", "↑", "Z"],
	["↓", "←", "Z"]
]

func _process(delta: float) -> void:
	timer += delta
	if timer >= spawn_interval:
		_spawn_power_up()
		timer = 0

func _spawn_power_up() -> void:
	var power_up = power_up_scene.instantiate()
	power_up.position = Vector2(spawn_x_start, randf_range(spawn_y_min, spawn_y_max))
	# pick a random combo
	power_up.set_combo(combos_list[randi() % combos_list.size()])
	add_child(power_up)

# Call this from player input when a sequence is submitted
func check_all_power_ups(sequence: Array[String]) -> void:
	for child in get_children():
		if child is SaucePowerUp:
			child.check_sequence(sequence)
