extends Node2D

# Scenes
@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var player_input: Node = $PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $Checklist
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI   # DishCompleteUI script must have `show_dish(tex)`
@onready var win_overlay: CanvasLayer = $WinOverlay

# Hearts
@export var max_hearts := 3
var current_hearts := max_hearts
@onready var hearts_ui: HBoxContainer = $HeartsContainer

# Combo
var combo := 0
@onready var combo_label: Label = $ComboLabel

# Dynamic required ingredients per level
var required_ingredients: Dictionary = {}
var collected_counts: Dictionary = {}   

# Spawn settings
@export var spawn_interval: float = 1.25
@export var max_active_ingredients: int = 6
@export var spawn_min_x: float = -500.0
@export var spawn_max_x: float = 50.0
@export var spawn_start_y: float = -100.0

var spawn_timer: float = 0.0
var game_paused: bool = false
var waiting_for_continue: bool = false   # <-- NEW FLAG

# Game Timer
var time_left: int


# --------------------------------
# READY
# --------------------------------
func _ready() -> void:	
	# Stretch HTML5 canvas if needed (HTML5 export hack)
	if Engine.has_singleton("JavaScript"):
		var js = Engine.get_singleton("JavaScript")
		js.eval("window.addEventListener('resize', () => {let c=document.getElementById('canvas'); if(c){c.style.width='100%'; c.style.height='100%';}});")

	# Connect PlayerInput signals
	if player_input == null:
		push_error("PlayerInput node not found!")
		return
	if not player_input.has_signal("sequence_submitted"):
		push_error("PlayerInput missing 'sequence_submitted' signal!")
		return
	player_input.sequence_submitted.connect(_on_sequence_submitted)
	if player_input.has_signal("sequence_reset"):
		player_input.sequence_reset.connect(_on_sequence_reset)

	# Hide overlay at start
	win_overlay.visible = false
	waiting_for_continue = false

	_load_level()

	# Initialize UI
	_update_hearts_ui()
	_update_combo_ui()

	# Start spawn timer randomized
	spawn_timer = randf_range(0.25, spawn_interval)


# --------------------------------
# HEARTS
# --------------------------------
func _update_hearts_ui() -> void:
	for i in range(max_hearts):
		var heart: TextureRect = hearts_ui.get_child(i)
		heart.visible = i < current_hearts

func _lose_heart(reason: String) -> void:
	current_hearts -= 1
	_reset_combo()
	_update_hearts_ui()
	print("💔 %s Hearts remaining: %d" % [reason, current_hearts])
	if current_hearts <= 0:
		game_over()
		print("GAME OVER – Out of hearts!") # placeholder


# --------------------------------
# COMBO
# --------------------------------
func _increase_combo() -> void:
	combo += 1
	_update_combo_ui()

func _reset_combo() -> void:
	combo = 0
	_update_combo_ui()

func _update_combo_ui() -> void: 
	if combo > 0: 
		combo_label.text = "%dx Combo!" % combo 
	else: combo_label.text = ""

# --------------------------------
# LOAD LEVEL
# --------------------------------

func _load_level() -> void:
	var dish = LevelManager.get_current_dish()
	
	# Timer
	time_left = dish["time_limit"]

	$TimerLabel.text = str(time_left)
	$TimerLabel/LevelTimer.start()
	
	$DishTitle.text = " " + dish["name"]
	
	var level_data: Dictionary = LevelManager.get_current_requirements()

	required_ingredients.clear()
	collected_counts.clear()
	for name in level_data.keys():
		required_ingredients[name] = {
			"combo": level_data[name]["combo"],
			"count": level_data[name]["amount"]
		}
		collected_counts[name] = 0

	# Build checklist
	var req_counts := {}
	for name in required_ingredients.keys():
		req_counts[name] = required_ingredients[name]["count"]

	checklist_ui.setup_checklist(req_counts)
	checklist_ui.show()


# --------------------------------
# PROCESS
# --------------------------------
func _process(delta: float) -> void:
	if game_paused and waiting_for_continue:
		# only allow input when dish overlay is actually active
		if Input.is_anything_pressed():
			_on_continue_pressed()
		return

	if game_paused:
		return

	# Normal gameplay
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_needed()
		spawn_timer = spawn_interval

	if _all_ingredients_collected():
		_on_dish_completed()


# --------------------------------
# SPAWNING
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
		if collected_counts[name] < int(required_ingredients[name]["count"]):
			needed.append(name)
	if needed.is_empty():
		return ""
	return needed[randi() % needed.size()]

func spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	ingredient_container.add_child(ing_node)

	var ing = ing_node as Ingredient
	if ing == null:
		push_error("Ingredients.tscn root missing Ingredient.gd!")
		ing_node.queue_free()
		return

	var combo: Array = required_ingredients[ingredient_name]["combo"]
	ing.set_combo_and_name(combo, ingredient_name)

	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)


# --------------------------------
# PLAYER INPUT MATCHING
# --------------------------------
func _on_sequence_submitted(sequence: Array) -> void:
	var matched := false
	for ing_node in ingredient_container.get_children():
		var ing = ing_node as Ingredient
		if ing == null:
			continue
		if sequence == ing.combo:
			matched = true
			var name: String = ing.ingredient_name
			var required := int(required_ingredients[name]["count"])
			if collected_counts[name] < required:
				collected_counts[name] += 1
				checklist_ui.update_progress(name, collected_counts[name])
				_increase_combo()
			else:
				_lose_heart("Already collected all of %s!" % name)
			ing.queue_free()
			break
	if not matched:
		_lose_heart("Wrong combo!")

	if "input_buffer" in player_input:
		player_input.input_buffer.clear()

func _on_sequence_reset() -> void:
	print("Input reset!")
	_reset_combo()


# --------------------------------
# WIN CONDITION → Dish Celebration
# --------------------------------
func _all_ingredients_collected() -> bool:
	for name in required_ingredients.keys():
		if collected_counts[name] < int(required_ingredients[name]["count"]):
			return false
	return true

func _on_dish_completed() -> void:
	game_paused = true
	waiting_for_continue = true
	print("🎉 Dish complete! Showing UI...")
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")
	
	var dish_info = LevelManager.get_current_dish()
	var dish_texture: Texture2D = dish_info["texture"]
	var dish_name: String = dish_info["name"]
	
	# Show dish with scaling
	dish_ui.show_dish(dish_texture, dish_name)
	win_overlay.visible = true
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")
	
func _on_continue_pressed() -> void:
	print("Loading next level")
	game_paused = false
	waiting_for_continue = false
	LevelManager.next_level()
	_load_level()

func game_over() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
	

func _on_level_timer_timeout() -> void:
	time_left -= 1
	$TimerLabel.text = str(time_left)

	if time_left <= 0:
		game_over()
