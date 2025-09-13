extends Node2D

@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var text_popup_scene: PackedScene = preload("res://Scenes/text_popup.tscn")
@onready var sauce_scene: PackedScene = preload("res://Scenes/sauce.tscn")
@onready var player_input: Node = $UI/PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $UI/Checklist
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI  
@onready var win_overlay: CanvasLayer = $WinOverlay
@onready var pest_manager: Node = $PestManager
@onready var boss_spawn: Node2D = $BossSpawn
@onready var damage_flash: ColorRect = $UI/DamageFlash
@onready var PotAnimation: AnimatedSprite2D = $PotAnimation
@export var max_input_length: int = 10

# Pests
@onready var pest_scene: PackedScene = preload("res://Scenes/mosquito.tscn")

# Exports / Tunables
@export var max_hearts: int = 3

# ingredient spawning
@export var spawn_interval: float = 1.5
@export var max_active_ingredients: int = 100
@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float = 80.0
@export var spawn_start_y: float = -100.0

# pest spawning
@export var pest_spawn_min: float = 3.0
@export var pest_spawn_max: float = 8.0
@export var pest_spawn_repeat_min: float = 4.0
@export var pest_spawn_repeat_max: float = 12.0
@export var max_active_pests: int = 3

# Sauce spawning
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var base_spawn_interval: float = 1.2
var sauce_cooldown: float = 5.0 # 5
var sauce_min_cooldown: float = 3.0 # 3
var sauce_max_cooldown: float = 8.0 # 8

# State
var current_hearts: int = max_hearts
@onready var hearts_ui: HBoxContainer = $UI/HeartsContainer

var combo: int = 0
var highest_combo: int = 0
@onready var combo_label: Label = $UI/ComboLabel

var required_ingredients: Dictionary = {}  
var collected_counts: Dictionary = {}

var spawn_timer: float = 0.0
var pest_next_spawn: float = 0.0

var game_paused: bool = false
var waiting_for_continue: bool = false   
var dish_completed: bool = false

var time_left: int = 0
var level_has_requirements: bool = false

var last_fail_reason: String = ""

var saved_hearts: int = max_hearts
var saved_combo: int = 0
var shiba_boss: ShibaBoss = null  

var active_buffs: Dictionary = {}       
var buff_icon_nodes: Dictionary = {}  
var ingredient_speed_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("Game")
	MusicManager.set_all_sfx_volume(5)
	MusicManager.set_sfx_volume_for("slash",20)
	
	# sauce
	rng.randomize()
	sauce_cooldown = rng.randf_range(sauce_min_cooldown, sauce_max_cooldown)
	
	PotAnimation.play("normal")
	
	# BGM 
	var title_music = preload("res://Audio/bgm.ogg")
	MusicManager.play_bgm(title_music, true)

	player_input.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
	if player_input.has_signal("sequence_reset"):
		player_input.sequence_reset.connect(Callable(self, "_on_sequence_reset"))

	win_overlay.visible = false
	dish_completed = false
	game_paused = false

	# start level
	_load_level()
	_update_hearts_ui()
	_update_combo_ui()

	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)
	randomize()

# Hearts 
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
	
	var popup_pos: Vector2
	popup_pos = ingredient_container.global_position + Vector2(270, 400)
	_spawn_text_popup(reason, popup_pos)
	
	# Damage indicator 
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
	add_child(popup)
	popup.position = to_local(world_pos) if has_method("to_local") else world_pos
	popup.show_text(msg)

func _flash_topmost_ingredient(name: String) -> void:
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
			if ing.has_method("flash_x"):
				ing.flash_x()
				print("DEBUG: flashed X on topmost unchopped ", name)
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
				print("DEBUG: flashed X on topmost (fallback) ", name)
			return

# Start level
func _load_level(saved_hearts: int = max_hearts, saved_combo: int = 0) -> void:
	current_hearts = clamp(saved_hearts, 0, max_hearts)
	combo = saved_combo
	if combo > highest_combo:
		highest_combo = combo
	
	for child in ingredient_container.get_children():
		child.queue_free()

	if shiba_boss and is_instance_valid(shiba_boss):
		shiba_boss.queue_free()
		shiba_boss = null
	
	required_ingredients.clear()
	collected_counts.clear()
	dish_completed = false
	game_paused = false
	_update_combo_ui()
	_update_hearts_ui()
	
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)
	
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()
	
	# Dish images
	var dish: Dictionary = LevelManager.get_current_dish()
	$UI/DishTitle.text = " " + str(dish.get("name","Unknown Dish"))
	time_left = int(dish.get("time_limit", 60))
	$UI/TimerLabel.text = str(time_left)
	$UI/TimerLabel/LevelTimer.stop()
	if time_left > 0:
		$UI/TimerLabel/LevelTimer.start()

	# Boss level?!
	if dish.get("is_boss", false):
		level_has_requirements = false
		if checklist_ui:
			checklist_ui.hide()
		
		spawn_timer = INF
		
		if pest_manager:
			pest_manager.set_process(false)
			for c in pest_manager.get_children():
				if is_instance_valid(c):
					c.queue_free()
		
		# Spawn SHIBA BOSS!!
		var shiba_scene: PackedScene = preload("res://Scenes/shiba_boss.tscn")
		shiba_boss = shiba_scene.instantiate() as ShibaBoss
		boss_spawn.add_child(shiba_boss)
		
		if shiba_boss.has_signal("boss_defeated"):
			shiba_boss.boss_defeated.connect(Callable(self, "_on_boss_defeated"))
		
		if player_input and player_input.has_signal("buffer_changed"):
			player_input.buffer_changed.connect(Callable(shiba_boss, "on_input_buffer_changed"))
		
		return
	
	if pest_manager:
		pest_manager.set_process(true)
	
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

# Main process
func _process(delta: float) -> void:
	if game_paused:
		return
	
	if "input_buffer" in player_input:
		while player_input.input_buffer.size() > max_input_length:
			player_input.input_buffer.pop_front()  # remove oldest input
		if player_input.has_method("_update_display"):
			player_input._update_display()
	
	sauce_cooldown -= delta
	if sauce_cooldown <= 0.0:
		if rng.randf() < 0.1:  
			spawn_sauce()	
		sauce_cooldown = rng.randf_range(sauce_min_cooldown, sauce_max_cooldown)	
		
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_try_spawn_needed()
		spawn_timer = spawn_interval
		
	if not dish_completed and _all_ingredients_collected():
		_on_dish_completed()

func _try_spawn_needed() -> void:
	if dish_completed:
		return 
		
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
			pool.append_array([name, name, name])
		else:
			pool.append(name)
	
	# safety
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

# spawn ingredients 
func _on_sauce_collected(sauce_type: String) -> void:
	var popup_pos: Vector2
	popup_pos = ingredient_container.global_position + Vector2(270, 400)
	
	MusicManager.play_sfx("powerup")
	
	match sauce_type:
		"hot":
			_spawn_text_popup("Slow Down!", popup_pos)
			ingredient_speed_multiplier = 0.35   # stronger slowdown
			var t = get_tree().create_timer(10.0)
			t.timeout.connect(func():
				ingredient_speed_multiplier = 1.0
			)
		
		"soy":
			_spawn_text_popup("Combo Boost!", popup_pos)
			combo *= 2
			_update_combo_ui()
		
		"sweet":
			_spawn_text_popup("Extra Heart!", popup_pos)
			if current_hearts < max_hearts:
				current_hearts += 1
				_update_hearts_ui()
		
		"mystery":
			var list := ["hot","soy","sweet"]
			_on_sauce_collected(list[rng.randi() % list.size()] )

func spawn_sauce() -> void:
	if ingredient_container.get_child_count() >= max_active_ingredients:
		return
		
	var s := sauce_scene.instantiate() as Sauce
	if s == null:
		push_error("Failed to instantiate Sauce")
		return
		
	var types := ["hot", "soy", "sweet", "mystery"]
	s.sauce_type = types[rng.randi() % types.size()]
	
	s.position = Vector2(rng.randf_range(spawn_min_x, spawn_max_x), spawn_start_y)
	
	s.sauce_collected.connect(Callable(self, "_on_sauce_collected"))
	
	ingredient_container.add_child(s)

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
	
	if ing.has_signal("chop_completed") and not ing.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
		ing.chop_completed.connect(Callable(self, "_on_ingredient_chopped"))
	
	var spawn_x = randf_range(spawn_min_x, spawn_max_x)
	ing.position = Vector2(spawn_x, spawn_start_y)

func _on_pest_failed(reason: String) -> void:
	last_fail_reason = reason
	_lose_heart(reason)

func _on_pest_attacked(pest_node: Node) -> void:
	last_fail_reason = "A pest attacked you!"
	_lose_heart(last_fail_reason)

func _on_ingredient_chopped(ingredient_name: String) -> void:
	if not required_ingredients.has(ingredient_name):
		return
		
	var req_count: int = int(required_ingredients[ingredient_name]["count"])
	var cur_count: int = collected_counts.get(ingredient_name, 0)
	
	if cur_count >= req_count:
		for i in range(ingredient_container.get_child_count() - 1, -1, -1):
			var ing_node = ingredient_container.get_child(i)
			if ing_node is Ingredient and ing_node.ingredient_name == ingredient_name and not ing_node.is_chopped:
				ing_node.flash_x()
				break
				
		_lose_heart("Too many %ss!" % ingredient_name)
		return
	
	collected_counts[ingredient_name] = cur_count + 1
	
	if checklist_ui and checklist_ui.has_method("update_progress"):
		checklist_ui.update_progress(ingredient_name, collected_counts[ingredient_name])
	
	if _all_ingredients_collected():
		_on_dish_completed()

func _on_sequence_submitted(sequence: Array) -> void:
	var clean_sequence := sequence.duplicate()
	var dish := LevelManager.get_current_dish()
	var is_boss: bool = dish.get("is_boss", false)
	var matched: bool = false
	
	# 1) Sauces
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		if node is Sauce:
			if node.check_sequence(clean_sequence):
				matched = true
				break
	if matched:
		_clear_player_input()
		return
		
	#  2) Boss check 
	if is_boss and shiba_boss and is_instance_valid(shiba_boss):
		if shiba_boss.check_sequence(clean_sequence):
			matched = true
		else:
			# wrong boss input → react & deduct heart
			shiba_boss.react_wrong_input()
			_lose_heart("Wrong input against boss!")
			matched = true
		_clear_player_input()
		return
		
	#  3) PestManager
	if has_node("PestManager"):
		var pm = $PestManager
		if pm and pm.check_sequence(clean_sequence):
			matched = true
			_clear_player_input()
			return
			
	#  4) Ingredients 
	if not level_has_requirements:
		_clear_player_input()
		return
		
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
		
		# Too many of an ingredient = heart loss
		if cur_count >= req_count:
			if clean_sequence.size() == ing.combo.size():
				var would_equal := true
				for j in range(clean_sequence.size()):
					if str(clean_sequence[j]) != str(ing.combo[j]):
						would_equal = false
						break
				if would_equal:
					_flash_topmost_ingredient(name)
					_lose_heart("Too many %ss!" % name)
					matched = true
					break
			continue
		
		# Exact combo match
		if clean_sequence.size() == ing.combo.size():
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
				
	#  5) Wrong combo  
	if not matched:
		_lose_heart("Wrong combo!")
		
	#  6) Always clear input buffer 
	_clear_player_input()

# Avoid repeating buffer clearing
func _clear_player_input() -> void:
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
	if player_input.has_method("_update_display"):
		player_input._update_display()

func _on_sequence_reset() -> void:
	print("Input reset!")
	combo = 0
	_update_combo_ui()

# game win!
func _all_ingredients_collected() -> bool:
	var dish_info: Dictionary = LevelManager.get_current_dish()
	if dish_info.get("is_boss", false):
		return false  
	for name in required_ingredients.keys():
		if collected_counts.get(name, 0) < int(required_ingredients[name]["count"]):
			return false
	return true

func _on_dish_completed() -> void:
	dish_completed = true
	game_paused = true
	
	saved_hearts = clamp(current_hearts, 0, max_hearts)
	saved_combo = combo
	
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var dish_texture: Texture2D = dish_info.get("texture")
	var dish_name: String = dish_info.get("name")
	if dish_ui and dish_ui.has_method("show_dish"):
		dish_ui.show_dish(dish_texture, dish_name)
		
	win_overlay.visible = true
	if $WinOverlay/DishCompleteUI/Star/AnimationPlayer:
		$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")
	
	MusicManager.play_sfx("level_up")
	
	await get_tree().create_timer(2.0).timeout
	
	win_overlay.visible = false
	game_paused = false
	dish_completed = false
	
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()
	
	LevelManager.next_level()
	_load_level(saved_hearts, saved_combo)

func _on_continue_pressed() -> void:
	if win_overlay.visible:
		win_overlay.visible = false
		
	game_paused = false
	waiting_for_continue = false
	dish_completed = false
	
	saved_hearts = current_hearts
	saved_combo = combo
	
	LevelManager.next_level()
	_load_level(saved_hearts, saved_combo)

func _calculate_score() -> int:
	var level_number: int = LevelManager.current_level + 1
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var level_time_limit: int = int(dish_info.get("time_limit", 0))
	var time_taken: int = clamp(level_time_limit - int(time_left), 0, level_time_limit)
	var score: int = int(level_number * highest_combo * 10) - int(time_taken)
	
	print("(debug) 
	current_hearts:", current_hearts, 
	"combo:", combo, 
	"highest_combo:", highest_combo, 
	"Level:", LevelManager.current_level)
	
	return max(0, score)

func _game_over() -> void:
	PotAnimation.z_index = 10
	$UI/Pot.hide()
	$UI.hide()
	
	MusicManager.stop_bgm()
	MusicManager.stop_all_sfx()
	MusicManager.play_sfx("boil")
	PotAnimation.play("explode")
	await PotAnimation.animation_finished
	
	var level_number: int = LevelManager.current_level + 1
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var level_time_limit: int = int(dish_info.get("time_limit", 0))
	var time_taken: int = clamp(level_time_limit - int(time_left), 0, level_time_limit)
	
	print("debugging: Level:", level_number)
	print("debugging: Time taken:", time_taken)
	print("debugging: Highest combo:", highest_combo)
	
	var score: int = int(level_number * highest_combo * 10) - int(time_taken)
	score = max(0, score)
	print("debugging: Score calculated:", score)
	_save_score(score, last_fail_reason)
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func _save_score(score: int, reason: String) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("user://scores.cfg")
	cfg.set_value("scores", "last_score", score)
	cfg.set_value("scores", "last_fail_reason", reason)
	
	var prev_high: int = int(cfg.get_value("scores", "high_score", 0))
	if score > prev_high:
		cfg.set_value("scores", "high_score", score)
		
	var err: int = cfg.save("user://scores.cfg")
	if err != OK:
		push_error("Failed to save scores.cfg: %s" % str(err))

func _on_level_timer_timeout() -> void:
	time_left -= 1
	$UI/TimerLabel.text = str(time_left)
	if time_left <= 0:
		last_fail_reason = "You ran out of time."
		_game_over()
