extends Node2D

# Scenes / nodes
@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var player_input: Node = $PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $Checklist
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI   # expects `show_dish(texture, name)`
@onready var win_overlay: CanvasLayer = $WinOverlay

# --- Pest system ---
@onready var pest_scene: PackedScene = preload("res://Scenes/mosquito.tscn")
@onready var pest_container: Node2D = $PestContainer

# Pest spawn timing (seconds)
var pest_next_spawn: float = 0.0
@export var pest_spawn_min: float = 8.0    # earliest spawn after level starts
@export var pest_spawn_max: float = 18.0   # latest spawn for first pest
@export var pest_spawn_repeat_min: float = 15.0  # subsequent spawn min
@export var pest_spawn_repeat_max: float = 30.0  # subsequent spawn max

# Limit active pests (optional)
@export var max_active_pests: int = 3
# Hearts
@export var max_hearts: int = 3
var current_hearts: int = max_hearts
@onready var hearts_ui: HBoxContainer = $HeartsContainer

# Combo
var combo: int = 0
var highest_combo: int = 0
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
var waiting_for_continue: bool = false   # true only when player can press continue
var dish_completed: bool = false         # guard so _on_dish_completed fires once

# Game Timer
var time_left: int = 0
var level_has_requirements: bool = false

# ----------------------------------------------------------------
func _ready() -> void:
	# Optional HTML5 canvas stretch helper (keeps behavior from your original)
	if Engine.has_singleton("JavaScript"):
		var js = Engine.get_singleton("JavaScript")
		js.eval("window.addEventListener('resize', () => {let c=document.getElementById('canvas'); if(c){c.style.width='100%'; c.style.height='100%';}});")

	# PlayerInput signals
	if player_input == null:
		push_error("PlayerInput node not found!")
		return
	if not player_input.has_signal("sequence_submitted"):
		push_error("PlayerInput missing 'sequence_submitted' signal.")
		return
	player_input.sequence_submitted.connect(_on_sequence_submitted)
	if player_input.has_signal("sequence_reset"):
		player_input.sequence_reset.connect(_on_sequence_reset)

	# Connect dish overlay continue signal (if available)
	if dish_ui != null and dish_ui.has_signal("continue_pressed"):
		var continue_callable := Callable(self, "_on_continue_pressed")
		if not dish_ui.is_connected("continue_pressed", continue_callable):
			dish_ui.connect("continue_pressed", continue_callable)

	win_overlay.visible = false
	waiting_for_continue = false
	dish_completed = false

	_load_level()
	_update_hearts_ui()
	_update_combo_ui()
	spawn_timer = randf_range(0.25, spawn_interval)

# ----------------------------------------------------------------
# Hearts / lives
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

# ----------------------------------------------------------------
# Combo management
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

# ----------------------------------------------------------------
# Load / start level (fully resets state)
func _load_level() -> void:
	# Clear any old ingredients from previous level
	for child in ingredient_container.get_children():
		child.queue_free()

	# Reset core per-level state
	required_ingredients.clear()
	collected_counts.clear()
	combo = 0
	highest_combo = 0
	dish_completed = false
	waiting_for_continue = false
	game_paused = false
	_update_combo_ui()
	_update_hearts_ui()

	# Reset spawn timer
	spawn_timer = randf_range(0.25, spawn_interval)

	# Clear player input buffer (safety)
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

	# Load level metadata
	var dish: Dictionary = LevelManager.get_current_dish()
	$DishTitle.text = " " + str(dish.get("name","Unknown Dish"))
	time_left = int(dish.get("time_limit",60))
	$TimerLabel.text = str(time_left)
	$TimerLabel/LevelTimer.stop()
	if time_left > 0:
		$TimerLabel/LevelTimer.start()

	# Build required_ingredients with duplicated combos (defensive)
	var level_data: Dictionary = LevelManager.get_current_requirements()
	for name in level_data.keys():
		var data: Dictionary = level_data[name]
		var combo_copy: Array = []
		if data.has("combo") and data["combo"] is Array:
			# deep duplicate to avoid shared references
			combo_copy = data["combo"].duplicate(true)
		required_ingredients[name] = {"combo": combo_copy, "count": int(data.get("amount", 0))}
		collected_counts[name] = 0

	level_has_requirements = required_ingredients.size() > 0

	# Setup checklist UI
	var req_counts: Dictionary = {}
	for name in required_ingredients.keys():
		req_counts[name] = required_ingredients[name]["count"]
	if checklist_ui and checklist_ui.has_method("setup_checklist"):
		checklist_ui.setup_checklist(req_counts)
		checklist_ui.show()
	
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)

# ----------------------------------------------------------------
func _process(delta: float) -> void:
	# If the game is paused and we are in the continue-wait state,
	# only accept the mapped continue action (e.g. Z mapped to ui_accept).
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

	# Pest spawn timer: schedule pests independently (pests persist across levels)
	# Only spawn if we haven't hit the max active pests
	if pest_container and pest_container.get_child_count() < max_active_pests:
		# ensure pest_next_spawn has a sensible default
		if pest_next_spawn <= 0.0:
			pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)
		pest_next_spawn -= delta
		if pest_next_spawn <= 0.0:
			_spawn_random_pest()
			# schedule next spawn in the repeated range
			pest_next_spawn = randf_range(pest_spawn_repeat_min, pest_spawn_repeat_max)

	# Check for dish completion
	if not dish_completed and _all_ingredients_collected():
		_on_dish_completed()

# ----------------------------------------------------------------
# Spawning helpers
func _try_spawn_needed() -> void:
	# Respect maximum active ingredients
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
	# instantiate and add to container
	var ing_node := ingredient_scene.instantiate()
	ingredient_container.add_child(ing_node)

	var ing = ing_node as Ingredient
	if ing == null:
		push_error("Ingredients.tscn root missing Ingredient.gd!")
		ing_node.queue_free()
		return

	# Defensive: duplicate combo so ingredient keeps its own copy
	var combo_arr: Array = []
	if required_ingredients.has(ingredient_name) and required_ingredients[ingredient_name].has("combo"):
		combo_arr = required_ingredients[ingredient_name]["combo"].duplicate(true)
	ing.set_combo_and_name(combo_arr, ingredient_name)

	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)

# pest spawning
func _spawn_random_pest() -> void:
	# choose which pest type (we only have mosquito now; expand later)
	var p := pest_scene.instantiate()
	pest_container.add_child(p)

	# choose spawn x (off top or side) and y
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)  # reuse your spawn bounds
	var spawn_y = -50.0
	p.position = Vector2(spawn_x, spawn_y)

	# set the combo and target position (pot). Choose a combo for the pest:
	# e.g. mosquito requires ["→","Z"] or any sequence you like
	if p.has_method("set_combo_and_target"):
		# Set the combo and the pot target (pass position of the pot or center)
		var mosq_combo := ["→","Z"]  # example; you can change
		# find pot position (replace with your pot node path). Example:
		var pot_node = get_node_or_null("Pot")  # adjust to your actual pot node path
		var pot_pos = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y*0.5)
		if pot_node != null:
			pot_pos = pot_node.global_position
		p.set_combo_and_target(mosq_combo, pot_pos)

	# connect signals
	# connect signals (Godot 4 style)
	if p.has_signal("defeated"):
		p.defeated.connect(Callable(self, "_on_pest_defeated"))
	if p.has_signal("attacked"):
		p.attacked.connect(Callable(self, "_on_pest_attacked"))

func _on_pest_defeated(pest_node: Node) -> void:
	# player defended successfully — just ensure pest removed and maybe award points/combo
	if is_instance_valid(pest_node):
		# optionally play small effect or increase combo
		_increase_combo()
		pest_node.queue_free()

func _on_pest_attacked(pest_node: Node) -> void:
	# pest succeeded in attacking — remove it and deduct a heart
	if is_instance_valid(pest_node):
		pest_node.queue_free()
		_lose_heart("A pest attacked you!")

# ----------------------------------------------------------------
# Input matching (robust)
# helper: normalize one step to canonical token
func _normalize_step(s) -> String:
	var st := str(s)
	# arrow glyphs and common action names
	if st == "↑" or st.to_lower() == "up" or st == "ui_up" or st.to_lower() == "joystickup":
		return "UP"
	if st == "↓" or st.to_lower() == "down" or st == "ui_down" or st.to_lower() == "joystickdown":
		return "DOWN"
	if st == "←" or st.to_lower() == "left" or st == "ui_left" or st.to_lower() == "joystickleft":
		return "LEFT"
	if st == "→" or st.to_lower() == "right" or st == "ui_right" or st.to_lower() == "joystickright":
		return "RIGHT"
	# confirm / Z / start
	if st == "Z" or st == "z" or st.to_lower() == "ui_accept" or st.to_lower() == "joystickstart" or st.to_lower() == "start":
		return "Z"
	# fallback: uppercase token
	return st.to_upper()

func _normalize_array(arr: Array) -> Array:
	var out := []
	for e in arr:
		out.append(_normalize_step(e))
	return out

func _on_sequence_submitted(sequence: Array) -> void:
	# Ignore input if overlay or dish is completed or we're waiting for continue
	if win_overlay.visible or waiting_for_continue or dish_completed:
		return

	# Normalize the player sequence once
	var clean_sequence: Array = _normalize_array(sequence)

	# --- 0) Check pests first (so swatting pests doesn't count as wrong combo) ---
	if pest_container:
		for pest_node in pest_container.get_children():
			var pest = pest_node
			if pest == null:
				continue

			# obtain pest combo (support method or direct field)
			var pest_combo_raw: Array = []
			if pest.has_method("get_combo"):
				pest_combo_raw = pest.get_combo()
			elif "combo" in pest:
				pest_combo_raw = pest.combo
			else:
				continue

			var clean_pest_combo: Array = _normalize_array(pest_combo_raw)
			if clean_sequence == clean_pest_combo:
				# defeat the pest (prefer method 'defeat')
				if pest.has_method("defeat"):
					pest.defeat()
				elif pest.has_method("on_defeat"):
					pest.on_defeat()
				else:
					# fallback: free the pest and emit defeated signal if available
					if pest.has_method("emit_signal"):
						emit_signal("defeated", self)
					pest.queue_free()

				# clear input buffer and update display then stop processing
				if "input_buffer" in player_input:
					player_input.input_buffer.clear()
					if player_input.has_method("_update_display"):
						player_input._update_display()
				return

	# --- 1) If there are no level requirements, clear buffer and ignore ingredient logic ---
	if not level_has_requirements:
		if "input_buffer" in player_input:
			player_input.input_buffer.clear()
		return

	# --- 2) Check ingredients normally ---
	var matched: bool = false

	for ing_node in ingredient_container.get_children():
		var ing = ing_node as Ingredient
		if ing == null:
			continue

		# Normalize the ingredient's combo and compare
		var ing_combo_raw: Array = ing.combo
		var clean_combo: Array = _normalize_array(ing_combo_raw)

		if clean_sequence == clean_combo:
			matched = true
			var name: String = ing.ingredient_name

			# Check if ingredient is required in this level
			if required_ingredients.has(name):
				var required_count: int = int(required_ingredients[name]["count"])
				var current_count: int = collected_counts.get(name, 0)

				if current_count < required_count:
					collected_counts[name] = current_count + 1
					_increase_combo()

					# Update the checklist UI
					if checklist_ui and checklist_ui.has_method("update_progress"):
						checklist_ui.update_progress(name, collected_counts[name])
				else:
					_lose_heart("Already collected all of %s!" % name)
			else:
				_lose_heart("Ingredient %s does not exist in this level!" % name)

			# Remove the ingredient from the scene
			ing.queue_free()
			break  # stop after matching one ingredient

	# Player input was incorrect
	if not matched:
		_lose_heart("Wrong combo!")

	# Clear input buffer and refresh display
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

func _on_sequence_reset() -> void:
	print("Input reset!")
	_reset_combo()

# ----------------------------------------------------------------
# Win / Dish celebration
func _all_ingredients_collected() -> bool:
	# if level has no requirements, can't be completed
	if not level_has_requirements:
		return false
	for name in required_ingredients.keys():
		if collected_counts[name] < int(required_ingredients[name]["count"]):
			return false
	return true

func _on_dish_completed() -> void:
	dish_completed = true
	game_paused = true
	waiting_for_continue = false  # wait until delay finishes

	var dish_info: Dictionary = LevelManager.get_current_dish()
	var dish_texture: Texture2D = dish_info.get("texture")
	var dish_name: String = dish_info.get("name")

	if dish_ui and dish_ui.has_method("show_dish"):
		dish_ui.show_dish(dish_texture, dish_name)

	win_overlay.visible = true
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")

	# --- Play dish complete SFX ---
	MusicManager.play_sfx("level_up")  # or name it "dish_complete" in your SFX library

	# Small delay before allowing continue
	get_tree().create_timer(1.5).timeout.connect(func():
		waiting_for_continue = true
	)

# helper coroutine for safe continue enabling
func _start_continue_delay() -> void:
	await get_tree().create_timer(1.5).timeout
	# Only enable continue if we're still in the completed state and overlay visible
	if dish_completed and win_overlay.visible:
		waiting_for_continue = true

func _on_continue_pressed() -> void:
	# Hide overlay and reset flags
	if win_overlay.visible:
		win_overlay.visible = false

	game_paused = false
	waiting_for_continue = false
	dish_completed = false

	# Advance to next level
	LevelManager.next_level()

	# Load next level (this resets everything)
	_load_level()

# ----------------------------------------------------------------
# GAME OVER (compute, save score, change to game over scene)
func _game_over() -> void:
	# compute score: (level_number * highest_combo * 10) - time_taken
	var level_number: int = 1
	level_number = LevelManager.current_level + 1

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
	# ignore loading error if not present
	cfg.load("user://scores.cfg")

	cfg.set_value("scores", "last_score", score)
	var prev_high: int = int(cfg.get_value("scores", "high_score", 0))
	if score > prev_high:
		cfg.set_value("scores", "high_score", score)

	var err: int = cfg.save("user://scores.cfg")
	if err != OK:
		push_error("Failed to save scores.cfg: %s" % str(err))

# ----------------------------------------------------------------
# Timer callback (should be connected to LevelTimer.timeout)
func _on_level_timer_timeout() -> void:
	time_left -= 1

	if has_node("TimerLabel"):
		$TimerLabel.text = str(time_left)

	if time_left <= 0:
		_game_over()
