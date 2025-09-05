extends Node2D

# -----------------------
# Nodes / Scenes
# -----------------------
@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var text_popup_scene: PackedScene = preload("res://Scenes/text_popup.tscn")
@onready var player_input: Node = $PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $Checklist
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI   # expects `show_dish(texture, name)`
@onready var win_overlay: CanvasLayer = $WinOverlay
@onready var pest_manager: Node = $PestManager
@onready var pot_node: Sprite2D = $IngredientContainer/Pot
@onready var boss_spawn: Node2D = $BossSpawn
@onready var damage_flash: ColorRect = $DamageFlash

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
var shiba_boss: ShibaBoss = null   # <- add this

# -----------------------
# READY
# -----------------------
func _ready() -> void:
	add_to_group("Game")
	MusicManager.set_all_sfx_volume(5)
	MusicManager.set_sfx_volume_for("slash",20)
	
	# pot 
	pot_node.z_index = 10
	pot_node.z_as_relative = false
	pot_node = $IngredientContainer/Pot

	# BGM 
	var title_music = preload("res://Audio/bgm.ogg")
	MusicManager.play_bgm(title_music, true)

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
	combo = 0
	_update_combo_ui()
	_update_hearts_ui()
	MusicManager.play_sfx("wrong")

	# --- TEXT POPUP ---
	var popup_pos: Vector2
	if is_instance_valid(pot_node):
		popup_pos = pot_node.global_position + Vector2(0, -60)
	else:
		# fallback: screen center
		popup_pos = get_viewport().get_visible_rect().size * 0.5

	_spawn_text_popup(reason, popup_pos)

	# --- DAMAGE FLASH ---
	if damage_flash:
		damage_flash.visible = true
		damage_flash.color = Color(1, 0, 0, 0.6)

		var tween := create_tween()
		tween.tween_property(damage_flash, "color:a", 0.0, 0.4) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)

		tween.finished.connect(func():
			damage_flash.visible = false
		)

	print("%s Hearts remaining: %d" % [reason, current_hearts])

	if current_hearts <= 0:
		_game_over()

func _update_combo_ui() -> void:
	if combo > 0:
		combo_label.text = "%dx Combo!" % combo
	else:
		combo_label.text = ""

func _spawn_text_popup(msg: String, world_pos: Vector2) -> void:
	var popup := text_popup_scene.instantiate()
	add_child(popup)  # Put it inside your UI layer
	popup.position = Vector2(290, 290) # wherever in UI coords
	popup.show_text(msg)

# Helper: find the topmost ingredient matching `name` and flash an X on it.
func _flash_topmost_ingredient(name: String) -> void:
	# First prefer an un-chopped matching ingredient (topmost)
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		var ing = node as Ingredient
		if ing == null:
			continue
		if ing.ingredient_name != name:
			continue
		# prefer un-chopped
		if not ing.is_chopped:
			if ing.has_method("flash_x"):
				ing.flash_x()
				print("DEBUG: flashed X on topmost unchopped ", name)
			return

	# If none un-chopped, flash the topmost one anyway (fallback)
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
				print("DEBUG: flashed X on topmost (fallback) ", name)
			return

# -----------------------
# Load / start level (make behavior similar to old working script)
# -----------------------
func _load_level(saved_hearts: int = max_hearts, saved_combo: int = 0) -> void:
	# Restore saved state
	current_hearts = clamp(saved_hearts, 0, max_hearts)
	combo = saved_combo
	if combo > highest_combo:
		highest_combo = combo

	# Clear old ingredient nodes
	for child in ingredient_container.get_children():
		if child == pot_node:
			continue
		child.queue_free()

	# Clear old boss if present
	if shiba_boss and is_instance_valid(shiba_boss):
		shiba_boss.queue_free()
		shiba_boss = null

	# Reset per-level state
	required_ingredients.clear()
	collected_counts.clear()
	dish_completed = false
	game_paused = false
	_update_combo_ui()
	_update_hearts_ui()

	# Reset timers
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)

	# Clear player input buffer for safety
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

	# Load dish metadata
	var dish: Dictionary = LevelManager.get_current_dish()
	$DishTitle.text = " " + str(dish.get("name","Unknown Dish"))
	time_left = int(dish.get("time_limit", 60))
	$TimerLabel.text = str(time_left)
	$TimerLabel/LevelTimer.stop()
	if time_left > 0:
		$TimerLabel/LevelTimer.start()

	# ----- Boss level? -----
	if dish.get("is_boss", false):
		level_has_requirements = false
		if checklist_ui:
			checklist_ui.hide()

		# Stop ingredient spawns
		spawn_timer = INF

		# Disable & clear PestManager so only the boss is active
		if pest_manager:
			pest_manager.set_process(false)
			for c in pest_manager.get_children():
				if is_instance_valid(c):
					c.queue_free()

		# Spawn the Shiba boss under BossSpawn
		var shiba_scene: PackedScene = preload("res://Scenes/Shiba_Boss.tscn")
		shiba_boss = shiba_scene.instantiate() as ShibaBoss
		boss_spawn.add_child(shiba_boss)

		# Connect its defeat signal
		if shiba_boss.has_signal("boss_defeated"):
			shiba_boss.boss_defeated.connect(Callable(self, "_on_boss_defeated"))
		return

	# ----- Normal level setup -----
	# Make sure PestManager is active again
	if pest_manager:
		pest_manager.set_process(true)

	# Build requirements and checklist
	var level_data: Dictionary = LevelManager.get_current_requirements()
	for name in level_data.keys():
		var data: Dictionary = level_data[name]
		var combo_copy: Array = []
		if data.has("combo") and data["combo"] is Array:
			combo_copy = data["combo"].duplicate(true)
		required_ingredients[name] = {"combo": combo_copy, "count": int(data.get("amount", 0))}
		collected_counts[name] = 0

	level_has_requirements = required_ingredients.size() > 0

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
func _on_boss_defeated() -> void:
	print("Boss defeated!")
	_on_dish_completed()

func spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	ingredient_container.add_child(ing_node)

	var ing := ing_node as Ingredient
	if ing == null:
		push_error("Ingredients.tscn root must extend Ingredient.gd!")
		ing_node.queue_free()
		return

	# Level speed
	var base_speed := 150.0
	var level_index := LevelManager.current_level
	var speed_multiplier := 0.7 + (level_index * 0.15)
	ing.speed = base_speed * speed_multiplier

	# Assign combo & name
	var combo_arr: Array = []
	if required_ingredients.has(ingredient_name) and required_ingredients[ingredient_name].has("combo"):
		var raw = required_ingredients[ingredient_name]["combo"]
		if raw is Array:
			combo_arr = raw.duplicate(true)
	ing.set_combo_and_name(combo_arr, ingredient_name)

	# Connect chop_completed
	if ing.has_signal("chop_completed") and not ing.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
		ing.chop_completed.connect(Callable(self, "_on_ingredient_chopped"))

	# Random spawn position
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)

func _on_pest_failed(reason: String) -> void:
	last_fail_reason = reason
	_lose_heart(reason)

func _on_pest_attacked(pest_node: Node) -> void:
	last_fail_reason = "A pest attacked you!"
	_lose_heart(last_fail_reason)

# Main.gd

func _on_ingredient_chopped(ingredient_name: String) -> void:
	if not required_ingredients.has(ingredient_name):
		return

	var req_count: int = int(required_ingredients[ingredient_name]["count"])
	var cur_count: int = collected_counts.get(ingredient_name, 0)

	# Too many of this ingredient
	if cur_count >= req_count:
		# find the topmost ingredient (last in container) that matches
		for i in range(ingredient_container.get_child_count() - 1, -1, -1):
			var ing_node = ingredient_container.get_child(i)
			if ing_node is Ingredient and ing_node.ingredient_name == ingredient_name and not ing_node.is_chopped:
				ing_node.flash_x()
				break

		_lose_heart("You put too many %ss!" % ingredient_name)
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
	var clean_sequence := sequence.duplicate()
	var dish := LevelManager.get_current_dish()
	var is_boss: bool = dish.get("is_boss", false)

	# --- 1) Boss check ---
	if is_boss and shiba_boss and is_instance_valid(shiba_boss):
		if shiba_boss.check_sequence(clean_sequence):
			# correct boss input → clear buffer
			if "input_buffer" in player_input:
				player_input.input_buffer.clear()
				if player_input.has_method("_update_display"):
					player_input._update_display()
			return
		else:
			# wrong boss input → react & deduct heart
			shiba_boss.react_wrong_input()
			if "input_buffer" in player_input:
				player_input.input_buffer.clear()
				if player_input.has_method("_update_display"):
					player_input._update_display()
			return

	# --- 2) PestManager (non-boss flow) ---
	if has_node("PestManager"):
		var pm = $PestManager
		if pm and pm.check_sequence(clean_sequence):
			if "input_buffer" in player_input:
				player_input.input_buffer.clear()
				if player_input.has_method("_update_display"):
					player_input._update_display()
			return

	# --- 3) Ingredient levels ---
	if not level_has_requirements:
		if "input_buffer" in player_input:
			player_input.input_buffer.clear()
		return

	# --- 4) Check ingredients (topmost first) ---
	var matched: bool = false
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var ing_node = ingredient_container.get_child(i)
		if not is_instance_valid(ing_node):
			continue
		var ing = ing_node as Ingredient
		if ing == null or ing.is_chopped:
			continue

		var name: String = ing.ingredient_name
		if not required_ingredients.has(name):
			continue

		var req_count: int = int(required_ingredients[name]["count"])
		var cur_count: int = collected_counts.get(name, 0)

		# Too many → lose heart
		if cur_count >= req_count:
			if clean_sequence.size() == ing.combo.size():
				var would_equal := true
				for j in range(clean_sequence.size()):
					if str(clean_sequence[j]) != str(ing.combo[j]):
						would_equal = false
						break
				if would_equal:
					# flash X on the topmost matching ingredient
					_flash_topmost_ingredient(name)

					_lose_heart("You put too many %ss!" % name)
					matched = true
					break
					
			continue

		# Exact combo match
		if clean_sequence.size() != ing.combo.size():
			continue

		var equal := true
		for j in range(clean_sequence.size()):
			if str(clean_sequence[j]) != str(ing.combo[j]):
				equal = false
				break

		if equal:
			matched = true
			ing.play_slash_sequence(clean_sequence)
			if not ing.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
				ing.connect("chop_completed", Callable(self, "_on_ingredient_chopped"))
			combo += 1
			if combo > highest_combo:
				highest_combo = combo
			_update_combo_ui()
			break

	# --- 5) Wrong combo handling ---
	if not matched:
		_lose_heart("Wrong combo!")

	# --- 6) Always clear input buffer ---
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

func _on_sequence_reset() -> void:
	print("Input reset!")
	combo = 0
	_update_combo_ui()

# -----------------------
# Win / Dish celebration
# -----------------------
func _all_ingredients_collected() -> bool:
	var dish_info: Dictionary = LevelManager.get_current_dish()
	if dish_info.get("is_boss", false):
		return false  # boss completion handled separately
	for name in required_ingredients.keys():
		if collected_counts.get(name, 0) < int(required_ingredients[name]["count"]):
			return false
	return true

func _on_dish_completed() -> void:
	dish_completed = true
	game_paused = true

	# Save hearts & combo
	saved_hearts = clamp(current_hearts, 0, max_hearts)
	saved_combo = combo

	# Show dish UI
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var dish_texture: Texture2D = dish_info.get("texture")
	var dish_name: String = dish_info.get("name")
	if dish_ui and dish_ui.has_method("show_dish"):
		dish_ui.show_dish(dish_texture, dish_name)

	# Overlay effects
	win_overlay.visible = true
	if $WinOverlay/DishCompleteUI/Star/AnimationPlayer:
		$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")

	# Play SFX
	var sfx := get_node_or_null("/root/SFXManager")
	if sfx == null:
		sfx = get_node_or_null("/root/MusicManager")
	if sfx != null and sfx.has_method("play_sfx"):
		sfx.play_sfx("level_up")

	# Wait 2 seconds, then continue
	await get_tree().create_timer(2.0).timeout

	win_overlay.visible = false
	game_paused = false
	dish_completed = false

	# Clear leftover input buffer
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

	# Next level
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
	print("debugging: _game_over() - saving score. current_hearts:", current_hearts, "combo:", combo, "highest_combo:", highest_combo, "Level:", LevelManager.current_level)
	return max(0, score)

func _game_over() -> void:
	# Get level number
	var level_number: int = LevelManager.current_level + 1

	# Calculate time taken
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var level_time_limit: int = int(dish_info.get("time_limit", 0))
	var time_taken: int = clamp(level_time_limit - int(time_left), 0, level_time_limit)

	# print debug info
	print("debugging: Level:", level_number)
	print("debugging: Time taken:", time_taken)
	print("debugging: Highest combo:", highest_combo)

	# Calculate score
	var score: int = int(level_number * highest_combo * 10) - int(time_taken)
	score = max(0, score)
	print("debugging: Score calculated:", score)
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
