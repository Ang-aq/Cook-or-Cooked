extends Node2D

# reuse existing ingredient scene
@onready var ingredient_scene: PackedScene = preload("res://VersusScenes/versus_ingredient.tscn")

# UI nodes
@onready var checklist_p1: Control = $CanvasLayer/ChecklistP1
@onready var checklist_p2: Control = $CanvasLayer/ChecklistP2
@onready var player_input_p1: Node = $CanvasLayer/PlayerInputP1
@onready var player_input_p2: Node = $CanvasLayer/PlayerInputP2

@onready var ingredient_container: Node2D = $IngredientContainer

# Tunables
@export var spawn_interval: float = 1.2
@export var spawn_min_x: float = -300.0
@export var spawn_max_x: float = 300.0
@export var spawn_start_y: float = -100.0

var spawn_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Game state for versus
var required_ingredients: Dictionary = {}  # copy of LevelManager requirements
var collected_counts := {1: {}, 2: {}}     # per-player collected
var reserved_map: Dictionary = {}          # ingredient_node -> player_id (temporary reservation)

func _ready() -> void:
	rng.randomize()
	spawn_timer = spawn_interval
	# TODO: ask LevelManager for dish (for now we'll set a test requirement if LevelManager not available)
	if "LevelManager" in ProjectSettings.globalize():
		pass
	# example: copy current level requirements or set temporary ones:
	required_ingredients = {
		"Tomato": {"count":3, "combo":["→","Z"]},
		"Onion": {"count":2, "combo":["↓","Z"]}
	}
	for name in required_ingredients.keys():
		collected_counts[1][name] = 0
		collected_counts[2][name] = 0

	# setup two checklists (reuse existing Checklist.tscn script)
	if checklist_p1 and checklist_p1.has_method("setup_checklist"):
		var req_counts := {}
		for n in required_ingredients.keys():
			req_counts[n] = int(required_ingredients[n]["count"])
		checklist_p1.setup_checklist(req_counts)
		checklist_p2.setup_checklist(req_counts)

	# connect player input signals
	if player_input_p1:
		player_input_p1.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
		player_input_p1.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
	if player_input_p2:
		player_input_p2.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
		player_input_p2.sequence_reset.connect(Callable(self, "_on_sequence_reset"))

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		_try_spawn_ingredient()
		spawn_timer = spawn_interval

# spawn an ingredient instance using your existing Ingredients.tscn
func _try_spawn_ingredient() -> void:
	# simple weighted choice for now: pick any required ingredient at random
	var names := required_ingredients.keys()
	if names.size() == 0:
		return
	var name := names[rng.randi() % names.size()]
	_spawn_ingredient(name)

func _spawn_ingredient(ingredient_name: String) -> void:
	var ing_node := ingredient_scene.instantiate()
	if ing_node == null:
		push_error("Failed to instantiate ingredient scene")
		return
	ingredient_container.add_child(ing_node)
	ing_node.position = Vector2(rng.randf_range(spawn_min_x, spawn_max_x), spawn_start_y)

	# reuse the existing public method if available
	if ing_node.has_method("set_combo_and_name"):
		var combo = required_ingredients[ingredient_name].get("combo", [])
		ing_node.set_combo_and_name(combo.duplicate(true), ingredient_name)

	# connect chop_completed (original Ingredient emits (ingredient_name) )
	if ing_node.has_signal("chop_completed"):
		ing_node.chop_completed.connect(Callable(self, "_on_ingredient_chopped"))

# Called when either player submits a sequence
# PlayerInput sends (sequence, player_id)
func _on_sequence_submitted(sequence: Array, player_id: int) -> void:
	var clean_sequence = sequence.duplicate()
	var matched := false

	# First, check sauces / pests like original game (omitted for brevity)
	# Then check shared ingredient pool in reverse order (topmost first)
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		# skip if already chopped
		if node.has_method("is_chopped") and node.is_chopped:
			continue
		# If this ingredient's combo size matches our sequence, check equality
		if node.has_method("combo") and node.combo.size() == clean_sequence.size():
			var eq := true
			for j in range(clean_sequence.size()):
				if str(clean_sequence[j]) != str(node.combo[j]):
					eq = false
					break
			if eq:
				# reserve: map node -> player_id so when chop_completed fires we know who to credit
				reserved_map[node] = player_id
				# ask ingredient to play its slash; original signature: play_slash_sequence(sequence)
				if node.has_method("play_slash_sequence"):
					node.play_slash_sequence(clean_sequence)
				matched = true
				break

	if not matched:
		# wrong combo: for now, penalize globally (you can change to per-player later)
		# show popup or play sfx
		print("Versus: wrong combo by player %s" % str(player_id))

	# clear the submitting player's display
	_clear_player_input(player_id)

func _on_sequence_reset(player_id: int) -> void:
	# optionally reset a player's combo count or UI
	print("Versus: player %d reset input" % player_id)

func _clear_player_input(player_id: int) -> void:
	if player_id == 1 and player_input_p1 and player_input_p1.has_method("_update_display"):
		player_input_p1.input_buffer.clear()
		player_input_p1._update_display()
	elif player_id == 2 and player_input_p2 and player_input_p2.has_method("_update_display"):
		player_input_p2.input_buffer.clear()
		player_input_p2._update_display()

# Called when an Ingredient finishes chopping. Original Ingredient emits only (ingredient_name).
# We loop reserved_map to find which node emitted (we get the sender via get_signal_sender()).
func _on_ingredient_chopped(ingredient_name: String) -> void:
	# Godot doesn't give sender directly in this signal handler but we can search child nodes
	# Strategy: find the topmost chopped ingredient with matching name that also exists in reserved_map,
	# prefer those that are now is_chopped == true.
	var credited_player := 0
	var target_node := null
	for node in reserved_map.keys():
		if not is_instance_valid(node):
			continue
		if node.ingredient_name == ingredient_name and node.is_chopped:
			credited_player = int(reserved_map.get(node, 0))
			target_node = node
			break

	# Fallback: if nothing in reserved_map, try to find topmost chopped ingredient with that name
	if credited_player == 0:
		for i in range(ingredient_container.get_child_count() - 1, -1, -1):
			var n = ingredient_container.get_child(i)
			if not is_instance_valid(n):
				continue
			if n.ingredient_name == ingredient_name and n.is_chopped:
				target_node = n
				break

	if target_node != null and credited_player != 0:
		# credit that player
		var prev := collected_counts[credited_player].get(ingredient_name, 0)
		var req := int(required_ingredients[ingredient_name]["count"])
		# Too many? if already full, you may want to flash X instead (keep it simple now)
		if prev >= req:
			print("Versus: Player %d tried to add too many %s" % [credited_player, ingredient_name])
			# optional: flash topmost ingredient and penalize
			# call target_node.flash_x() if available
			if target_node.has_method("flash_x"):
				target_node.flash_x()
		else:
			collected_counts[credited_player][ingredient_name] = prev + 1
			# update UI checklist for the player
			if credited_player == 1 and checklist_p1 and checklist_p1.has_method("update_progress"):
				checklist_p1.update_progress(ingredient_name, collected_counts[1][ingredient_name])
			elif credited_player == 2 and checklist_p2 and checklist_p2.has_method("update_progress"):
				checklist_p2.update_progress(ingredient_name, collected_counts[2][ingredient_name])

			# win check for credited player
			var finished := true
			for name in required_ingredients.keys():
				if collected_counts[credited_player].get(name, 0) < int(required_ingredients[name]["count"]):
					finished = false; break
			if finished:
				_on_player_won(credited_player)
	else:
		print("Versus: chopped but couldn't attribute to player for ingredient:", ingredient_name)

	# remove node from reserved_map if present
	if target_node != null and reserved_map.has(target_node):
		reserved_map.erase(target_node)
