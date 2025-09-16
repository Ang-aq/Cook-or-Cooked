extends Node
class_name IngredientManager

signal ingredient_spawned(ingredient_node)
signal ingredient_chopped(ingredient_name)

@export var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@export var ingredient_container_path: NodePath = NodePath("..") 

# spawn tuning (defaults copied from your Main)
@export var spawn_interval: float = 1.5
@export var max_active_ingredients: int = 100
@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float = 80.0
@export var spawn_start_y: float = -100.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawn_timer: float = 0.0

var required_ingredients: Dictionary = {}
var collected_counts: Dictionary = {}

@onready var ingredient_container: Node = get_node_or_null(ingredient_container_path)

var _running: bool = true

func _ready() -> void:
	rng.randomize()
	spawn_timer = randf_range(0.25, spawn_interval)
	set_process(true)

func start() -> void:
	_running = true
	set_process(true)

func stop() -> void:
	_running = false
	set_process(false)

func set_requirements(req: Dictionary, collected: Dictionary) -> void:
	required_ingredients = req
	collected_counts = collected

func clear_all() -> void:
	if not is_instance_valid(ingredient_container):
		return
	for child in ingredient_container.get_children():
		if is_instance_valid(child):
			child.queue_free()

func get_active_count() -> int:
	if not is_instance_valid(ingredient_container):
		return 0
	return ingredient_container.get_child_count()

func force_spawn(name: String) -> void:
	if name == "" or not is_instance_valid(ingredient_container):
		return
	spawn_ingredient(name)

func _process(delta: float) -> void:
	if not _running:
		return
	var parent = get_parent()
	# Respect a parent's game_paused flag if present (non-fatal if it doesn't exist)
	if parent and parent.has_method("get") and "game_paused" in parent and parent.game_paused:
		return

	if not is_instance_valid(ingredient_container):
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_needed()
		spawn_timer = spawn_interval

func _try_spawn_needed() -> void:
	if not is_instance_valid(ingredient_container):
		return
	if ingredient_container.get_child_count() >= max_active_ingredients:
		return
	var name := _pick_weighted_ingredient_name()
	if name == "":
		return
	spawn_ingredient(name)

func _pick_weighted_ingredient_name() -> String:
	if required_ingredients == null or required_ingredients.size() == 0:
		return ""
	var pool: Array = []
	for name in required_ingredients.keys():
		var required_count = int(required_ingredients[name].get("count", 0))
		var collected_count = collected_counts.get(name, 0)
		if collected_count < required_count:
			pool.append_array([name, name, name])
		else:
			pool.append(name)
	# safety
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

func spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	ingredient_container.add_child(ing_node)
	
	var ing := ing_node as Ingredient
	if ing == null:
		push_error("Ingredients.tscn root must extend Ingredient.gd!")
		ing_node.queue_free()
		return
	
	var base_speed = 130.0
	var level = LevelManager.current_level
	var speed_multiplier = 0.7 + (level * 0.15)
	ing.speed = base_speed * speed_multiplier
	
	ing.original_speed = ing.speed
	
	var combo_arr: Array = []
	if required_ingredients.has(ingredient_name) and required_ingredients[ingredient_name].has("combo"):
		var raw = required_ingredients[ingredient_name]["combo"]
		if raw is Array:
			combo_arr = raw.duplicate(true)
	ing.set_combo_and_name(combo_arr, ingredient_name)
	
	# NOTE: do NOT connect ingredient.chop_completed here.
	# IngredientManager (if used) already connects and re-emits the event.
	# If Main spawns ingredients directly and you prefer Main to handle chop events,
	# connect here (but make sure you do not also connect via IngredientManager).
	
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)

func _on_ingredient_chopped(ingredient_name: String) -> void:
	emit_signal("ingredient_chopped", ingredient_name)

func flash_topmost_ingredient(name: String) -> void:
	if not is_instance_valid(ingredient_container):
		return
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		var ing = node as Ingredient
		if ing == null:
			continue
		if ing.ingredient_name != name:
			continue
		if not ing.is_chopped:
			ing.flash_x()
			return

	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		var ing = node as Ingredient
		if ing == null:
			continue
		if ing.ingredient_name == name:
			if ing.has_method("flash_x"):
				ing.flash_x()
			return
