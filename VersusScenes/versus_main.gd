# res://Scripts/VersusMain.gd
extends Node2D

# reuse the versus ingredient scene (duplicate of your original ingredient scene)
@onready var ingredient_scene: PackedScene = preload("res://VersusScenes/versus_ingredient.tscn")

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
var tutorial_shown := true 
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel

# Tunables
@export var spawn_interval: float = 0.8
@export var spawn_min_x: float = -300.0
@export var spawn_max_x: float = 300.0
@export var spawn_start_y: float = -100.0
@export var round_time: float = 90.0   # length of round

# Game Finished!
@onready var win_screen: Control = $CanvasLayer/WinScreen
@onready var win_label: Label = $CanvasLayer/WinScreen/WinLabel
@onready var rematch_button: Button = $CanvasLayer/WinScreen/RematchButton
@onready var menu_button: Button = $CanvasLayer/WinScreen/MenuButton

# State
var spawn_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var time_left: float = 0.0
var gameplay_paused: bool = false

# HEARTS (versus mode: internal 6 lives per player, show 3 hearts UI)
@export var lives_per_player: int = 6   # real lives (6 halves)
@onready var hearts_p1: HBoxContainer = $CanvasLayer/HeartsP1
@onready var hearts_p2: HBoxContainer = $CanvasLayer/HeartsP2

# preload heart textures (adjust paths to your project)
@onready var tex_heart_full: Texture2D = preload("res://Sprites/HeartFull.png")
@onready var tex_heart_half: Texture2D = preload("res://Sprites/HeartHalf2.png")
@onready var tex_heart_empty: Texture2D = preload("res://Sprites/blank3.png")

# actual lives state (1..6 for each player)
var lives: Dictionary = {1: lives_per_player, 2: lives_per_player}

var dish_list: Array = [
	# Dish 1
	{"Tomato": {"count":3, "combo":["→","→","Z"]}, 
	"Onion": {"count":2, "combo":["↓","Z"]}
	},
	# Dish 2
	{"Carrot": {"count":2, "combo":["↑","Z"]},
	 "Meat": {"count":2, "combo":["←","→","Z"]}
	},
	# Dish 3
	{"Spring Onion":  {"count":2, "combo": ["←","↓","Z"]},
	 "Meat":   {"count":2,"combo": ["→","↑","Z"]},
	},
	# Dish 4
	{"Potato": {"count":1,"combo": ["↑","↓","Z"]},
	"Carrot": {"count":1, "combo": ["↑","↑","↑","Z"],},
	"Onion":  {"count":1, "combo": ["←","→","↓","Z"]}
	}
]

var current_dish_index: Dictionary = {1: 0, 2: 0}
var collected_counts: Dictionary = {1: {}, 2: {}}
var dishes_completed: Dictionary = {1: 0, 2: 0}

# Reservations
var reserved_map: Dictionary = {}  # ingredient_node -> player_id

func _ready() -> void:
	fade_rect.modulate.a = 1.0   # start fully black
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
	
	# Background music
	var bgm = preload("res://Audio/bgm.ogg")
	MusicManager.play_bgm(bgm, true)
	
	# Initialize win screen
	if win_screen:
		win_screen.visible = false
		win_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Ensure VersusMain is in "Game" group (for Ingredient nodes to find it)
	if not is_in_group("Game"):
		add_to_group("Game")

	# Debug: verify UI node wiring
	print("--- VersusMain ready ---")
	print("Checklist P1:", checklist_p1, "Checklist P2:", checklist_p2)
	print("PlayerInput P1:", player_input_p1, "PlayerInput P2:", player_input_p2)
	print("Ingredient container:", ingredient_container)

	# Setup initial checklists
	_setup_checklist_for_player(1)
	_setup_checklist_for_player(2)

	# Connect player input signals (ensure PlayerInput nodes are correct type)
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

	# Connect win screen buttons
	if rematch_button:
		rematch_button.pressed.connect(Callable(self, "_on_rematch_button_pressed"))
		print("Connected rematch_button pressed signal")
	if menu_button:
		menu_button.pressed.connect(Callable(self, "_on_menu_button_pressed"))
		print("Connected menu_button pressed signal")

	# --- IMPORTANT FIX ---
	# Prevent round timer and spawns from running until tutorial + countdown are done
	gameplay_paused = true

	# Show tutorial immediately on match start
	_show_tutorial()

func _process(delta: float) -> void:
	# -----------------
	# Handle gameplay if not paused
	# -----------------
	if not gameplay_paused:
		# Timer
		if time_left > 0:
			time_left -= delta
			if time_left <= 0:
				time_left = 0
				_end_round()
			_update_timer_label()

		# Spawning
		spawn_timer -= delta
		if spawn_timer <= 0:
			_try_spawn_ingredient()
			spawn_timer = spawn_interval

	# -----------------
	# Handle win screen input regardless of pause
	# -----------------
	if win_screen and win_screen.visible:
		if Input.is_action_just_pressed("joystickStart"): # Z
			if rematch_button:
				_on_rematch_button_pressed()
		if Input.is_action_just_pressed("joystickReset"): # X
			if menu_button:
				_on_menu_button_pressed()

func fade_out(time: float = 1.0) -> void:
	fade_rect.visible = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = timer / time
		await RenderingServer.frame_post_draw  # wait one frame safely
	fade_rect.modulate.a = 1.0


func fade_in(time: float = 1.0) -> void:
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = 1.0 - (timer / time)
		await RenderingServer.frame_post_draw
	fade_rect.modulate.a = 0.0
	fade_rect.visible = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
# Tutorial UI
func _show_tutorial() -> void:
	if tutorial_screen:
		tutorial_screen.visible = true
		if tutorial_anim:
			tutorial_anim.play("tutorial")
			print("Tutorial animation started")
	
	tutorial_shown = true
	gameplay_paused = true  # freeze game

	# Pause gameplay nodes
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(false)
		node.set_physics_process(false)

func _hide_tutorial():
	tutorial_screen.visible = false
	tutorial_shown = false

	# Start countdown AFTER tutorial closes
	await _start_countdown()

	# Now unpause gameplay
	_resume_gameplay_nodes()
	gameplay_paused = false

func _unhandled_input(event):
	if tutorial_screen.visible and event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton):
		_hide_tutorial()

func _start_countdown() -> void:
	countdown_label.visible = true
	gameplay_paused = true  # still paused during countdown

	var countdown_numbers: Array = [3, 2, 1]
	for number in countdown_numbers:
		countdown_label.text = str(number)
		await RenderingServer.frame_post_draw
		await get_tree().create_timer(1.0).timeout

	countdown_label.text = "Go!"
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(0.5).timeout

	countdown_label.visible = false
	# DO NOT unpause here — _hide_tutorial() will do that after countdown finishes

func _resume_gameplay_nodes() -> void:
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(true)
		node.set_physics_process(true)

# Checklist setup per player
func _setup_checklist_for_player(player_id: int) -> void:
	var dish_index: int
	
	if dish_list.size() == 0:
		return  # no dishes defined

	# Pick a random dish from the list
	dish_index = rng.randi_range(0, dish_list.size() - 1)
	current_dish_index[player_id] = dish_index

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

# Spawning helpers
func _try_spawn_ingredient() -> void:
	# Build pool of active ingredients from both players' current dishes
	var active_names: Array = []
	for pid in [1, 2]:
		var idx = current_dish_index[pid]
		if idx < dish_list.size():
			active_names.append_array(dish_list[idx].keys())

	if active_names.is_empty():
		return

	var name: String = active_names[rng.randi() % active_names.size()]
	_spawn_ingredient(name)

func _spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	if ing_node == null:
		push_error("Failed to instantiate ingredient scene")
		return

	# Add to the world (not UI)
	ingredient_container.add_child(ing_node)
	ing_node.position = Vector2(rng.randf_range(spawn_min_x, spawn_max_x), spawn_start_y)

	# find combo from dish_list (prefer current dish combos)
	var combo: Array = []
	for dish in dish_list:
		if dish.has(ingredient_name):
			combo = dish[ingredient_name].get("combo", [])
			break

	if ing_node.has_method("set_combo_and_name"):
		ing_node.set_combo_and_name(combo.duplicate(true), ingredient_name)

	if ing_node.has_signal("chop_completed"):
		ing_node.chop_completed.connect(Callable(self, "_on_ingredient_chopped"))

	# Debug: make sure the ingredient's sprite & animation exist and print combo
	var node_name = ing_node.name
	var anim_exists = ing_node.has_node("AnimatedSprite2D") or ing_node.has_node("Sprite2D")
	print("Spawned ingredient:", ingredient_name, "node:", node_name, "combo:", combo, "anim_exists:", anim_exists)

# ---------------------------
# Player input
# ---------------------------
func _on_sequence_submitted(sequence: Array, player_id: int) -> void:
	print("Sequence submitted by P%d: %s" % [player_id, str(sequence)])
	var clean_sequence = sequence.duplicate()
	var matched := false

	# iterate topmost first; only consider Ingredient-type nodes (safe property access)
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		# only handle Ingredient-derived nodes (your Ingredient.gd should ideally have `class_name Ingredient`)
		# If you don't use class_name, remove the `is Ingredient` check
		if not (node is Ingredient):
			continue
		# skip already chopped
		if node.is_chopped:
			continue

		# check combo (make sure both are strings for comparison)
		if node.combo is Array and node.combo.size() == clean_sequence.size():
			var eq := true
			for j in range(clean_sequence.size()):
				if str(clean_sequence[j]) != str(node.combo[j]):
					eq = false
					break

			if eq:
				# Reserve via VersusIngredient (this sets node.reserved_by)
				if node.has_method("reserve") and node.reserve(player_id):
					# store reservation locally for fallback lookup and bookkeeping
					reserved_map[node] = player_id
					print("Reserved node %s for player %d" % [node.name, player_id])

					# IMPORTANT: call the parent's play_slash_sequence signature (single arg).
					# VersusIngredient.play_slash_sequence will color the slash using node.reserved_by.
					if node.has_method("play_slash_sequence"):
						node.play_slash_sequence(clean_sequence)

					matched = true
					break
				else:
					# already reserved by other player
					print("Node %s already reserved" % node.name)
					break

	# feedback for wrong combo
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
	if player_input_node.has_method("_update_display"):
		player_input_node._update_display()

# ---------------------------
# Ingredient chopped handler
# ---------------------------
func _on_ingredient_chopped(ingredient_name: String) -> void:
	print("Ingredient chopped signal:", ingredient_name)
	var credited_player: int = 0
	var target_node: Node2D = null

	# look for reserved node first
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
	
	# fallback: topmost chopped ingredient (if reservation missed)
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
	
	# cleanup reservation
	if reserved_map.has(target_node):
		reserved_map.erase(target_node)

# ---------------------------
# Dish & round end logic
# ---------------------------
func _on_player_finished_dish(player_id: int) -> void:
	# Increment completed count
	dishes_completed[player_id] += 1
	print("Player %d finished a dish! Total completed: %d" % [player_id, dishes_completed[player_id]])
	
	# Pick a new random dish
	if dish_list.size() > 0:
		var new_index = rng.randi_range(0, dish_list.size() - 1)
		current_dish_index[player_id] = new_index
		print("Player %d new dish index: %d" % [player_id, new_index])
	else:
		print("No dishes defined in dish_list!")
		return
		
	# Reset collected counts for this player
	collected_counts[player_id] = {}
	var new_dish: Dictionary = dish_list[current_dish_index[player_id]]
	for ingredient_name in new_dish.keys():
		collected_counts[player_id][ingredient_name] = 0

	# Update the player's checklist UI
	var checklist = checklist_p1 if player_id == 1 else checklist_p2
	if checklist and checklist.has_method("setup_checklist"):
		var req_counts: Dictionary = {}
		for ingredient_name in new_dish.keys():
			req_counts[ingredient_name] = int(new_dish[ingredient_name]["count"])
		print("Updating checklist for player %d: %s" % [player_id, req_counts])
		checklist.setup_checklist(req_counts)
	else:
		print("Checklist node missing or has no setup_checklist() for player", player_id)

func _end_round() -> void:
	# Stop gameplay nodes
	gameplay_paused = true
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(false)
		node.set_physics_process(false)
		
	# Determine winner
	var message := ""
	if dishes_completed[1] > dishes_completed[2]:
		message = "Player 1 Wins!"
	elif dishes_completed[2] > dishes_completed[1]:
		message = "Player 2 Wins!"
	else:
		message = "Draw!"
	print(message)
	
	# Show win screen
	if win_screen and win_label:
		win_label.text = message
		win_screen.visible = true
		win_screen.mouse_filter = Control.MOUSE_FILTER_STOP  # let it capture clicks
		
		# Ensure win_screen is in front of other Controls
		if win_screen.has_method("move_to_front"):
			win_screen.move_to_front()  # Godot 4
		elif win_screen.has_method("raise"):
			win_screen.raise()  # Godot 3 fallback
		else:
			# fallback: reparent to end of siblings (highest draw order)
			var parent = win_screen.get_parent()
			if parent:
				parent.move_child(win_screen, parent.get_child_count() - 1)
		
		print("Win screen shown and brought to front")

func _update_timer_label() -> void:
	if timer_label:
		timer_label.text = str(int(ceil(time_left)))

func _on_rematch_button_pressed() -> void:
	print("_on_rematch_button_pressed() called")
	await fade_out(0.5)
	# Explicitly change to the versus scene file so it always reloads a fresh copy
	var err = get_tree().change_scene_to_file("res://VersusScenes/versus_main.tscn")
	if err != OK:
		push_error("Failed to change to versus_main.tscn (err %s)" % str(err))

func _on_menu_button_pressed() -> void:
	print("_on_menu_button_pressed() called")
	await fade_out(0.5)
	get_tree().change_scene_to_file("res://Scenes/titlescreen.tscn")

func _update_player_hearts_ui(player_id: int) -> void:
	# pick the correct HBox for this player
	var container: HBoxContainer = hearts_p1 if player_id == 1 else hearts_p2
	if container == null:
		return

	# total lives (0..lives_per_player)
	var total_lives: int = int(lives.get(player_id, lives_per_player))
	
	# update 3 on-screen hearts (each heart represents two internal "half-lives")
	for i in range(3):
		if i >= container.get_child_count():
			continue
		var heart_sprite := container.get_child(i) as TextureRect
		if heart_sprite == null:
			continue

		# compute how many half-lives this particular heart still has (0..2)
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
	# decrement by 1 (one half-heart)
	if not lives.has(player_id):
		lives[player_id] = lives_per_player
	lives[player_id] = max(0, lives[player_id] - 1)
	
	# SFX
	var mm = get_tree().get_root().get_node_or_null("/root/MusicManager")
	if mm and mm.has_method("play_sfx"):
		mm.play_sfx("wrong")

	# Refresh the visual hearts
	_update_player_hearts_ui(player_id)

	# Visual pulse on the heart that changed
	# compute index for the heart to pulse
	var heart_index: int = clamp(int(lives[player_id] / 2), 0, 2)
	var container := hearts_p1 if player_id == 1 else hearts_p2
	if container and heart_index < container.get_child_count():
		var theart := container.get_child(heart_index) as TextureRect
		if theart:
			var tween := create_tween()
			tween.tween_property(theart, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(theart, "scale", Vector2(1, 1), 0.12).set_delay(0.08)
	
	# optional popup with a reason
#	if reason != "":
#		var popup_pos := Vector2.ZERO
#		var root_view := get_viewport()
#		if root_view:
#			popup_pos = root_view.get_visible_rect().size * 0.5
#		_spawn_text_popup(reason, popup_pos)
	
	# check elimination
	if lives[player_id] <= 0:
		_on_player_eliminated(player_id)
	
func _on_player_eliminated(player_id: int) -> void:
	# determine winner: the other player
	var winner := 2 if player_id == 1 else 1

	# Stop gameplay
	gameplay_paused = true
	for node in [$IngredientContainer, player_input_p1, player_input_p2]:
		node.set_process(false)
		node.set_physics_process(false)

	# Show winner on the win screen
	if win_label:
		win_label.text = "Player %d Wins!" % winner
	if win_screen:
		win_screen.visible = true
		win_screen.mouse_filter = Control.MOUSE_FILTER_STOP
		# bring to front
		var parent := win_screen.get_parent()
		if parent:
			parent.move_child(win_screen, parent.get_child_count() - 1)
