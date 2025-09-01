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
@onready var pest_manager: Node = $PestManager
# Pests
@onready var pest_scene: PackedScene = preload("res://Scenes/mosquito.tscn")

# -----------------------
# Exports / Tunables
# -----------------------
# general
@export var max_hearts: int = 3

# spawning
@export var spawn_interval: float = 1.2
@export var max_active_ingredients: int = 100
@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float = 80.0
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

var last_fail_reason: String = ""

# Save state when a level ends (persist across level load)
var saved_hearts: int = max_hearts
var saved_combo: int = 0

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
	add_to_group("Game")
	
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

	# ensure overlay hidden initially
	win_overlay.visible = false
	dish_completed = false
	game_paused = false

	# start the level (initial saved state)
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
	last_fail_reason = reason  
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
func _load_level(saved_hearts: int = max_hearts, saved_combo: int = 0) -> void:
	# Restore saved state (carry over hearts & combo from previous level)
	current_hearts = clamp(saved_hearts, 0, max_hearts)
	combo = saved_combo
	if combo > highest_combo:
		highest_combo = combo

	# Clear any old ingredient nodes
	for child in ingredient_container.get_children():
		child.queue_free()

	# Reset per-level dictionaries & UI state (do not reset highest_combo)
	required_ingredients.clear()
	collected_counts.clear()
	dish_completed = false
	game_paused = false
	_update_combo_ui()
	_update_hearts_ui()

	# Reset spawn timers
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)

	# Clear player input buffer for safety
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

	# Load level metadata
	var dish: Dictionary = LevelManager.get_current_dish()
	$DishTitle.text = " " + str(dish.get("name","Unknown Dish"))
	time_left = int(dish.get("time_limit", 60))
	$TimerLabel.text = str(time_left)
	$TimerLabel/LevelTimer.stop()
	if time_left > 0:
		$TimerLabel/LevelTimer.start()

	# Build required_ingredients and initialize collected_counts
	var level_data: Dictionary = LevelManager.get_current_requirements()
	for name in level_data.keys():
		var data: Dictionary = level_data[name]
		var combo_copy: Array = []
		if data.has("combo") and data["combo"] is Array:
			combo_copy = data["combo"].duplicate(true)
		required_ingredients[name] = {"combo": combo_copy, "count": int(data.get("amount", 0))}
		collected_counts[name] = 0

	level_has_requirements = required_ingredients.size() > 0

	# Setup checklist UI if available
	var req_counts: Dictionary = {}
	for name in required_ingredients.keys():
		req_counts[name] = int(required_ingredients[name]["count"])
	if checklist_ui and checklist_ui.has_method("setup_checklist"):
		checklist_ui.setup_checklist(req_counts)
		checklist_ui.show()

# -----------------------
# Main process
# -----------------------
func _process(delta: float) -> void:
	# if the game is paused (e.g. during dish UI), don't run game logic
	if game_paused:
		return

	# Ingredient spawn timer
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_needed()
		spawn_timer = spawn_interval

	# Check for dish completion
	if not dish_completed and _all_ingredients_collected():
		_on_dish_completed()

# -----------------------
# Spawning helpers
# -----------------------
func _try_spawn_needed() -> void:
	if dish_completed:
		return  # stop once dish is done

	if ingredient_container.get_child_count() >= max_active_ingredients:
		return

	var name: String = _pick_weighted_ingredient_name()
	if name == "":
		return

	spawn_ingredient(name)


func _pick_weighted_ingredient_name() -> String:
	if required_ingredients.size() == 0:
		return ""

	var pool: Array = []
	for name in required_ingredients.keys():
		var required_count = int(required_ingredients[name]["count"])
		var collected_count = collected_counts.get(name, 0)

		if collected_count < required_count:
			# uncollected: weight heavier
			pool.append_array([name, name, name])
		else:
			# already complete: still allow, but less often
			pool.append(name)

	# safety
	if pool.is_empty():
		# if everything is completed, spawning should stop via _try_spawn_needed()
		return ""

	return pool[randi() % pool.size()]

# ---------------------
# spawn_ingredient (replace existing)
# ---------------------
func spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	ingredient_container.add_child(ing_node)

	var ing = ing_node as Ingredient
	if ing == null:
		push_error("Ingredients.tscn root missing Ingredient.gd!")
		ing_node.queue_free()
		return

	# duplicate combo data from level data (defensive)
	var combo_arr: Array = []
	if required_ingredients.has(ingredient_name) and required_ingredients[ingredient_name].has("combo"):
		combo_arr = required_ingredients[ingredient_name]["combo"].duplicate(true)
	ing.set_combo_and_name(combo_arr, ingredient_name)

	# connect chop_completed (ingredient emits the ingredient name string)
	# Use a guard so we don't double-connect
	if not ing.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
		ing.connect("chop_completed", Callable(self, "_on_ingredient_chopped"))

	# place and return
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)
	
# Called by PestManager via call_group when a pest times out / succeeds at attacking.
func _on_pest_failed(reason: String) -> void:
	last_fail_reason = reason
	_lose_heart(reason)

# Optional: if you want an immediate reason when a pest "attacks" (distinct from failed)
func _on_pest_attacked(pest_node: Node) -> void:
	last_fail_reason = "A pest attacked you!"
	_lose_heart(last_fail_reason)

# Called when an ingredient finishes its chop animation
func _on_ingredient_chopped(ingredient_name: String) -> void:
	# Check if this ingredient is part of the requirements
	if not required_ingredients.has(ingredient_name):
		return

	# Get required and current counts
	var req_count: int = int(required_ingredients[ingredient_name]["count"])
	var cur_count: int = collected_counts.get(ingredient_name, 0)

	# Don’t allow duplicates after requirement is met
	if cur_count >= req_count:
		return

	# Update collected count
	collected_counts[ingredient_name] = cur_count + 1

	# Update checklist UI
	if checklist_ui and checklist_ui.has_method("update_progress"):
		checklist_ui.update_progress(ingredient_name, collected_counts[ingredient_name])

	# If all ingredients complete, mark dish as done
	if _all_ingredients_collected():
		_on_dish_completed()

func _on_sequence_submitted(sequence: Array) -> void:
	# IGNORE input while the dish-complete overlay is active
	if dish_completed:
		print("DEBUG: Ignored sequence because dish UI is active:", sequence)
		return

	# copy so we don't accidentally mutate original buffer
	var clean_sequence := sequence.duplicate()

	# --- 1) Let PestManager handle it first ---
	if has_node("PestManager"):
		var pm = $PestManager
		if pm and pm.check_sequence(clean_sequence):
			# Pest handled → clear buffer and return
			if "input_buffer" in player_input:
				player_input.input_buffer.clear()
				if player_input.has_method("_update_display"):
					player_input._update_display()
			return

	# --- 2) If no level ingredient requirements ---
	if not level_has_requirements:
		if "input_buffer" in player_input:
			player_input.input_buffer.clear()
		return

	print("DEBUG: submitted sequence:", sequence)

	# --- 3) Ingredient matching ---
	var matched: bool = false

	for ing_node in ingredient_container.get_children():
		if not is_instance_valid(ing_node):
			continue
		var ing = ing_node as Ingredient
		if ing == null:
			continue

		# skip already chopped ingredients
		if ing.is_chopped:
			continue

		var name: String = ing.ingredient_name

		# skip if ingredient not required
		if not required_ingredients.has(name):
			continue

		# skip if already collected enough of this ingredient
		var req_count: int = int(required_ingredients[name]["count"])
		var cur_count: int = collected_counts.get(name, 0)
		if cur_count >= req_count:
			continue

		# quick length check
		if clean_sequence.size() != ing.combo.size():
			continue

		# element-by-element compare
		var equal := true
		for i in range(clean_sequence.size()):
			if str(clean_sequence[i]) != str(ing.combo[i]):
				equal = false
				break

		if equal:
			matched = true

			# Play slash sequence on the ingredient (Ingredient handles order & completion)
			ing.play_slash_sequence(clean_sequence)

			# ensure connection so main gets notified when the chop finishes
			if not ing.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
				ing.connect("chop_completed", Callable(self, "_on_ingredient_chopped"))

			# Immediately increase combo (keep original behavior)
			_increase_combo()

			# stop after the first matched ingredient
			break

	# --- 4) Wrong combo handling ---
	if not matched:
		_lose_heart("Wrong combo!")

	# --- 5) Always clear player's input buffer ---
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
	for name in required_ingredients.keys():
		if collected_counts.get(name, 0) < int(required_ingredients[name]["count"]):
			return false
	return true

func _on_dish_completed() -> void:
	# mark completed and pause gameplay immediately
	dish_completed = true
	game_paused = true

	# Save hearts & combo for next level
	saved_hearts = clamp(current_hearts, 0, max_hearts)
	saved_combo = combo

	# Show dish UI
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var dish_texture: Texture2D = dish_info.get("texture")
	var dish_name: String = dish_info.get("name")
	if dish_ui and dish_ui.has_method("show_dish"):
		dish_ui.show_dish(dish_texture, dish_name)

	# Show overlay visuals
	win_overlay.visible = true
	if $WinOverlay/DishCompleteUI/Star/AnimationPlayer:
		$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")

	# play sfx if available
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx == null:
		sfx = get_node_or_null("/root/MusicManager")
	if sfx != null and sfx.has_method("play_sfx"):
		sfx.play_sfx("level_up")

	# wait briefly, then automatically continue to next level
	await get_tree().create_timer(2.0).timeout

	# hide overlay before transition
	if win_overlay.visible:
		win_overlay.visible = false

	# Unpause local flags (we will immediately load next level)
	game_paused = false
	dish_completed = false

	# ensure any leftover input buffer is cleared so stray events don't apply on new level
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

	# Advance to next level and load it, passing saved state
	LevelManager.next_level()
	_load_level(saved_hearts, saved_combo)
		
func _on_continue_pressed() -> void:
	if win_overlay.visible:
		win_overlay.visible = false

	game_paused = false
	waiting_for_continue = false
	dish_completed = false

	# Save current hearts/combo BEFORE loading next level
	saved_hearts = current_hearts
	saved_combo = combo

	LevelManager.next_level()
	_load_level(saved_hearts, saved_combo)

# -----------------------
# Game Over / Score saving
# -----------------------
func _calculate_score() -> int:
	var level_number: int = LevelManager.current_level + 1
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var level_time_limit: int = int(dish_info.get("time_limit", 0))
	var time_taken: int = clamp(level_time_limit - int(time_left), 0, level_time_limit)
	var score: int = int(level_number * highest_combo * 10) - int(time_taken)
	print("DEBUG: _game_over() - saving score. current_hearts:", current_hearts, "combo:", combo, "highest_combo:", highest_combo, "Level:", LevelManager.current_level)
	return max(0, score)

func _game_over() -> void:
	# Get level number
	var level_number: int = LevelManager.current_level + 1

	# Calculate time taken
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var level_time_limit: int = int(dish_info.get("time_limit", 0))
	var time_taken: int = clamp(level_time_limit - int(time_left), 0, level_time_limit)

	# Print debug info
	print("DEBUG: Level:", level_number)
	print("DEBUG: Time taken:", time_taken)
	print("DEBUG: Highest combo:", highest_combo)

	# Calculate score
	var score: int = int(level_number * highest_combo * 10) - int(time_taken)
	score = max(0, score)
	print("DEBUG: Score calculated:", score)
	_save_score(score, last_fail_reason)
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func _save_score(score: int, reason: String) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("user://scores.cfg") # ignore missing file

	cfg.set_value("scores", "last_score", score)
	cfg.set_value("scores", "last_fail_reason", reason)

	# handle highscore
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
		last_fail_reason = "You ran out of time."
		_game_over()
