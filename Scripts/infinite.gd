extends Node2D

@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var text_popup_scene: PackedScene = preload("res://Scenes/text_popup.tscn")
@onready var en_font: Font = preload("res://Fonts/CutePixel.ttf")
@onready var jp_font: Font = preload("res://Fonts/BestTen-CRT.otf")
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
@onready var countdown_label: Label = $UI/CountdownLabel
@onready var fade_rect: ColorRect = $UI/Fade
@onready var dish_title: Label = $UI/DishTitle
@onready var tutorial_dialog: TutorialDialog = $UI/TutorialDialog
@onready var keys: AnimatedSprite2D = $UI/Keys
@onready var button: AnimatedSprite2D = $UI/Button
@onready var skip_label: Label = $UI/Skip

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
@export var accel_duration: float = 150.0 

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
var countdown_running: bool = false
var dishes_completed: int = 0
var last_fail_reason: String = ""
var tutorial_skipped: bool = false

func _ready() -> void:
	fade_in()
	game_paused = true
	player_input.input_enabled = not (game_paused or countdown_running)
	countdown_label.hide()
	_translate_ui_texts()
	
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(skip_label, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(skip_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	_start_tutorial()
	rng.randomize()
	add_to_group("Game")
	ingredient_speed_multiplier = start_multiplier
	_build_infinite_pool()
	
	alive_time = 0.0
	if is_instance_valid(alive_label):
		alive_label.text = "00:00"
	
	var initial_v: float = spawn_speed_baseline * ingredient_speed_multiplier
	var initial_interval: float = spawn_spacing_pixels / max(0.0001, initial_v)
	initial_interval *= (1.0 + randf_range(-spawn_interval_jitter, spawn_interval_jitter))
	spawn_timer = max(min_spawn_interval, initial_interval)
	
	_initialize_checklist()
	
	if player_input and player_input.has_signal("sequence_submitted"):
		if not player_input.is_connected("sequence_submitted", Callable(self, "_on_sequence_submitted")):
			player_input.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
	if player_input and player_input.has_signal("sequence_reset"):
		if not player_input.is_connected("sequence_reset", Callable(self, "_on_sequence_reset")):
			player_input.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
	
	_update_hearts_ui()
	_update_combo_ui()
	potAnimated.play("normal")
	button.play("click")
	
func _process(delta: float) -> void:
	if game_paused:
		return
	
	if not game_over_triggered:
		alive_time += delta
		if is_instance_valid(alive_label):
			alive_label.text = "%s" % _format_time_mmss(alive_time)
	
	ingredient_speed_multiplier = min(max_multiplier, ingredient_speed_multiplier + speed_increase_per_second * delta)
	
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_infinite_ingredient()

func _physics_process(delta: float) -> void:
	_cleanup_missed_ingredients()

func _translate_ui_texts() -> void:
	var lang = LocalizationManager.current_language
	if not LocalizationManager.translations.has(lang):
		return
	var dict = LocalizationManager.translations[lang]
	
	if is_instance_valid(alive_label) and dict.has("Dishes Made"):
		alive_label.text = dict["Dishes Made"]
	
	if is_instance_valid(combo_label) and combo > 0 and dict.has("%dx Combo!"):
		combo_label.text = dict["%dx Combo!"].replace("%d", str(combo))
	
	if is_instance_valid(skip_label) and dict.has("skip_tutorial"):
		skip_label.text = dict["skip_tutorial"]
	
	var use_jp_font = lang in ["jp", "ja"]
	_apply_font_to_ui(self, use_jp_font)

func _apply_font_to_ui(node: Node, use_jp_font: bool) -> void:
	var font_to_use: Font = jp_font if use_jp_font else en_font

	if node is Label:
		node.add_theme_font_override("font", font_to_use)
	elif node is RichTextLabel:
		node.add_theme_font_override("normal_font", font_to_use)
	elif node is Button:
		node.add_theme_font_override("font", font_to_use)

	for child in node.get_children():
		_apply_font_to_ui(child, use_jp_font)

func _start_tutorial() -> void:
	var lang = LocalizationManager.current_language
	var dict = LocalizationManager.translations[lang]

	var lines: Array[String] = [
		dict.get("tutorial_1", "Hey you! Come here, quickly!"),
		dict.get("tutorial_2", "It's RUSH HOUR and the line of customers seems endless!"),
		dict.get("tutorial_3", "We need the dishes done as soon as possible. Here I'll teach you the basics."),
		dict.get("tutorial_4", "Chop ingredients by entering their combos using the BLUE JOYSTICK."),
		dict.get("tutorial_5", "Then press the RED BUTTON to enter the combo and the BLUE BUTTON to reset!")
	]

	var portraits: Array[Texture] = [
		load("res://Sprites/Portrait3.png"),
		load("res://Sprites/Portrait4.png"),
		load("res://Sprites/Portrait1.png"),
		load("res://Sprites/Portrait1.png"),
		load("res://Sprites/Portrait1.png")
	]

	keys.show()
	keys.play("controls")

	if not tutorial_dialog.dialogue_finished.is_connected(_on_tutorial_finished):
		tutorial_dialog.dialogue_finished.connect(_on_tutorial_finished)

	tutorial_dialog.start_dialogue(lines, portraits)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("skipTutorial") and tutorial_skipped == false:
		tutorial_skipped = true
		tutorial_dialog.hide()
		keys.hide()
		skip_label.hide()
		_on_tutorial_finished()

func _on_tutorial_finished() -> void: 
	await fade_out()
	tutorial_skipped = true
	skip_label.hide()
	keys.hide()
	button.hide()
	tutorial_dialog.dialogue_finished.disconnect(_on_tutorial_finished)
	_start_countdown()

func _build_infinite_pool() -> void:
	infinite_pool.clear()
	var seen: Dictionary = {}
	for level in LevelManager.levels:
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

	if infinite_pool.size() == 0:
		infinite_pool.append({"name":"Potato","combo":["↑","↓","Z"]})
		infinite_pool.append({"name":"Meat","combo":["→","↑","Z"]})
		infinite_pool.append({"name":"Carrot","combo":["↑","↑","↑","Z"]})

func _initialize_checklist() -> void:
	checklist.clear()
	var current_reqs: Dictionary = LevelManager.get_current_requirements()
	var req_counts: Dictionary = {}
	for nm in current_reqs.keys():
		checklist[nm] = 0
		req_counts[nm] = int(current_reqs[nm].get("amount", 0))
	
	checklist_ui.setup_checklist(req_counts)
	checklist_ui.show()

	if is_instance_valid(dish_title):
		var dish_info: Dictionary = LevelManager.get_current_dish()
		var name = str(dish_info.get("name", "Unknown Dish"))
		if LocalizationManager.translations.has(LocalizationManager.current_language):
			var lang_dict = LocalizationManager.translations[LocalizationManager.current_language]
			if lang_dict.has(name):
				name = lang_dict[name]
		dish_title.text = name

func _start_countdown() -> void:
	if not is_instance_valid(countdown_label):
		game_paused = false
		player_input.input_enabled = not (game_paused or countdown_running) # FIX
		return
	await fade_in()
	MusicManager.stop_bgm()
	MusicManager.play_sfx("countdown")
	
	countdown_running = true
	countdown_label.visible = true
	
	var steps = ["3", "2", "1", "GO!"]
	for i in steps:
		countdown_label.text = i
		await get_tree().create_timer(1.0).timeout
		if i == "GO!":
			var intro = preload("res://Audio/bgm.ogg")
			var loop  = preload("res://Audio/bgmloop.ogg")
			MusicManager.play_bgm_with_intro(intro, loop)
			_spawn_infinite_ingredient()
	countdown_label.visible = false
	countdown_running = false
	game_paused = false
	player_input.input_enabled = not (game_paused or countdown_running)

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

	var base_speed: float = spawn_speed_baseline
	var v: float = max(0.0001, base_speed * ingredient_speed_multiplier)
	var next_interval: float = spawn_spacing_pixels / v
	next_interval *= (1.0 + randf_range(-spawn_interval_jitter, spawn_interval_jitter))
	spawn_timer = max(min_spawn_interval, next_interval)

#region Player Input
func _on_sequence_submitted(sequence: Array) -> void:
	if game_paused or countdown_running:
		return
	
	var clean_sequence: Array = sequence.duplicate()
	var matched: bool = false

	for i in range(ingredient_container.get_child_count()):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		var ing: Ingredient = node as Ingredient
		if ing == null or ing.is_chopped:
			continue
		
		if _sequences_match(clean_sequence, ing.combo):
			matched = true
			ing.play_slash_sequence(clean_sequence)
			
			var max_amount: int = int(LevelManager.get_requirement_for(ing.ingredient_name).get("amount", 999))
			if checklist.has(ing.ingredient_name) and checklist[ing.ingredient_name] + 1 >= max_amount:
				_remove_extra_ingredients(ing.ingredient_name, ing)

			break

	if not matched:
		_lose_heart(LocalizationManager.t("Wrong combo!"), 0.5)
	
	player_input.input_buffer.clear()
	player_input._update_display()
#endregion

#region Chopped Ingredients
func _on_ingredient_chopped(ingredient_name: String, chopped_ingredient: Ingredient) -> void:
	var max_amount: int = int(LevelManager.get_requirement_for(ingredient_name).get("amount", 999))

	if checklist.has(ingredient_name):
		checklist[ingredient_name] += 1
		checklist[ingredient_name] = min(checklist[ingredient_name], max_amount)
		if checklist_ui:
			checklist_ui.update_progress(ingredient_name, checklist[ingredient_name])

	combo += 1
	if combo > highest_combo:
		highest_combo = combo
	_update_combo_ui()

	var popup_pos: Vector2 = ingredient_container.global_position + Vector2(270, 400)
	_spawn_text_popup("Collected %s!" % ingredient_name, popup_pos)
	MusicManager.play_sfx("chop")

	if checklist[ingredient_name] >= max_amount:
		for child in ingredient_container.get_children():
			if not is_instance_valid(child):
				continue
			var ing: Ingredient = child as Ingredient
			if ing == null:
				continue
			if ing != chopped_ingredient and ing.ingredient_name == ingredient_name and not ing.is_chopped:
				ing.queue_free()
	
	if _check_if_level_completed():
		await get_tree().create_timer(0.6).timeout
		_on_dish_completed()

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
#endregion

#region Level Completion
func _check_if_level_completed() -> bool:
	var reqs: Dictionary = LevelManager.get_current_requirements()
	for name in checklist.keys():
		var required_amount: int = int(reqs.get(name, {}).get("amount", 0))
		if checklist.get(name, 0) < required_amount:
			return false
	return true

func _on_dish_completed() -> void:
	dish_completed = true

	# increment dishes completed (score factor)
	dishes_completed += 1

	# get current dish info to show UI
	var dish_info: Dictionary = LevelManager.get_current_dish()
	var dish_name: String = dish_info.get("name")
	var dish_texture: Texture2D = dish_info.get("texture")

	# show dish complete UI
	dish_ui.show_dish(dish_texture, dish_name)
	MusicManager.play_sfx("level_up")
	win_overlay.visible = true
	$WinOverlay/DishCompleteUI/Star/AnimationPlayer.play("Spin")

	await get_tree().create_timer(2.0).timeout

	win_overlay.visible = false
	dish_completed = false

	# choose next level for infinite flow
	var total: int = LevelManager.levels.size()
	if total <= 1:
		_initialize_checklist()
		return

	var candidates: Array[int] = []
	for i in range(total):
		if i != int(LevelManager.current_level):
			var lvl: Dictionary = LevelManager.levels[i]
			if not lvl.get("is_boss", false):
				candidates.append(i)

	if candidates.size() > 0:
		LevelManager.current_level = candidates[rng.randi() % candidates.size()]

	_initialize_checklist()
	game_paused = false
#endregion

func _cleanup_missed_ingredients() -> void:
	for ing_node in ingredient_container.get_children():
		if not is_instance_valid(ing_node):
			continue
		var ing: Ingredient = ing_node as Ingredient
		if ing == null:
			continue
		if ing.global_position.y > kill_line_y:
			if not ing.is_chopped:
				_lose_heart("Missed %s!" % ing.ingredient_name, 1.0)
			ing.queue_free()

func _clear_all_ingredients() -> void:
	for child in ingredient_container.get_children():
		if is_instance_valid(child):
			child.queue_free()


#region Helpers
func _lose_heart(reason: String, amount: float = 1.0) -> void:
	# store last fail reason for game over screen
	last_fail_reason = reason

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
	current_hearts -= amount
	current_hearts = max(0, current_hearts)
	combo = 0
	_update_combo_ui()
	_update_hearts_ui()
	MusicManager.play_sfx("wrong")
	popup_pos = ingredient_container.global_position + Vector2(270, 400)
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
		combo_label.text = LocalizationManager.t("%dx Combo!") % combo
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
#endregion

func _on_game_over() -> void:
	if game_over_triggered:
		return
	game_over_triggered = true

	potAnimated.z_index = 10
	pot.hide()
	
	MusicManager.stop_bgm()
	MusicManager.stop_all_sfx()
	MusicManager.play_sfx("boil")
	potAnimated.play("explode")
	await potAnimated.animation_finished
	
	# dishes_completed * seconds_lived * highest_combo
	var seconds_lived: int = int(alive_time)
	var score: int = int(dishes_completed) * seconds_lived * int(highest_combo)

	if score < 0:
		score = 0

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

func _format_time_mmss(t: float) -> String:
	var total_seconds := int(t)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

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
