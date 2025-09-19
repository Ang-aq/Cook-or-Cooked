extends Node2D

@onready var ingredient_scene: PackedScene = preload("res://VersusScenes/versus_ingredient.tscn")
@onready var DishMiniScene: PackedScene = preload("res://VersusScenes/dish_mini.tscn")

# UI nodes (set in scene)
@onready var fade_rect: ColorRect = $CanvasLayer/TutorialScreen/ColorRect
@onready var checklist_p1: Control = $CanvasLayer/ChecklistP1
@onready var checklist_p2: Control = $CanvasLayer/ChecklistP2
@onready var player_input_p1: Node = $CanvasLayer/PlayerInputP1
@onready var player_input_p2: Node = $CanvasLayer/PlayerInputP2
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var timer_label: Label = $CanvasLayer/TimerLabel
@onready var tutorial_screen: Control = $CanvasLayer/TutorialScreen
@onready var tutorial_anim: AnimatedSprite2D = $CanvasLayer/TutorialScreen/AnimatedSprite2D
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel
@onready var dish_mini_p1: Control = $CanvasLayer/DishMiniP1
@onready var dish_mini_p2: Control = $CanvasLayer/DishMiniP2
@onready var powerup_popup_layer: CanvasLayer = $CanvasLayer
@onready var speed_label: Label = $CanvasLayer/SlideLabel

@export var spawn_interval: float = 0.8
@export var spawn_min_x: float = -300.0
@export var spawn_max_x: float = 300.0
@export var spawn_start_y: float = -100.0
var spawn_timer: float = 0.0
@export var start_fall_speed: float = 100
@export var end_fall_speed: float = 150
@export var round_time: float = 90.0   

# Speed system
@export var speed_increase_interval: float = 30.0 
var _current_speed_stage: int = 0
var _max_speed_stages: int = 1
var _speed_thresholds: Array = []     
var _time_thresholds: Array = []
var _triggered_time_events: Array = []   
var _countdown_started: bool = false

# Game Finished!
@onready var win_screen: Control = $CanvasLayer/WinScreen
@onready var win_label: Label = $CanvasLayer/WinScreen/WinLabel
@onready var rematch_button: Button = $CanvasLayer/WinScreen/RematchButton
@onready var menu_button: Button = $CanvasLayer/WinScreen/MenuButton
@onready var powerup_label: Label = $CanvasLayer/PowerupLabel
var _powerup_tween: Tween
var sudden_death_active: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var time_left: float = 0.0
var gameplay_paused: bool = false

# hearts
@export var lives_per_player: int = 6   
@onready var hearts_p1: HBoxContainer = $CanvasLayer/HeartsP1
@onready var hearts_p2: HBoxContainer = $CanvasLayer/HeartsP2

@onready var tex_heart_full: Texture2D = preload("res://Sprites/HeartFull.png")
@onready var tex_heart_half: Texture2D = preload("res://Sprites/HeartHalf2.png")
@onready var tex_heart_empty: Texture2D = preload("res://Sprites/blank3.png")

var lives: Dictionary = {1: lives_per_player, 2: lives_per_player}

# power-ups
@onready var powerup_scene: PackedScene = preload("res://VersusScenes/versus_powerup.tscn")
@export var powerup_spawn_interval_min: float = 8.0
@export var powerup_spawn_interval_max: float = 12.0
var powerup_spawn_timer: float = 0.0
var POWERUP_TYPES: Array = ["heart_breaker", "dish_snatcher", "extra_life", "mystery"]
var POWERUP_WEIGHTS: Array = [20, 10, 20, 50] 
var _during_fade: bool = false
var tutorial_shown := false

var dish_list: Array = [
	# Dish 1
	{"Scallion":  {"count":2, "combo": ["←","↓","Z"]},
	 "Meat":   {"count":2,"combo": ["→","↑","Z"]},
	},
	# Dish 2
	{"Carrot": {"count":2, "combo":["↑","Z"]},
	 "Meat": {"count":2, "combo":["←","→","Z"]}
	},
	# Dish 3
	{"Tomato": {"count":3, "combo":["→","→","Z"]}, 
	"Onion": {"count":2, "combo":["↓","Z"]}
	},
	# Dish 4
	{"Potato": {"count":1,"combo": ["↑","↓","Z"]},
	"Carrot": {"count":1, "combo": ["↑","↑","↑","Z"],},
	"Onion":  {"count":1, "combo": ["←","→","↓","Z"]}
	}
]

var dish_meta: Array = [
	{"name":"Yakitori", "texture": preload("res://Sprites/Ingredients/yakitori.png")},
	{"name":"Beef Curry", "texture": preload("res://Sprites/Ingredients/beefCurry.png")},
	{"name":"Shrimp Curry", "texture": preload("res://Sprites/Ingredients/shrimpCurry.png")},
	{"name":"Sinigang!?", "texture": preload("res://Sprites/Sinigang.png")} 
]

var powerup_spawn_points: Array = [
	Vector2(300, 150),
	Vector2(400, 150),
	Vector2(600, 150),
	Vector2(700, 150),
	Vector2(800, 150)
]

var sudden_death_dish: Dictionary = {
	"Carrot": {"count":4, "combo": ["←","↓","→","↑","Z"]},
	"Meat": {"count":4, "combo": ["→","→","↑","↑","Z"]},
	"Tomato": {"count":3, "combo": ["↓","↓","←","→","Z"]},
	"Onion": {"count":3, "combo": ["↑","↓","←","→","Z"]}
}

var sudden_death_meta: Dictionary = {
	"name": "Super Beef Curry",
	"texture": preload("res://Sprites/Ingredients/beefCurry.png")
}

var current_dish_index: Dictionary = {1: 0, 2: 0}
var collected_counts: Dictionary = {1: {}, 2: {}}
var dishes_completed: Dictionary = {1: 0, 2: 0}

var reserved_map: Dictionary = {}  

func _ready() -> void:
	fade_rect.modulate.a = 1.0   
	fade_rect.visible = true
	await fade_in(0.5)
	
	lives[1] = lives_per_player
	lives[2] = lives_per_player
	_update_player_hearts_ui(1)
	_update_player_hearts_ui(2)
	
	rng.randomize()
	spawn_timer = spawn_interval
	time_left = round_time
	_update_timer_label()
	
	_init_speed_system()
	
	dish_mini_p1 = DishMiniScene.instantiate() as Control
	dish_mini_p2 = DishMiniScene.instantiate() as Control
	$CanvasLayer.add_child(dish_mini_p1)
	$CanvasLayer.add_child(dish_mini_p2)
	dish_mini_p1.position = Vector2(33, 545) 
	dish_mini_p2.position = Vector2(1018, 545)
	
	if win_screen:
		win_screen.visible = false
		win_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if not is_in_group("Game"):
		add_to_group("Game")
	
	print("Checklist P1:", checklist_p1, "Checklist P2:", checklist_p2)
	print("PlayerInput P1:", player_input_p1, "PlayerInput P2:", player_input_p2)
	print("Ingredient container:", ingredient_container)
	
	_setup_checklist_for_player(1)
	_setup_checklist_for_player(2)
	
	if player_input_p1:
		if player_input_p1.has_signal("sequence_submitted"):
			player_input_p1.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
		if player_input_p1.has_signal("sequence_reset"):
			player_input_p1.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
		print("Connected P1 input signals")
	
	if player_input_p2:
		if player_input_p2.has_signal("sequence_submitted"):
			player_input_p2.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
		if player_input_p2.has_signal("sequence_reset"):
			player_input_p2.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
		print("Connected P2 input signals")
	
	if rematch_button:
		rematch_button.pressed.connect(Callable(self, "_on_rematch_button_pressed"))
		print("Connected rematch_button pressed signal")
	if menu_button:
		menu_button.pressed.connect(Callable(self, "_on_menu_button_pressed"))
		print("Connected menu_button pressed signal")
	
	gameplay_paused = true
	
	_show_tutorial()
	powerup_spawn_timer = rng.randf_range(powerup_spawn_interval_min, powerup_spawn_interval_max)

func _process(delta: float) -> void:
	if not gameplay_paused:
		if time_left > 0:
			time_left -= delta
			if time_left <= 0:
				time_left = 0
				_end_round()
			_update_timer_label()
		
		_maybe_check_time_events()
		
		var current_speed: float = get_current_fall_speed()
		for node in ingredient_container.get_children():
			if is_instance_valid(node) and node is Ingredient and not node.is_chopped:
				node.set_fall_speed(current_speed)
		
		# handle ingredient spawning timer
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_try_spawn_ingredient()
			spawn_timer = spawn_interval
			
		# handle powerup spawn timer (less frequent than ingredients)
		powerup_spawn_timer -= delta
		if powerup_spawn_timer <= 0.0:
			_try_spawn_powerup()
			powerup_spawn_timer = rng.randf_range(powerup_spawn_interval_min, powerup_spawn_interval_max)
	
	if win_screen and win_screen.visible:
		if Input.is_action_just_pressed("joystickStart"):
			if rematch_button:
				_on_rematch_button_pressed()
		if Input.is_action_just_pressed("joystickReset"):
			if menu_button:
				_on_menu_button_pressed()

func _try_spawn_powerup() -> void:
	if rng.randf() > 0.5:
		_spawn_powerup()

func _spawn_powerup() -> void:
	var powerup := powerup_scene.instantiate() as VersusPowerUp
	ingredient_container.add_child(powerup)
	var spawn_point = powerup_spawn_points.pick_random()
	powerup.position = spawn_point
	
	var chosen: String = _pick_weighted(POWERUP_TYPES, POWERUP_WEIGHTS)
	print("[DEBUG] Spawning powerup type: ", chosen)
	powerup.powerup_type = chosen
	powerup._refresh_visuals() 

func _spawn_powerup_popup(player_id: int, text: String) -> void:
	powerup_label.text = text
	powerup_label.modulate.a = 1.0
	powerup_label.visible = true
	
	var tween := create_tween()
	tween.tween_property(powerup_label, "position:y", powerup_label.position.y - 50, 0.8)
	tween.tween_property(powerup_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): 
		powerup_label.visible = false)

func _pick_weighted(items: Array, weights: Array) -> Variant:
	if items.size() == 0:
		return ""
	if items.size() != weights.size():
		return items[0]
	var total: int = 0
	
	for w in weights:
		total += int(w)
	var r: int = rng.randi_range(0, total - 1)
	var acc: int = 0
	
	for i in range(items.size()):
		acc += int(weights[i])
		if r < acc:
			return items[i]
	return items[items.size() - 1]

func _init_speed_system() -> void:
	_max_speed_stages = max(1, int(ceil(round_time / speed_increase_interval)))
	_current_speed_stage = 0
	_triggered_time_events.clear()
	_speed_thresholds.clear()
	_time_thresholds.clear()
	_countdown_started = false
	
	var k: int = 1
	while true:
		var t := round_time - (k * speed_increase_interval)
		if t <= 0:
			break
		_speed_thresholds.append(int(round(t)))
		k += 1

	var extras := [60, 30, 10, 5]
	for e in extras:
		if round_time >= e and not _time_thresholds.has(int(e)):
			_time_thresholds.append(int(e))

	_time_thresholds.append_array(_speed_thresholds)
	_time_thresholds = _time_thresholds.duplicate(true)
	_time_thresholds.sort() # ascending
	var rev: Array = []
	for i in range(_time_thresholds.size() - 1, -1, -1):
		rev.append(_time_thresholds[i])
	_time_thresholds = rev

func _maybe_check_time_events() -> void:
	if _time_thresholds.size() == 0:
		return

	for threshold in _time_thresholds:
		var tval: float = float(threshold)
		if time_left <= tval and not _triggered_time_events.has(threshold):
			_triggered_time_events.append(threshold)
			if _speed_thresholds.has(threshold):
				_current_speed_stage += 1
				if _current_speed_stage > _max_speed_stages:
					_current_speed_stage = _max_speed_stages
				if int(threshold) == 60:
					_show_slide_label("60 minute left!")
				elif int(threshold) == 30:
					_show_slide_label("30 seconds left!")
				else:
					_show_slide_label("%d seconds left!" % int(threshold))
				MusicManager.play_sfx("level_up")
			else:
				match int(threshold):
					10:
						_show_popup("10 seconds left")
					5:
						if not _countdown_started:
							_countdown_started = true
							call_deferred("_start_final_countdown")
					_:
						_show_popup("%d seconds left" % int(ceil(threshold)))
			break

func get_current_fall_speed() -> float:
	var ratio: float = 0.0
	if _max_speed_stages > 0:
		ratio = clamp(float(_current_speed_stage) / float(_max_speed_stages), 0.0, 1.0)
	return lerp(start_fall_speed, end_fall_speed, ratio)

func _show_popup(text: String, hold_time: float = 0.8, fade_time: float = 1.2) -> void:

	if powerup_label == null:
		return
	powerup_label.text = text
	powerup_label.visible = true
	var c: Color = powerup_label.modulate
	c.a = 1.0
	powerup_label.modulate = c
	var tween: Tween = create_tween()
	tween.tween_property(powerup_label, "position:y", powerup_label.position.y - 40, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(hold_time)
	tween.tween_property(powerup_label, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		if powerup_label:
			powerup_label.visible = false
			powerup_label.text = "")

func _show_slide_label(text: String, hold_time: float = 0.9, enter_time: float = 0.35, exit_time: float = 0.35) -> void:
	var label_node: Label = speed_label 
	label_node.text = text
	label_node.visible = true
	await RenderingServer.frame_post_draw
	
	var vp := get_viewport_rect().size
	var min_size: Vector2 = label_node.get_minimum_size()
	var label_w: float = max(1.0, min_size.x)   
	var label_h: float = max(1.0, min_size.y)
	
	var start_x: float = -label_w - 20.0
	var target_x: float = (vp.x - label_w) * 0.5
	var end_x: float = vp.x + 20.0
	
	var target_y: float = (vp.y - label_h) * 0.5
	
	var gp: Vector2 = label_node.global_position
	gp.x = start_x
	gp.y = target_y
	label_node.global_position = gp

	#  text slides in, stops, slides out
	var tween: Tween = create_tween()
	tween.tween_property(label_node, "global_position:x", target_x, enter_time).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(hold_time)
	tween.tween_property(label_node, "global_position:x", end_x, exit_time).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		if label_node:
			label_node.visible = false
			label_node.text = "")

func _start_final_countdown() -> void: 
	if countdown_label == null:
		return
	countdown_label.visible = true
	var start_num: int = min(5, int(ceil(time_left)))
	
	for i in range(start_num, 0, -1):
		countdown_label.text = str(i)
		if countdown_label.text == "3":
			MusicManager.play_sfx("countdown")
		await get_tree().create_timer(1.0).timeout
	countdown_label.visible = false

func fade_out(time: float = 1.0) -> void:
	_during_fade = true
	fade_rect.visible = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, time).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	_during_fade = false

func fade_in(time: float = 1.0) -> void:
	_during_fade = true
	fade_rect.visible = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	fade_rect.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, time).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	
	fade_rect.visible = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_during_fade = false

func _show_tutorial() -> void:
	tutorial_anim.play("tutorial")
	if tutorial_screen:
		tutorial_screen.visible = true
		tutorial_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	
	tutorial_shown = true
	gameplay_paused = true
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(false)
		node.set_physics_process(false)

func _hide_tutorial():
	MusicManager.stop_bgm()
	tutorial_screen.visible = false
	tutorial_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_shown = false
	await _start_countdown()
	_resume_gameplay_nodes()
	gameplay_paused = false

func _unhandled_input(event):
	if _during_fade:
		return

	if tutorial_screen and tutorial_shown and tutorial_screen.visible and event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		_hide_tutorial()

func _start_countdown() -> void:
	
	MusicManager.play_sfx("countdown")
	countdown_label.visible = true
	gameplay_paused = true  
	var countdown_numbers: Array = [3, 2, 1]
	for number in countdown_numbers:
		countdown_label.text = str(number)
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(1.0).timeout
	
	countdown_label.text = "Go!"
	var title_music = preload("res://Audio/bgm.ogg")
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.5).timeout
	MusicManager.play_bgm(title_music, true)
	
	countdown_label.visible = false

func _resume_gameplay_nodes() -> void:
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(true)
		node.set_physics_process(true)

func _setup_checklist_for_player(player_id: int) -> void:
	var dish_index: int
	
	if dish_list.size() == 0:
		return  

	if current_dish_index[player_id] == -1:
		dish_index = rng.randi_range(0, dish_list.size() - 1)
		current_dish_index[player_id] = dish_index
	else:
		dish_index = current_dish_index[player_id]
	
	var dish: Dictionary = dish_list[dish_index]
	collected_counts[player_id] = {}
	
	var checklist = checklist_p1 if player_id == 1 else checklist_p2
	if checklist and checklist.has_method("setup_checklist"):
		var req_counts := {}
		for n in dish.keys():
			req_counts[n] = int(dish[n]["count"])
			collected_counts[player_id][n] = 0
		print("Setting up checklist for player %d: %s" % [player_id, req_counts])
		checklist.setup_checklist(req_counts)
	else:
		print("Checklist node missing or has no setup_checklist() for player", player_id)

func _try_spawn_ingredient() -> void:
	var weights: Dictionary = {}

	for pid in [1, 2]:
		var needed = _get_needed_counts(pid)
		for ing in needed.keys():
			weights[ing] = weights.get(ing, 1) + needed[ing] * 3  # give higher weight

	if weights.is_empty():
		for pid in [1, 2]:
			var idx = current_dish_index[pid]
			if idx < dish_list.size():
				for ing in dish_list[idx].keys():
					weights[ing] = 1

	var names = weights.keys()
	var weight_values: Array = []
	for ing in names:
		weight_values.append(weights[ing])

	var name: String = _pick_weighted(names, weight_values)
	_spawn_ingredient(name)

func _spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	if ing_node == null:
		push_error("Failed to instantiate ingredient scene")
		return
	
	ingredient_container.add_child(ing_node)
	ing_node.position = Vector2(rng.randf_range(spawn_min_x, spawn_max_x), spawn_start_y)
	
	ing_node.set_fall_speed(get_current_fall_speed())
	
	var combo: Array = []
	for dish in dish_list:
		if dish.has(ingredient_name):
			combo = dish[ingredient_name].get("combo", [])
			break
	
	if ing_node.has_method("set_combo_and_name"):
		ing_node.set_combo_and_name(combo.duplicate(true), ingredient_name)
	
	if ing_node.has_signal("chop_completed"):
		ing_node.chop_completed.connect(Callable(self, "_on_ingredient_chopped"))
	
	var node_name = ing_node.name
	var anim_exists = ing_node.has_node("AnimatedSprite2D") or ing_node.has_node("Sprite2D")
	print("Spawned ingredient:", ingredient_name, "node:", node_name, "combo:", combo, "anim_exists:", anim_exists)

# player input
func _on_sequence_submitted(sequence: Array, player_id: int) -> void:
	print("Sequence submitted by P%d: %s" % [player_id, str(sequence)])
	var clean_sequence = sequence.duplicate()
	var matched := false

	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		if not (node is Ingredient):
			continue
		if node.is_chopped:
			continue
		
		if node.combo is Array and node.combo.size() == clean_sequence.size():
			var eq := true
			for j in range(clean_sequence.size()):
				if str(clean_sequence[j]) != str(node.combo[j]):
					eq = false
					break
			
			if eq:
				if node.has_method("reserve") and node.reserve(player_id):
					reserved_map[node] = player_id
					print("Reserved ingredient %s for player %d" % [node.name, player_id])
					
					if node.has_method("play_slash_sequence"):
						node.play_slash_sequence(clean_sequence)
					
					matched = true
					break
				else:
					print("Ingredient %s already reserved" % node.name)
					break
	
	if not matched:
		for i in range(ingredient_container.get_child_count() - 1, -1, -1):
			var node = ingredient_container.get_child(i)
			if not is_instance_valid(node):
				continue
			if not (node is VersusPowerUp):
				continue
				
			if node.combo is Array and node.combo.size() == clean_sequence.size():
				var eq := true
				for j in range(clean_sequence.size()):
					if str(clean_sequence[j]) != str(node.combo[j]):
						eq = false
						break

				if eq:
					if node.has_method("reserve") and node.reserve(player_id):
						print("Player %d activated powerup %s" % [player_id, node.powerup_type])
						if node.has_method("play_slash_sequence"):
							node.play_slash_sequence(clean_sequence)
						matched = true
						break
					else:
						print("Powerup %s already reserved" % node.name)
						break
	
	if not matched:
		_lose_half_heart(player_id, "Wrong combo!")
		print("Player %d wrong combo -> lost half heart" % player_id)
	
	_clear_player_input(player_id)

func _on_sequence_reset(player_id: int) -> void:
	print("Versus: player %d reset input" % player_id)

func _clear_player_input(player_id: int) -> void:
	if player_id == 1 and player_input_p1:
		input_player_clear(player_input_p1)
	elif player_id == 2 and player_input_p2:
		input_player_clear(player_input_p2)

func input_player_clear(player_input_node: Node) -> void:
	if "input_buffer" in player_input_node:
		player_input_node.input_buffer.clear()
	player_input_node._update_display()

# ingredients 
func _on_ingredient_chopped(ingredient_name: String) -> void:
	print("Ingredient chopped signal:", ingredient_name)
	var credited_player: int = 0
	var target_node: Node2D = null

	for node in reserved_map.keys():
		if not is_instance_valid(node):
			continue
		if not (node is Ingredient):
			continue
		if node.ingredient_name == ingredient_name and node.is_chopped:
			if node.has_method("get_reserved_player"):
				credited_player = node.get_reserved_player()
			else:
				credited_player = int(reserved_map.get(node, 0))
			target_node = node
			break
	
	if credited_player == 0:
		for i in range(ingredient_container.get_child_count() - 1, -1, -1):
			var n = ingredient_container.get_child(i)
			if not is_instance_valid(n):
				continue
			if not (n is Ingredient):
				continue
			if n.ingredient_name == ingredient_name and n.is_chopped:
				target_node = n
				break
	
	if target_node == null:
		print("Versus: chopped but couldn't find target_node for", ingredient_name)
		return
	
	if credited_player == 0:
		print("Versus: no credited player for chopped ingredient", ingredient_name)
		if target_node.has_method("flash_x"):
			target_node.flash_x()
		if reserved_map.has(target_node):
			reserved_map.erase(target_node)
		return
	
	# get current dish safely
	var dish_index = current_dish_index.get(credited_player, -1)
	if dish_index < 0 or dish_index >= dish_list.size():
		print("Invalid dish index for player", credited_player)
		return
	
	var dish: Dictionary = dish_list[dish_index]
	if not dish.has(ingredient_name):
		# Ingredient not required for this dish
		print("Ingredient %s not in current dish for player %d" % [ingredient_name, credited_player])
		if target_node.has_method("flash_x"):
			target_node.flash_x()
		if reserved_map.has(target_node):
			reserved_map.erase(target_node)
		# penalize credited player for adding wrong ingredient
		if credited_player > 0:
			_lose_half_heart(credited_player, "Wrong ingredient!")
		return
	
	
	var prev: int = collected_counts[credited_player].get(ingredient_name, 0)
	var req: int = int(dish[ingredient_name]["count"])

	if prev >= req:
		# too many of that ingredient
		if target_node.has_method("flash_x"):
			target_node.flash_x()
		print("Versus: Player %d tried to add too many %s" % [credited_player, ingredient_name])
		if credited_player > 0:
			_lose_half_heart(credited_player, "Too many %s!" % ingredient_name)
	else:
		# credit the ingredient
		collected_counts[credited_player][ingredient_name] = prev + 1
		var checklist = checklist_p1 if credited_player == 1 else checklist_p2
		if checklist and checklist.has_method("update_progress"):
			checklist.update_progress(ingredient_name, collected_counts[credited_player][ingredient_name])
	
	# check if dish is finished
	var finished: bool = true
	for name in dish.keys():
		if collected_counts[credited_player].get(name, 0) < int(dish[name]["count"]):
			finished = false
			break
	if finished:
		_on_player_finished_dish(credited_player)
	
	if reserved_map.has(target_node):
		reserved_map.erase(target_node)

func _on_player_finished_dish(player_id: int) -> void:
	# increment count
	if sudden_death_active:
		_end_sudden_death(player_id)
		return
	dishes_completed[player_id] += 1
	print("Player %d finished a dish! Total completed: %d" % [player_id, dishes_completed[player_id]])
	
	var idx: int = current_dish_index.get(player_id, 0)
	var meta: Dictionary = {}
	if idx >= 0 and idx < dish_meta.size():
		meta = dish_meta[idx]
	
	if meta != null:
		var dish_texture: Texture2D = meta.get("texture", null)
		var dish_name: String = str(meta.get("name", "Dish"))
		if player_id == 1 and dish_mini_p1:
			if dish_mini_p1.has_method("show_dish"):
				dish_mini_p1.show_dish(dish_texture, dish_name)
		elif player_id == 2 and dish_mini_p2:
			if dish_mini_p2.has_method("show_dish"):
				dish_mini_p2.show_dish(dish_texture, dish_name)
	
	MusicManager.play_sfx("level_up")
	
	if dish_list.size() > 0:
		var new_index = rng.randi_range(0, dish_list.size() - 1)
		current_dish_index[player_id] = new_index
		print("Player %d new dish index: %d" % [player_id, new_index])
	else:
		print("No dishes defined in dish_list!")
		return

	collected_counts[player_id] = {}
	var new_dish: Dictionary = dish_list[current_dish_index[player_id]]
	for ingredient_name in new_dish.keys():
		collected_counts[player_id][ingredient_name] = 0

	var checklist = checklist_p1 if player_id == 1 else checklist_p2
	if checklist and checklist.has_method("setup_checklist"):
		var req_counts: Dictionary = {}
		for ingredient_name in new_dish.keys():
			req_counts[ingredient_name] = int(new_dish[ingredient_name]["count"])
		print("Updating checklist for player %d: %s" % [player_id, req_counts])
		checklist.setup_checklist(req_counts)
	else:
		print("Checklist node missing or has no setup_checklist() for player", player_id)

#region Endgame
func _end_round() -> void:
	gameplay_paused = true
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(false)
		node.set_physics_process(false)
		
	var message := ""
	if dishes_completed[1] > dishes_completed[2]:
		message = "Player 1 Wins!"
	elif dishes_completed[2] > dishes_completed[1]:
		message = "Player 2 Wins!"
	else:
		_start_sudden_death()
		return
	print(message)
	
	if win_screen and win_label:
		win_label.text = message
		win_screen.visible = true
		win_screen.mouse_filter = Control.MOUSE_FILTER_STOP 
		
		if win_screen.has_method("move_to_front"):
			win_screen.move_to_front() 
		elif win_screen.has_method("raise"):
			win_screen.raise()
		else:
		
			var parent = win_screen.get_parent()
			if parent:
				parent.move_child(win_screen, parent.get_child_count() - 1)
		
		print("Win screen shown and brought to front")

func _start_sudden_death() -> void:
	sudden_death_active = true
	time_left = 0 # no timer
	_show_slide_label("SUDDEN DEATH")
	
	# Clear current dishes
	current_dish_index[1] = -1
	current_dish_index[2] = -1
	collected_counts[1].clear()
	collected_counts[2].clear()
	
	var sudden_dish_index: int = 0
	_assign_dish_to_player(1, sudden_dish_index)
	_assign_dish_to_player(2, sudden_dish_index)
	
	# Reset UI checklist for both
	_setup_checklist_for_player(1)
	_setup_checklist_for_player(2)
	
	gameplay_paused = false

func _assign_dish_to_player(player_id: int, dish_index: int) -> void:
	current_dish_index[player_id] = dish_index
	collected_counts[player_id].clear()
	
	var new_dish: Dictionary = dish_list[dish_index]
	for ingredient_name in new_dish.keys():
		collected_counts[player_id][ingredient_name] = 0
	
	var checklist = checklist_p1 if player_id == 1 else checklist_p2
	if checklist and checklist.has_method("setup_checklist"):
		var req_counts: Dictionary = {}
		for ingredient_name in new_dish.keys():
			req_counts[ingredient_name] = int(new_dish[ingredient_name]["count"])
		print("Assigning dish to player %d: %s" % [player_id, req_counts])
		checklist.setup_checklist(req_counts)
	
func _end_sudden_death(winner_id: int) -> void:
	gameplay_paused = true
	sudden_death_active = false
	_show_winner(winner_id)

func _show_winner(winner_id: int = -1) -> void:
	var winner = winner_id
	if winner == -1:
		if dishes_completed[1] > dishes_completed[2]:
			winner = 1
		else:
			winner = 2

	win_screen.visible = true
	win_label.text = "Player %d Wins!" % winner
#endregion

func _update_timer_label() -> void:
	if timer_label:
		timer_label.text = str(int(ceil(time_left)))

func _on_rematch_button_pressed() -> void:
	print("_on_rematch_button_pressed() called")
	await fade_out(0.5)
	var err = get_tree().change_scene_to_file("res://VersusScenes/versus_main.tscn")
	if err != OK:
		push_error("Failed to change to versus_main.tscn (err %s)" % str(err))

func _on_menu_button_pressed() -> void:
	print("_on_menu_button_pressed() called")
	await fade_out(0.5)
	get_tree().change_scene_to_file("res://Scenes/titlescreen.tscn")

func _update_player_hearts_ui(player_id: int) -> void:
	var container: HBoxContainer = hearts_p1 if player_id == 1 else hearts_p2
	if container == null:
		return
	
	var total_lives: int = int(lives.get(player_id, lives_per_player))
	
	for i in range(3):
		if i >= container.get_child_count():
			continue
		var heart_sprite := container.get_child(i) as TextureRect
		if heart_sprite == null:
			continue
		
		var lives_for_heart: int = clamp(total_lives - (i * 2), 0, 2)
		match lives_for_heart:
			2:
				heart_sprite.texture = tex_heart_full
				heart_sprite.visible = true
			1:
				heart_sprite.texture = tex_heart_half
				heart_sprite.visible = true
			_:
				heart_sprite.texture = tex_heart_empty
				heart_sprite.visible = true

func _lose_half_heart(player_id: int, reason: String = "") -> void:
	if not lives.has(player_id):
		lives[player_id] = lives_per_player
	lives[player_id] = max(0, lives[player_id] - 1)
	
	MusicManager.play_sfx("wrong")
	
	_update_player_hearts_ui(player_id)
	
	var heart_index: int = clamp(int(lives[player_id] / 2), 0, 2)
	var container := hearts_p1 if player_id == 1 else hearts_p2
	if container and heart_index < container.get_child_count():
		var theart := container.get_child(heart_index) as TextureRect
		if theart:
			var tween := create_tween()
			tween.tween_property(theart, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(theart, "scale", Vector2(1, 1), 0.12).set_delay(0.08)

	if lives[player_id] <= 0:
		_on_player_eliminated(player_id)
	
func _on_player_eliminated(player_id: int) -> void:
	var winner := 2 if player_id == 1 else 1

	gameplay_paused = true
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(false)
		node.set_physics_process(false)
	
	if win_label:
		win_label.text = "Player %d Wins!" % winner
	if win_screen:
		win_screen.visible = true
		win_screen.mouse_filter = Control.MOUSE_FILTER_STOP
		var parent := win_screen.get_parent()
		if parent:
			parent.move_child(win_screen, parent.get_child_count() - 1)

func _show_powerup_label(text: String, fade_time: float = 1.5, hold_time: float = 0.6) -> void:
	if _powerup_tween != null and _powerup_tween.is_valid():
		_powerup_tween.kill()
		_powerup_tween = null
	
	if powerup_label == null:
		return
	powerup_label.text = text
	powerup_label.visible = true
	var c = powerup_label.modulate
	c.a = 1.0
	powerup_label.modulate = powerup_label.modulate
	
	_powerup_tween = create_tween()
	_powerup_tween.tween_callback(Callable(self, "_noop")) 
	_powerup_tween.tween_interval(hold_time)
	_powerup_tween.tween_property(powerup_label, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_LINEAR)
	_powerup_tween.tween_callback(Callable(self, "_on_powerup_label_faded"))

func _noop() -> void:
	# noop! 
	pass

func _on_powerup_label_faded() -> void:
	if powerup_label:
		powerup_label.visible = false
		powerup_label.text = ""
	_powerup_tween = null

func _on_powerup_collected(player_id: int, powerup_type: String) -> void:
	var short = powerup_type.capitalize().replace("_", " ")
	var text = "P%d: %s" % [player_id, short]
	_show_powerup_label(text)

func _get_needed_counts(player_id: int) -> Dictionary:
	var needed: Dictionary = {}
	if current_dish_index[player_id] < dish_list.size():
		var dish: Dictionary = dish_list[current_dish_index[player_id]]
		for ing in dish.keys():
			var required: int = dish[ing]["count"]
			var have: int = collected_counts[player_id].get(ing, 0)
			if have < required:
				needed[ing] = required - have
	return needed
