extends Node2D

# -----------------------
# Nodes / Scenes
# -----------------------
@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var player_input: Node = $PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $Checklist
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI   # expects `show_dish(texture, name)`
@onready var win_overlay: CanvasLayer = $WinOverlay

# Pests
@onready var pest_scene: PackedScene = preload("res://Scenes/mosquito.tscn")
@onready var pest_container: Node2D = $PestContainer

# -----------------------
# Exports / Tunables
# -----------------------
# general
@export var max_hearts: int = 3

# spawning
@export var spawn_interval: float = 1.25
@export var max_active_ingredients: int = 6
@export var spawn_min_x: float = -500.0
@export var spawn_max_x: float = 50.0
@export var spawn_start_y: float = -100.0

# pest timing
@export var pest_spawn_min: float = 3.0
@export var pest_spawn_max: float = 8.0
@export var pest_spawn_repeat_min: float = 4.0
@export var pest_spawn_repeat_max: float = 12.0
@export var max_active_pests: int = 3

# -----------------------
# State
# -----------------------
var current_hearts: int = max_hearts
@onready var hearts_ui: HBoxContainer = $HeartsContainer

var combo: int = 0
var highest_combo: int = 0
@onready var combo_label: Label = $ComboLabel

var required_ingredients: Dictionary = {}   # filled per-level by _load_level()
var collected_counts: Dictionary = {}

var spawn_timer: float = 0.0
var pest_next_spawn: float = 0.0

var game_paused: bool = false
var waiting_for_continue: bool = false   # becomes true after the dish UI delay
var dish_completed: bool = false

var time_left: int = 0
var level_has_requirements: bool = false

# -----------------------
# Utility comparison function (robust element-by-element)
# -----------------------
func arrays_equal(a: Array, b: Array) -> bool:
	if a == null or b == null:
		return false
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if str(a[i]) != str(b[i]):
			return false
	return true

# -----------------------
# READY
# -----------------------
func _ready() -> void:
	
	# BGM 
	var title_music = preload("res://Audio/bgm.ogg")
	MusicManager.play_bgm(title_music, true)
	# connect player input signals
	
	if player_input == null:
		push_error("PlayerInput node not found!")
		return
	if not player_input.has_signal("sequence_submitted"):
		push_error("PlayerInput missing 'sequence_submitted' signal.")
		return
	player_input.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
	if player_input.has_signal("sequence_reset"):
		player_input.sequence_reset.connect(Callable(self, "_on_sequence_reset"))

	# connect dish overlay continue if it exists (Godot 4 style)
	if dish_ui != null and dish_ui.has_signal("continue_pressed"):
		var continue_callable := Callable(self, "_on_continue_pressed")
		if not dish_ui.is_connected("continue_pressed", continue_callable):
			dish_ui.connect("continue_pressed", continue_callable)

	# ensure overlay hidden initially
	win_overlay.visible = false
	waiting_for_continue = false
	dish_completed = false
	game_paused = false

	# start the level
	_load_level()
	_update_hearts_ui()
	_update_combo_ui()

	# timers randomize
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)

# -----------------------
# Hearts / combo UI helpers
# -----------------------
func _update_hearts_ui() -> void:
	for i in range(max_hearts):
		if i < hearts_ui.get_child_count():
			var heart: TextureRect = hearts_ui.get_child(i)
			heart.visible = i < current_hearts

func _lose_heart(reason: String) -> void:
	current_hearts -= 1
	_reset_combo()
	_update_hearts_ui()
	print("💔 %s Hearts remaining: %d" % [reason, current_hearts])
	if current_hearts <= 0:
		_game_over()

func _increase_combo() -> void:
	combo += 1
	if combo > highest_combo:
		highest_combo = combo
	_update_combo_ui()

func _reset_combo() -> void:
	combo = 0
	_update_combo_ui()

func _update_combo_ui() -> void:
	if combo > 0:
		combo_label.text = "%dx Combo!" % combo
	else:
		combo_label.text = ""

# -----------------------
# Load / start level (make behavior similar to old working script)
# -----------------------
func _load_level() -> void:
	print("Loading level:", LevelManager.current_level)
	print("Level requirements (raw):", LevelManager.get_current_requirements())

	# 1) Clear any old ingredient nodes and make sure they free
	for child in ingredient_container.get_children():
		child.queue_free()
	# ensure queued frees processed so old instances cannot be matched
	await get_tree().process_frame

	# 2) Reset per-level dictionaries & UI state
	required_ingredients.clear()
	collected_counts.clear()
	combo = 0
	highest_combo = 0
	dish_completed = false
	waiting_for_continue = false
	game_paused = false
	_update_combo_ui()
	_update_hearts_ui()

	# 3) Reset spawn timers
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)

	# 4) Clear player input buffer for safety
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

	# 5) Load level metadata
	var dish: Dictionary = LevelManager.get_current_dish()
	$DishTitle.text = " " + str(dish.get("name","Unknown Dish"))
	time_left = int(dish.get("time_limit", 60))
	$TimerLabel.text = str(time_left)
	$TimerLabel/LevelTimer.stop()
	if time_left > 0:
		$TimerLabel/LevelTimer.start()

	# 6) Build required_ingredients (duplicate combos defensively) and zero collected_counts
	var level_data: Dictionary = LevelManager.get_current_requirements()
	for name in level_data.keys():
		var data: Dictionary = level_data[name]
		var combo_copy: Array = []
		if data.has("combo") and data["combo"] is Array:
			combo_copy = data["combo"].duplicate(true)
		required_ingredients[name] = {"combo": combo_copy, "count": int(data.get("amount", 0))}
		collected_counts[name] = 0

	level_has_requirements = required_ingredients.size() > 0

	# 7) Setup checklist UI
	var req_counts: Dictionary = {}
	for name in required_ingredients.keys():
		req_counts[name] = int(required_ingredients[name]["count"])
	if checklist_ui and checklist_ui.has_method("setup_checklist"):
		checklist_ui.setup_checklist(req_counts)
		checklist_ui.show()

	print("Collected counts after reset:", collected_counts)
	print("Required ingredients for level:", required_ingredients)

# -----------------------
# Main process
# -----------------------
func _process(delta: float) -> void:
	# while waiting for continue, only allow the continue action
	if game_paused and waiting_for_continue:
		if win_overlay.visible and Input.is_action_just_pressed("ui_accept"):
			_on_continue_pressed()
		return
	if game_paused:
		return

	# Ingredient spawn timer
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_needed()
		spawn_timer = spawn_interval

	# Pest spawn timer (persistent across levels)
	if pest_container and pest_container.get_child_count() < max_active_pests:
		pest_next_spawn -= delta
		if pest_next_spawn <= 0.0:
			_spawn_random_pest()
			pest_next_spawn = randf_range(pest_spawn_repeat_min, pest_spawn_repeat_max)

	# Check for dish completion
	if not dish_completed and _all_ingredients_collected():
		_on_dish_completed()

# -----------------------
# Spawning helpers
# -----------------------
func _try_spawn_needed() -> void:
	if ingredient_container.get_child_count() >= max_active_ingredients:
		return
	var name: String = _pick_needed_ingredient_name()
	if name == "":
		return
	spawn_ingredient(name)

func _pick_needed_ingredient_name() -> String:
	var needed: Array = []
	for name in required_ingredients.keys():
		var required_count = int(required_ingredients[name]["count"])
		var collected_count = collected_counts.get(name, 0)
		if collected_count < required_count:
			needed.append(name)
	if needed.size() == 0:
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

	var combo_arr: Array = []
	if required_ingredients.has(ingredient_name) and required_ingredients[ingredient_name].has("combo"):
		combo_arr = required_ingredients[ingredient_name]["combo"].duplicate(true)
	ing.set_combo_and_name(combo_arr, ingredient_name)

	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)

# -----------------------
# Pest spawn / handlers
# -----------------------
func _spawn_random_pest() -> void:
	var p := pest_scene.instantiate()
	pest_container.add_child(p)

	# spawn off top
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	var spawn_y = -50.0
	p.position = Vector2(spawn_x, spawn_y)

	# set combo & target (if pest supports it)
	if p.has_method("set_combo_and_target"):
		var mosq_combo := ["→","Z"]  # example
		var pot_node = get_node_or_null("Pot")  # adjust to your pot node path
		var pot_pos = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y*0.5)
		if pot_node != null:
			pot_pos = pot_node.global_position
		p.set_combo_and_target(mosq_combo, pot_pos)

	# connect signals and bind the pest node as an argument for the callbacks
	if p.has_signal("defeated"):
		p.defeated.connect(Callable(self, "_on_pest_defeated").bind(p))
	if p.has_signal("attacked"):
		p.attacked.connect(Callable(self, "_on_pest_attacked").bind(p))

func _on_pest_defeated(pest_node: Node) -> void:
	if is_instance_valid(pest_node):
		_increase_combo()
		pest_node.queue_free()

func _on_pest_attacked(pest_node: Node) -> void:
	if is_instance_valid(pest_node):
		pest_node.queue_free()
		_lose_heart("A pest attacked you!")

# -----------------------
# Input matching (keeps old reliable behavior)
# -----------------------
func _on_sequence_submitted(sequence: Array) -> void:
	# Guard: ignore gameplay input while overlays/pauses/continue states are active
	if (win_overlay != null and win_overlay.visible) or waiting_for_continue or dish_completed or game_paused:
		# clear buffer for safety
		if "input_buffer" in player_input:
			player_input.input_buffer.clear()
			if player_input.has_method("_update_display"):
				player_input._update_display()
		return

	# If no level requirements, just clear buffer and return
	if not level_has_requirements:
		if "input_buffer" in player_input:
			player_input.input_buffer.clear()
		return

	# Debug: show sequence received
	print("DEBUG: submitted sequence:", sequence)

	# 0) Check pests first (so swatting pests doesn't count as wrong combo)
	if pest_container:
		for pest_node in pest_container.get_children():
			if not is_instance_valid(pest_node):
				continue
			var pest_combo_raw: Array = []
			if pest_node.has_method("get_combo"):
				pest_combo_raw = pest_node.get_combo()
			elif "combo" in pest_node:
				pest_combo_raw = pest_node.combo
			else:
				continue

			# compare using arrays_equal
			if arrays_equal(sequence, pest_combo_raw):
				# defeat pest
				if pest_node.has_method("defeat"):
					pest_node.defeat()
				else:
					pest_node.queue_free()
				# clear input buffer and update display
				if "input_buffer" in player_input:
					player_input.input_buffer.clear()
					if player_input.has_method("_update_display"):
						player_input._update_display()
				return

	# 1) Check ingredients (old logic elementwise comparison)
	var matched: bool = false

	for ing_node in ingredient_container.get_children():
		if not is_instance_valid(ing_node):
			continue
		var ing = ing_node as Ingredient
		if ing == null:
			continue

		# skip if ingredient not required
		var name: String = ing.ingredient_name
		if not required_ingredients.has(name):
			continue

		# skip if already collected enough of this ingredient
		var req_count: int = int(required_ingredients[name]["count"])
		var cur_count: int = collected_counts.get(name, 0)
		if cur_count >= req_count:
			continue

		# quick length check
		if sequence.size() != ing.combo.size():
			continue

		# element-by-element compare robustly
		var equal := true
		for i in range(sequence.size()):
			if str(sequence[i]) != str(ing.combo[i]):
				equal = false
				break

		if equal:
			matched = true
			# increment counters & UI
			collected_counts[name] = cur_count + 1
			_increase_combo()
			if checklist_ui and checklist_ui.has_method("update_progress"):
				checklist_ui.update_progress(name, collected_counts[name])

			# remove the ingredient instance immediately
			ing.queue_free()
			break  # stop after matching one ingredient

	# 2) Wrong combo handling
	if not matched:
		_lose_heart("Wrong combo!")

	# Clear player's input buffer and refresh display
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

func _on_sequence_reset() -> void:
	print("Input reset!")
	_reset_combo()

# -----------------------
# Win / Dish celebration
# -----------------------
func _all_ingredients_collected() -> bool:
	if not level_has_requirements:
		return false
	for name in required_ingredients.keys():
		if collected_counts[name] < int(required_ingredients[name]["count"]):
			return false
	return true

func _on_dish_completed() -> void:
	dish_completed = true
	game_paused = true
	waiting_for_continue = false   # disabled until delay finishes
	print("🎉 Dish complete! Showing UI...")

	var dish_info: Dictionary = LevelManager.get_current_dish()
	var dish_texture: Texture2D = dish_info.get("texture")
	var dish_name: String = dish_info.get("name")

	if dish_ui and dish_ui.has_method("show_dish"):
		dish_ui.show_dish(dish_texture, dish_name)

	win_overlay.visible = true
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")

	# Play SFX if autoload exists
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx == null:
		sfx = get_node_or_null("/root/MusicManager") # try your project name
	if sfx != null and sfx.has_method("play_sfx"):
		sfx.play_sfx("level_up")

	# Small delay before allowing continue (non-blocking)
	await get_tree().create_timer(1.5).timeout
	# Only enable continue if we're still in the same completed state and overlay visible
	if dish_completed and win_overlay.visible:
		waiting_for_continue = true

func _on_continue_pressed() -> void:
	# Hide overlay and reset flags
	if win_overlay.visible:
		win_overlay.visible = false

	game_paused = false
	waiting_for_continue = false
	dish_completed = false

	# Advance to next level and load it
	LevelManager.next_level()
	_load_level()

# -----------------------
# Game Over / Score saving
# -----------------------
func _game_over() -> void:
	# compute score: (level_number * highest_combo * 10) - time_taken
	var level_number: int = LevelManager.current_level + 1
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var level_time_limit: int = int(dish_info.get("time_limit", 0))
	var time_taken: int = clamp(level_time_limit - int(time_left), 0, level_time_limit)

	var score: int = int(level_number * highest_combo * 10) - int(time_taken)
	score = max(0, score)
	_save_score(score)

	# change to game over scene
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func _save_score(score: int) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("user://scores.cfg") # ignore error if missing
	cfg.set_value("scores", "last_score", score)
	var prev_high: int = int(cfg.get_value("scores", "high_score", 0))
	if score > prev_high:
		cfg.set_value("scores", "high_score", score)
	var err: int = cfg.save("user://scores.cfg")
	if err != OK:
		push_error("Failed to save scores.cfg: %s" % str(err))

# -----------------------
# Timer callback
# -----------------------
func _on_level_timer_timeout() -> void:
	time_left -= 1
	if has_node("TimerLabel"):
		$TimerLabel.text = str(time_left)
	if time_left <= 0:
		_game_over()
