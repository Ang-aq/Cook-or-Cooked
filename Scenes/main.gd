extends Node2D

@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var player_input: Node = $PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $Checklist  # Node with Checklist.gd attached

# Levels!!!!!!!!!!
var required_ingredients: Dictionary = {
	"Potato": {"combo": ["↑","↓","Z"], "count": 3},
	"Onion":  {"combo": ["←","→","Z"], "count": 2},
	"Carrot": {"combo": ["↑","↑","Z"], "count": 4},
	"Meat": {"combo": ["→","↑","Z"], "count": 3}
}

var collected_counts: Dictionary = {}   

# Spawning Ingredients
@export var spawn_interval: float = 1.25
@export var max_active_ingredients: int = 6
var spawn_timer: float = 0.0
var game_over: bool = false

func _ready() -> void:
	# Fix HTML5 canvas stretch
	if Engine.has_singleton("JavaScript"):
		var js = Engine.get_singleton("JavaScript")
		js.eval("window.addEventListener('resize', () => {let c=document.getElementById('canvas'); if(c){c.style.width='100%'; c.style.height='100%';}});")

	# Ensure PlayerInput exists and connect signals
	if player_input == null:
		push_error("PlayerInput node not found!")
		return
	if not player_input.has_signal("sequence_submitted"):
		push_error("PlayerInput is missing 'sequence_submitted' signal.")
		return
	player_input.sequence_submitted.connect(_on_sequence_submitted)
	if player_input.has_signal("sequence_reset"):
		player_input.sequence_reset.connect(_on_sequence_reset)

	# Init collected counts
	for name in required_ingredients.keys():
		collected_counts[name] = 0

	# Build checklist UI with required counts
	var req_counts: Dictionary = {}
	for name in required_ingredients.keys():
		req_counts[name] = int(required_ingredients[name]["count"])
	checklist_ui.setup_checklist(req_counts)
	checklist_ui.show()

	# Start spawn timer randomized
	spawn_timer = randf_range(0.25, spawn_interval)

func _process(delta: float) -> void:
	if game_over:
		return

	# Periodic spawns
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_needed()
		spawn_timer = spawn_interval

	# Win condition
	if _all_ingredients_collected():
		_on_game_over()

# --------------------------------
# Spawning
# --------------------------------
func _try_spawn_needed() -> void:
	if ingredient_container.get_child_count() >= max_active_ingredients:
		return

	var name: String = _pick_needed_ingredient_name()
	if name == "":
		return

	spawn_ingredient(name)

func _pick_needed_ingredient_name() -> String:
	var needed: Array[String] = []
	for name in required_ingredients.keys():
		var required: int = int(required_ingredients[name]["count"])
		if collected_counts[name] < required:
			needed.append(name)
	if needed.is_empty():
		return ""
	return needed[randi() % needed.size()]

@export var spawn_min_x := -500.0
@export var spawn_max_x := 50.0
@export var spawn_start_y := -100.0  # above the screen

func spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	ingredient_container.add_child(ing_node)

	var ing = ing_node as Ingredient
	if ing == null:
		push_error("Ingredients.tscn root does NOT have Ingredient.gd attached (class Ingredient).")
		ing_node.queue_free()
		return

	var combo: Array = required_ingredients[ingredient_name]["combo"]
	ing.set_combo_and_name(combo, ingredient_name)

	# Spawn within defined X range and start Y above screen
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)

# --------------------------------
# Input matching
# --------------------------------
func _on_sequence_submitted(sequence: Array) -> void:
	var matched := false

	for ing_node in ingredient_container.get_children():
		var ing = ing_node as Ingredient
		if ing == null:
			continue

		# Match the sequence to the ingredient instance
		if sequence == ing.combo:
			matched = true

			var name: String = ing.ingredient_name
			var required := int(required_ingredients[name]["count"])
			# Only increment if we haven’t already reached the required amount
			if collected_counts[name] < required:
				collected_counts[name] += 1
				checklist_ui.update_progress(name, collected_counts[name])

			# Remove this ingredient instance
			ing.queue_free()
			break  # Stop after first match

	if not matched:
		print("❌ Wrong combo!")

	# Clear input buffer
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()

func _on_sequence_reset() -> void:
	print("Input reset!")

# --------------------------------
# Win condition
# --------------------------------
func _all_ingredients_collected() -> bool:
	for name in required_ingredients.keys():
		var required: int = int(required_ingredients[name]["count"])
		if collected_counts[name] < required:
			return false
	return true

func _on_game_over() -> void:
	game_over = true
	print("🎉 All required ingredients collected! Demo Over.")
	get_tree().change_scene_to_file("res://Scenes/temp_demo_screen.tscn")
