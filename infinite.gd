extends Node2D

@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var text_popup_scene: PackedScene = preload("res://Scenes/text_popup.tscn")
@onready var player_input: Node = $UI/PlayerInput
@onready var ingredient_container: Node2D = $UI/IngredientContainer
@onready var checklist_ui: Control = $UI/Checklist
@onready var hearts_ui: HBoxContainer = $UI/HeartsContainer
@onready var combo_label: Label = $UI/ComboLabel
@onready var KillLine: Node2D = $KillLine
@onready var potAnimated: AnimatedSprite2D = $UI/PotAnimation
@onready var pot: Sprite2D = $UI/Pot
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI  
@onready var win_overlay: CanvasLayer = $WinOverlay
@onready var damage_flash: ColorRect = $UI/DamageFlash
@onready var alive_label: Label = $UI/AliveLabel

# tuning
@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float =  80.0
@export var spawn_start_y: float = -100.0
@export var max_active_ingredients: int = 100

@export var start_spawn_interval: float = 0.1
@export var start_multiplier: float = 0.25
@export var speed_increase_per_second: float = 0.01
@export var max_multiplier: float = 2.5
@export var spawn_interval_jitter: float = 0.35

@export var kill_line_y: float = 350  
@export var max_hearts: int = 6

@export var spawn_spacing_pixels: float = 150.0 
@export var spawn_speed_baseline: float = 150.0 
@export var min_spawn_interval: float = 0.03

@export var show_milliseconds: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawn_timer: float = 0.0
var ingredient_speed_multiplier: float = 1.0
var infinite_pool: Array[Dictionary] = []
var checklist: Dictionary = {}
var combo: int = 0
var highest_combo: int = 0
var current_hearts: int = max_hearts
var game_paused: bool = false
var game_over_triggered: bool = false
var dish_completed: bool = false
var damage_tween: Tween = null
var alive_time: float = 0.0

# -------------------------
# Lifecycle
# -------------------------
func _ready() -> void:
	# basic setup
	rng.randomize()
	add_to_group("Game")
	ingredient_speed_multiplier = start_multiplier
	_build_infinite_pool()
	
	# alive timer setup (guard the label)
	alive_time = 0.0
	if is_instance_valid(alive_label):
		alive_label.text = "00:00"
	
	# compute initial spawn_timer so spacing is consistent from the start
	var initial_v: float = spawn_speed_baseline * ingredient_speed_multiplier
	var initial_interval: float = spawn_spacing_pixels / max(0.0001, initial_v)
	initial_interval *= (1.0 + randf_range(-spawn_interval_jitter, spawn_interval_jitter))
	spawn_timer = max(min_spawn_interval, initial_interval)
	
	# initialize checklist from LevelManager (same requirements format as main game)
	_initialize_checklist()
	# <-- REMOVE spawn_timer = 0.0 so we don't wipe out the initial interval
	
	# connect player input signals
	if player_input and player_input.has_signal("sequence_submitted"):
		if not player_input.is_connected("sequence_submitted", Callable(self, "_on_sequence_submitted")):
			player_input.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
	if player_input and player_input.has_signal("sequence_reset"):
		if not player_input.is_connected("sequence_reset", Callable(self, "_on_sequence_reset")):
			player_input.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
	
	_update_hearts_ui()
	_update_combo_ui()
	potAnimated.play("normal")
	
	var intro = preload("res://Audio/bgm.ogg")
	var loop  = preload("res://Audio/bgmloop.ogg")
	MusicManager.play_bgm_with_intro(intro, loop)

func _process(delta: float) -> void:
	if game_paused:
		return

	# Update alive timer (only when game is running and not game over)
	if not game_over_triggered:
		alive_time += delta
		if is_instance_valid(alive_label):
			alive_label.text = "%s" % _format_time_mmss(alive_time)

	# gradually speed up falling ingredients (only once)
	ingredient_speed_multiplier = min(max_multiplier, ingredient_speed_multiplier + speed_increase_per_second * delta)

	# spawn timer logic (only once)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_infinite_ingredient()
		# _spawn_infinite_ingredient() will set the next spawn_timer

func _physics_process(delta: float) -> void:
	_cleanup_missed_ingredients()

# -------------------------
# Build the pool from LevelManager (reuse combos)
# -------------------------
func _build_infinite_pool() -> void:
	infinite_pool.clear()
	var seen: Dictionary = {}
	# assume LevelManager exists and contains levels
	for level in LevelManager.levels:
		# skip boss levels entirely so their ingredients are not included
		if level.get("is_boss", false):
			continue
		if level.has("requirements"):
			for name in level["requirements"].keys():
				if seen.has(name):
					continue
				seen[name] = true
				var req = level["requirements"][name]
				var combo_copy: Array[String] = []
				if req.has("combo") and req["combo"] is Array:
					for c in req["combo"]:
						combo_copy.append(str(c))
				infinite_pool.append({"name": name, "combo": combo_copy})

	# fallback pool if nothing found
	if infinite_pool.size() == 0:
		infinite_pool.append({"name":"Potato","combo":["↑","↓","Z"]})
		infinite_pool.append({"name":"Meat","combo":["→","↑","Z"]})
		infinite_pool.append({"name":"Carrot","combo":["↑","↑","↑","Z"]})

# -------------------------
# Checklist initialization that mirrors main game
# -------------------------
func _initialize_checklist() -> void:
	checklist.clear()
	var current_reqs: Dictionary = LevelManager.get_current_requirements()
	var req_counts: Dictionary = {}
	for nm in current_reqs.keys():
		checklist[nm] = 0
		req_counts[nm] = int(current_reqs[nm].get("amount", 0))
	
	checklist_ui.setup_checklist(req_counts)
	checklist_ui.show()

# -------------------------
# Spawn logic — only spawn ingredients still needed on the checklist
# -------------------------
func _spawn_infinite_ingredient() -> void:
	if ingredient_container.get_child_count() >= max_active_ingredients:
		return
	
	var available_pool: Array = []
	for item in infinite_pool:
		var name: String = item.get("name", "")
		if not checklist.has(name):
			continue
		
		var required_amount: int = int(LevelManager.get_requirement_for(name).get("amount", 999))
		if checklist.get(name, 0) < required_amount:
			available_pool.append(item)
	
	if available_pool.size() == 0:
		# nothing left to spawn for this level
		# set a small retry interval so we check again soon (use baseline)
		var v_retry: float = spawn_speed_baseline * ingredient_speed_multiplier
		var retry_interval: float = spawn_spacing_pixels / max(0.0001, v_retry)
		spawn_timer = max(min_spawn_interval, retry_interval)
		return
	
	var pick: Dictionary = available_pool[rng.randi() % available_pool.size()]
	var combo_copy: Array = pick.get("combo", []).duplicate(true)
	var s: Ingredient = ingredient_scene.instantiate() as Ingredient
	
	s.call_deferred("set_combo_and_name", combo_copy, pick.get("name", ""))

	s.position = Vector2(rng.randf_range(spawn_min_x, spawn_max_x), spawn_start_y)
	s.front_container = ingredient_container
	s._game_node = self

	if s.has_signal("chop_completed") and not s.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
		s.connect("chop_completed", Callable(self, "_on_ingredient_chopped"))

	ingredient_container.add_child(s)

	# --- compute next spawn interval so vertically they're ~spawn_spacing_pixels apart ---
	# using baseline (per-ingredient bases removed for simplicity & correctness)
	var base_speed: float = spawn_speed_baseline
	# actual vertical speed (pixels/sec)
	var v: float = max(0.0001, base_speed * ingredient_speed_multiplier)
	var next_interval: float = spawn_spacing_pixels / v
	next_interval *= (1.0 + randf_range(-spawn_interval_jitter, spawn_interval_jitter))
	spawn_timer = max(min_spawn_interval, next_interval)

# -------------------------
# Player input handling (chop matching)
# -------------------------
func _on_sequence_submitted(sequence: Array) -> void:
	var clean_sequence: Array = sequence.duplicate()
	var matched: bool = false

	# match against spawned ingredients, topmost-first
	for i in range(ingredient_container.get_child_count()):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		# only Ingredients are relevant
		var ing: Ingredient = node as Ingredient
		if ing == null or ing.is_chopped:
			continue
		if _sequences_match(clean_sequence, ing.combo):
			matched = true
			ing.play_slash_sequence(clean_sequence)
			# chop_completed signal will call _on_ingredient_chopped
			break

	if not matched:
		_lose_heart("Wrong combo!", 0.5)

	player_input.input_buffer.clear()
	player_input._update_display()

# -------------------------
# When ingredient reports it was chopped
# -------------------------
func _on_ingredient_chopped(ingredient_name: String, chopped_ingredient: Ingredient) -> void:
	var max_amount: int = int(LevelManager.get_requirement_for(ingredient_name).get("amount", 999))

	# Normal collect: increment checklist and update UI
	if checklist.has(ingredient_name):
		checklist[ingredient_name] += 1
		checklist[ingredient_name] = min(checklist[ingredient_name], max_amount)
		if checklist_ui:
			checklist_ui.update_progress(ingredient_name, checklist[ingredient_name])

	# combo tracking + feedback
	combo += 1
	if combo > highest_combo:
		highest_combo = combo
	_update_combo_ui()

	# spawn text popup for main ingredient
	var popup_pos: Vector2 = ingredient_container.global_position + Vector2(270, 400)
	_spawn_text_popup("Collected %s!" % ingredient_name, popup_pos)
	MusicManager.play_sfx("chop")

	# --- remove extra ingredients ONLY if the checklist already has enough ---
	if checklist[ingredient_name] >= max_amount:
		for child in ingredient_container.get_children():
			if not is_instance_valid(child):
				continue
			var ing: Ingredient = child as Ingredient
			if ing == null:
				continue
			if ing != chopped_ingredient and ing.ingredient_name == ingredient_name and not ing.is_chopped:
				ing.queue_free()

	# check for dish completion
	if _check_if_level_completed():
		await get_tree().create_timer(0.6).timeout
		_on_dish_completed()

# helper to remove extra un-chopped instances of a given ingredient name
func _remove_extra_ingredients_of_type(name: String) -> void:
	for child in ingredient_container.get_children():
		if not is_instance_valid(child):
			continue
		var ing: Ingredient = child as Ingredient
		if ing == null:
			continue
		if ing.ingredient_name == name and not ing.is_chopped:
			ing.queue_free()

func _remove_extra_ingredients(name: String, except_node: Node) -> void:
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var ing = ingredient_container.get_child(i)
		if ing is Ingredient and ing.ingredient_name == name and ing != except_node and not ing.is_chopped:
			ing.queue_free()

# -------------------------
# Check completion (all checklist items reached their required amount)
# -------------------------
func _check_if_level_completed() -> bool:
	var reqs: Dictionary = LevelManager.get_current_requirements()
	for name in checklist.keys():
		var required_amount: int = int(reqs.get(name, {}).get("amount", 0))
		if checklist.get(name, 0) < required_amount:
			return false
	return true

# -------------------------
# Dish finished: pick random other level and continue
# -------------------------
func _on_dish_completed() -> void:
	dish_completed = true
	var total: int = LevelManager.levels.size()
	if total <= 1:
		_initialize_checklist()
		# keep current spawn_timer and ingredient_speed_multiplier so flow is uninterrupted
		return
	
	var candidates: Array[int] = []
	for i in range(total):
		if i != int(LevelManager.current_level):
			var lvl: Dictionary = LevelManager.levels[i]
			if not lvl.get("is_boss", false):
				candidates.append(i)

	var chosen: int = int(LevelManager.current_level)
	if candidates.size() > 0:
		chosen = candidates[rng.randi() % candidates.size()]

	# set the LevelManager to the chosen level and re-init checklist (do NOT reset speed nor clear ingredients)
	LevelManager.current_level = chosen

	var dish_info: Dictionary = LevelManager.get_current_dish()
	var next_name: String = str(dish_info.get("name", "Unknown Dish"))
	var dish_name: String = dish_info.get("name")
	var dish_texture: Texture2D = dish_info.get("texture")
	_initialize_checklist()
	
	dish_ui.show_dish(dish_texture, dish_name)
	MusicManager.play_sfx("level_up")

	win_overlay.visible = true
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")
	await get_tree().create_timer(2.0).timeout
	
	win_overlay.visible = false
	game_paused = false
	dish_completed = false

# -------------------------
# Missed ingredients -> lose heart if not chopped
# -------------------------
func _cleanup_missed_ingredients() -> void:
	for ing_node in ingredient_container.get_children():
		if not is_instance_valid(ing_node):
			continue
		var ing: Ingredient = ing_node as Ingredient
		if ing == null:
			continue
		if ing.global_position.y > kill_line_y:
			# If the ingredient wasn't chopped, player loses a heart
			if not ing.is_chopped:
				_lose_heart("Missed %s!" % ing.ingredient_name, 1.0)
			# Always remove the ingredient
			ing.queue_free()

# -------------------------
# Clear all active ingredients
# -------------------------
func _clear_all_ingredients() -> void:
	for child in ingredient_container.get_children():
		if is_instance_valid(child):
			child.queue_free()

# -------------------------
# UI / helpers
# -------------------------
func _lose_heart(reason: String, amount: float = 1.0) -> void:
	current_hearts -= amount
	current_hearts = max(0, current_hearts)
	combo = 0
	_update_combo_ui()
	_update_hearts_ui()
	MusicManager.play_sfx("wrong")
	var popup_pos: Vector2 = ingredient_container.global_position + Vector2(270, 400)
	_spawn_text_popup(reason, popup_pos)
	
	if damage_flash:
		if damage_tween and is_instance_valid(damage_tween):
			damage_tween.kill()
			damage_tween = null
		
		damage_flash.visible = true
		
		var m: Color = damage_flash.modulate
		m.a = 1.0
		damage_flash.modulate = m
		
		var c: Color = damage_flash.color
		c.a = 1.0
		damage_flash.color = c
		
		damage_tween = create_tween()
		damage_tween.tween_property(damage_flash, "modulate:a", 0.0, 0.4) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)
		
		damage_tween.finished.connect(func():
			damage_flash.visible = false
			damage_tween = null
		)
		
	if current_hearts <= 0:
		_on_game_over()

func _update_hearts_ui() -> void:
	if not hearts_ui:
		return
	for i in range(hearts_ui.get_child_count()):
		var heart: TextureRect = hearts_ui.get_child(i)
		var full_heart_index = i * 2
		if current_hearts > full_heart_index + 1:
			heart.texture = preload("res://Sprites/HeartFull.png")
		elif current_hearts == full_heart_index + 1:
			heart.texture = preload("res://Sprites/HeartHalf2.png")
		else:
			heart.texture = preload("res://Sprites/SlashAnimations/blank.png")

func _update_combo_ui() -> void:
	if not combo_label:
		return
	if combo > 0:
		combo_label.text = "%dx Combo!" % combo
	else:
		combo_label.text = ""

func _spawn_text_popup(msg: String, world_pos: Vector2) -> void:
	if not text_popup_scene:
		return
	var popup: Node2D = text_popup_scene.instantiate()
	add_child(popup)
	popup.position = to_local(world_pos)
	popup.show_text(msg)

func _sequences_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if str(a[i]) != str(b[i]):
			return false
	return true

func _on_game_over() -> void:
	if game_over_triggered:
		return
	game_over_triggered = true
	
	MusicManager.stop_bgm()
	MusicManager.stop_all_sfx()
	MusicManager.play_sfx("boil")
	potAnimated.z_index = 10
	
	potAnimated.play("explode")
	await potAnimated.animation_finished
	
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func _format_time_mmss(t: float) -> String:
	var total_seconds := int(t)             # truncate to whole seconds
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
