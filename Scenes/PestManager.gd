# res://Managers/PestManager.gd
extends Node2D
class_name PestManager

# --- Configurable pest types (PackedScenes) ---
@export var pest_types: Array[PackedScene] = [
	preload("res://Scenes/mosquito.tscn")
]

# --- Spawn timing ---
@export var spawn_interval_min: float = 5.0
@export var spawn_interval_max: float = 12.0
@export var max_active_pests: int = 3

# --- Optional spawn bounds (local to this manager node) ---
@export var spawn_x_min: float = 50.0
@export var spawn_x_max: float = 800.0
@export var spawn_y_min: float = 150.0
@export var spawn_y_max: float = 500.0

# --- Internal state ---
var _spawn_timer: float = 0.0
var last_fail_reason: String = ""

func _ready() -> void:
	_reset_spawn_timer()

func _process(delta: float) -> void:
	# Only spawn while under cap
	if get_child_count() >= max_active_pests:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_random_pest()
		_reset_spawn_timer()

func _reset_spawn_timer() -> void:
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)

func _spawn_random_pest() -> void:
	if pest_types.is_empty():
		return

	var scene: PackedScene = pest_types[randi() % pest_types.size()]
	if scene == null:
		return

	var inst: Node2D = scene.instantiate()
	if not inst:
		return

	# randomize spawn position in manager's local space
	inst.position = Vector2(
		randf_range(spawn_x_min, spawn_x_max),
		randf_range(spawn_y_min, spawn_y_max)
	)
	add_child(inst)

	# Connect signals
	if inst.has_signal("defeated"):
		inst.defeated.connect(Callable(self, "_on_pest_defeated"))
	if inst.has_signal("attacked"):
		inst.attacked.connect(Callable(self, "_on_pest_attacked"))
	if inst.has_signal("pest_failed"):
		# Forward the fail reason up to the Main scene
		inst.pest_failed.connect(func(reason: String):
			get_tree().call_group("Game", "_on_pest_failed", reason)
		)

# --- Signal handlers from pests ---
func _on_pest_defeated(pest_node: Node) -> void:
	if is_instance_valid(pest_node) and pest_node.get_parent() == self:
		pest_node.queue_free()

func _on_pest_attacked(pest_node: Node) -> void:
	if is_instance_valid(pest_node):
		if pest_node.get_parent() == self:
			pest_node.queue_free()
		# Forward to Main
		get_tree().call_group("Game", "_on_pest_attacked", pest_node)

func _on_pest_failed(pest_node: Node, reason: String) -> void:
	last_fail_reason = reason
	if is_instance_valid(pest_node) and pest_node.get_parent() == self:
		pest_node.queue_free()
	# Forward to Main so it can reduce life / trigger GameOver
	# get_tree().call_group("Game", "_on_pest_failed", reason)

# --- Utility ---
# Called by Main (or player input) to check if any pest consumes the submitted combo.
# Returns true if a pest consumed (handled) the sequence — useful to stop ingredient checks.
func check_sequence(sequence: Array) -> bool:
	for pest in get_children():
		if not is_instance_valid(pest):
			continue
		if pest.has_method("check_sequence"):
			var handled: bool = pest.check_sequence(sequence)
			if handled:
				return true
	return false
