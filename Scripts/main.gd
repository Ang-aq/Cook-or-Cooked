extends Node2D

#region Nodes + Scenes
@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var text_popup_scene: PackedScene = preload("res://Scenes/text_popup.tscn")
@onready var sauce_scene: PackedScene = preload("res://Scenes/sauce.tscn")
@onready var en_font: Font = preload("res://Fonts/CutePixel.ttf")
@onready var jp_font: Font = preload("res://Fonts/BestTen-CRT.otf")
@onready var player_input: Node = $UI/PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var checklist_ui: Control = $UI/Checklist
@onready var dish_ui: Control = $WinOverlay/DishCompleteUI  
@onready var win_overlay: CanvasLayer = $WinOverlay
@onready var pest_manager: Node = $PestManager
@onready var boss_spawn: Node2D = $BossSpawn
@onready var damage_flash: ColorRect = $UI/DamageFlash
@onready var PotAnimation: AnimatedSprite2D = $PotAnimation
@onready var pest_scene: PackedScene = preload("res://Scenes/mosquito.tscn")
@onready var hearts_ui: HBoxContainer = $UI/HeartsContainer
@onready var combo_label: Label = $UI/ComboLabel
@onready var IngManager: Node = $IngredientManager
@onready var countdown_label: Label = $UI/Countdown
@onready var fade_rect: ColorRect = $UI/Fade
@onready var dish_title: Label = $UI/DishTitle
@export var chop_min_y: float = -100
@export var chop_max_y: float = 500.0
#endregion
#region Exports
# ingredient spawning
@export var spawn_interval: float = 1.5
@export var max_active_ingredients: int = 100
@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float = 80.0
@export var spawn_start_y: float = -100.0
@export var kill_line_y: float = 350.0  

# pest spawning
@export var pest_spawn_min: float = 15.0
@export var pest_spawn_max: float = 18.0
@export var pest_spawn_repeat_min: float = 15.0 # 15
@export var pest_spawn_repeat_max: float = 18.0 # 18
@export var max_active_pests: int = 3

# other exports 
@export var max_hearts: int = 6
@export var max_input_length: int = 10
#endregion
#region Variables
# sauce spawning
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var base_spawn_interval: float = 5.0 # 5
var sauce_cooldown: float = 5.0 # 5
var sauce_min_cooldown: float = 3.0 # 3
var sauce_max_cooldown: float = 8.0 # 8

# State
var current_hearts: int = max_hearts

var combo: int = 0
var highest_combo: int = 0

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
var damage_tween: Tween = null

var saved_hearts: int = max_hearts
var saved_combo: int = 0
var shiba_boss: ShibaBoss = null  

var active_buffs: Dictionary = {}       
var buff_icon_nodes: Dictionary = {}  
var ingredient_speed_multiplier: float = 1.0
var game_over_triggered: bool = false

var countdown_time: int = 3
var countdown_active: bool = false
var countdown_finish: bool = false
#endregion
func _ready() -> void:
	fade_in()
	player_input.set_process_unhandled_input(false)
	add_to_group("Game")
	rng.randomize()
	sauce_cooldown = rng.randf_range(sauce_min_cooldown, sauce_max_cooldown)
	
	PotAnimation.play("normal")
	
	if not player_input.is_connected("sequence_submitted", Callable(self, "_on_sequence_submitted")):
		player_input.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
	if player_input.has_signal("sequence_reset") and not player_input.is_connected("sequence_reset", Callable(self, "_on_sequence_reset")):
		player_input.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
	
	win_overlay.visible = false
	dish_completed = false
	game_paused = false
	
	_load_level()
	
	if is_instance_valid(IngManager):
		IngManager.set_requirements(required_ingredients, collected_counts)
	
	if is_instance_valid(IngManager) and IngManager.has_signal("ingredient_chopped"):
		if not IngManager.is_connected("ingredient_chopped", Callable(self, "_on_ingredient_chopped")):
			IngManager.ingredient_chopped.connect(Callable(self, "_on_ingredient_chopped"))
	
	_update_hearts_ui()
	_update_combo_ui()
	
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)
	randomize()

func _start_main_countdown() -> void:
	if not is_instance_valid(countdown_label):
		game_paused = false
		return
	MusicManager.stop_bgm()
	MusicManager.play_sfx("countdown")
	countdown_finish = true
	countdown_active = true
	countdown_label.visible = true
	
	var steps = ["3", "2", "1", "GO!"]
	for i in steps:
		countdown_label.text = i
		if i == "GO!":
			await get_tree().create_timer(1.0).timeout
			_begin_gameplay()
			countdown_label.visible = false
		await get_tree().create_timer(1.0).timeout

func _begin_gameplay() -> void:
	game_paused = false
	player_input.set_process_unhandled_input(true)
	spawn_timer = randf_range(0.25, spawn_interval)
	pest_next_spawn = randf_range(pest_spawn_min, pest_spawn_max)
	
	if time_left > 0:
		$UI/TimerLabel/LevelTimer.start()
	
	var intro = preload("res://Audio/bgm.ogg")
	var loop  = preload("res://Audio/bgmloop.ogg")
	MusicManager.play_bgm_with_intro(intro, loop)
	
func _update_hearts_ui() -> void:
	for i in range(hearts_ui.get_child_count()):
		var heart: TextureRect = hearts_ui.get_child(i)
		var full_heart_index = i * 2
		if current_hearts > full_heart_index + 1:
			heart.texture = preload("res://Sprites/HeartFull.png")
		elif current_hearts == full_heart_index + 1:
			heart.texture = preload("res://Sprites/HeartHalf2.png")
		else:
			heart.texture = preload("res://Sprites/SlashAnimations/blank.png")

func _lose_heart(reason: String, amount: float = 1.0) -> void:
	current_hearts -= amount
	current_hearts = max(current_hearts, 0)
	last_fail_reason = reason
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
		_game_over()

func _update_combo_ui() -> void:
	if combo > 0:
		combo_label.text = LocalizationManager.t("%dx Combo!") % combo
	else:
		combo_label.text = ""

func _spawn_text_popup(msg: String, world_pos: Vector2) -> void:
	var popup := text_popup_scene.instantiate()
	add_child(popup)
	popup.position = to_local(world_pos) 
	popup.show_text(msg)

# start level
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
		player_input._update_display()
	
	var dish: Dictionary = LevelManager.get_current_dish()
	var dish_name = dish.get("name", "Unknown Dish")
	dish_title.text = " " + LocalizationManager.t(dish_name)
	time_left = int(dish.get("time_limit", 60))
	$UI/TimerLabel.text = str(time_left)
	
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
		
		var shiba_scene: PackedScene = preload("res://Scenes/shiba_boss.tscn")
		shiba_boss = shiba_scene.instantiate() as ShibaBoss
		boss_spawn.add_child(shiba_boss)
		
		if shiba_boss.has_signal("boss_defeated"):
			shiba_boss.boss_defeated.connect(Callable(self, "_on_boss_defeated"))
		
		if player_input and player_input.has_signal("buffer_changed"):
			player_input.buffer_changed.connect(Callable(shiba_boss, "on_input_buffer_changed"))
		
		if is_instance_valid(IngManager):
			IngManager.stop()
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
	if checklist_ui:
		checklist_ui.setup_checklist(req_counts)
		checklist_ui.show()
	
	if is_instance_valid(IngManager):
		IngManager.set_requirements(required_ingredients, collected_counts)
		IngManager.start()
	
	if countdown_finish == false:
		game_paused = true
		_start_main_countdown()

# main process
func _process(delta: float) -> void:
	if game_paused:
		return
	
	if "input_buffer" in player_input:
		while player_input.input_buffer.size() > max_input_length:
			player_input.input_buffer.pop_front()
		player_input._update_display()
	
	sauce_cooldown -= delta
	if sauce_cooldown <= 0.0:
		if rng.randf() < 0.25:
			spawn_sauce()
		sauce_cooldown = rng.randf_range(sauce_min_cooldown, sauce_max_cooldown)
	
	if not dish_completed and _all_ingredients_collected():
		_on_dish_completed()

# spawn ingredients 
func _on_sauce_collected(sauce_type: String) -> void:
	var popup_pos: Vector2
	popup_pos = ingredient_container.global_position + Vector2(270, 400)
	
	MusicManager.play_sfx("powerup")
	
	match sauce_type:
		"soy":
			_spawn_text_popup(LocalizationManager.t("Slow Down!"), popup_pos)
			ingredient_speed_multiplier = 0.35   # stronger slowdown
			var t = get_tree().create_timer(10.0)
			t.timeout.connect(func():
				ingredient_speed_multiplier = 1.0
			)
		
		"sweet":
			_spawn_text_popup(LocalizationManager.t("Combo Boost!"), popup_pos)
			combo *= 2
			_update_combo_ui()
		
		"hot":
			_spawn_text_popup(LocalizationManager.t("Extra Heart!"), popup_pos)
			if current_hearts < max_hearts:
				current_hearts += 2
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

func _on_pest_failed(reason: String) -> void:
	last_fail_reason = reason
	_lose_heart(reason, 0.5)

func _on_pest_attacked(pest_node: Node) -> void:
	_lose_heart(LocalizationManager.t("A pest attacked you!"), 0.5) 

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
				
		_lose_heart(LocalizationManager.t("Too many %ss!") % LocalizationManager.t(name))
		
		return
	
	collected_counts[ingredient_name] = cur_count + 1
	
	if checklist_ui:
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
		
	# 2) Boss check 
	if is_boss and shiba_boss and is_instance_valid(shiba_boss):
		if shiba_boss.check_sequence(clean_sequence):
			matched = true
		else:
			shiba_boss.react_wrong_input()
			_lose_heart(LocalizationManager.t("Wrong input!"))
			matched = true
		_clear_player_input()
		return
		
	# 3) PestManager
	if has_node("PestManager"):
		var pm = $PestManager
		if pm and pm.check_sequence(clean_sequence):
			matched = true
			_clear_player_input()
			return
			
	# 4) Ingredients 
	if not level_has_requirements:
		_clear_player_input()
		return
		
	for i in range(ingredient_container.get_child_count()):
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
		
		if cur_count >= req_count:
			if _sequences_match(clean_sequence, ing.combo):
				IngManager.flash_topmost_ingredient(name)
				_lose_heart(LocalizationManager.t("Too many %ss!") % LocalizationManager.t(name))
				matched = true
				break
			continue
		
		# Exact combo match
		if _sequences_match(clean_sequence, ing.combo):
			matched = true
			ing.play_slash_sequence(clean_sequence)
			if not ing.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
				ing.connect("chop_completed", Callable(self, "_on_ingredient_chopped"))
			combo += 1
			if combo > highest_combo:
				highest_combo = combo
			_update_combo_ui()
			break
				
	# 5) Wrong combo  
	if not matched:
		_lose_heart(LocalizationManager.t("Wrong combo!"), 0.5)  
		
	# 6) Always clear input buffer 
	_clear_player_input()

func _sequences_match(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if str(a[i]) != str(b[i]):
			return false
	return true

# Avoid repeating buffer clearing
func _clear_player_input() -> void:
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
	player_input._update_display()

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
	dish_ui.show_dish(dish_texture, dish_name)
		
	win_overlay.visible = true
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")
	
	MusicManager.play_sfx("level_up")
	
	await get_tree().create_timer(2.0).timeout
	
	win_overlay.visible = false
	game_paused = false
	dish_completed = false
	
	if "input_buffer" in player_input:
		player_input.input_buffer.clear()
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
	if game_over_triggered:
		return
	game_over_triggered = true
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

func fade_out(time: float = 0.5) -> void:
	fade_rect.visible = true
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = timer / time
		await get_tree().create_timer(0.0).timeout
	fade_rect.modulate.a = 1.0

func fade_in(time: float = 0.5) -> void:
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = 1.0 - (timer / time)
		await get_tree().create_timer(0.0).timeout
	fade_rect.modulate.a = 0.0
	fade_rect.visible = false

func _physics_process(delta: float) -> void:
	_cleanup_fallen_ingredients()

func _cleanup_fallen_ingredients() -> void:
	for ing_node in ingredient_container.get_children():
		if not is_instance_valid(ing_node):
			continue
		if ing_node.global_position.y > kill_line_y:
			ing_node.queue_free()

func _on_language_changed(new_lang: String) -> void:
	LocalizationManager.current_language = new_lang
	_update_ui_language()

func _update_ui_language() -> void:
	var dish = LevelManager.get_current_dish()
	dish_title.text = " " + LocalizationManager.t(dish.get("name", "Unknown Dish"))
	dish_title.add_theme_font_override("font", LocalizationManager.get_font())
	
	if checklist_ui:
		checklist_ui.refresh_translations()
	_apply_font_to_ui($UI, LocalizationManager.current_language == "jp")

func _apply_font_to_ui(node: Node, use_jp_font: bool) -> void:
	var font_to_use: Font = LocalizationManager.get_font()
	for child in node.get_children():
		if child is Label:
			child.add_theme_font_override("font", font_to_use)
		elif child is RichTextLabel:
			child.add_theme_font_override("normal_font", font_to_use)
		elif child.get_child_count() > 0:
			_apply_font_to_ui(child, use_jp_font)
