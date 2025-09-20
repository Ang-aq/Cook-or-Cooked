extends Node2D

@onready var ingredient_scene: PackedScene = preload("res://Scenes/Ingredients/Ingredients.tscn")
@onready var text_popup_scene: PackedScene = preload("res://Scenes/text_popup.tscn")
@onready var player_input: Node = $UI/PlayerInput
@onready var ingredient_container: Node2D = $IngredientContainer
@onready var hearts_ui: HBoxContainer = $UI/HeartsContainer 
@onready var combo_label: Label = $UI/ComboLabel
@onready var KillLine: Node2D = $KillLine
@onready var pot: AnimatedSprite2D = $PotAnimation

@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float =  80.0
@export var spawn_start_y: float = -100.0
@export var max_active_ingredients: int = 100

@export var start_spawn_interval: float = 1.7
@export var start_multiplier: float = 0.25
@export var speed_increase_per_second: float = 0.03
@export var max_multiplier: float = 2.5
@export var spawn_interval_jitter: float = 0.35

@export var kill_line_y: float = 350  

@export var max_hearts: int = 6

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var spawn_timer: float = 0.0
var ingredient_speed_multiplier: float = 1.0
var infinite_pool: Array[Dictionary] = []
var combo: int = 0
var highest_combo: int = 0
var current_hearts: int = max_hearts
var game_paused: bool = false
var checklist: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	add_to_group("Game")   
	ingredient_speed_multiplier = start_multiplier
	_build_infinite_pool()
	spawn_timer = randf_range(0.0, start_spawn_interval)
	_initialize_checklist()  # NEW

	# connect player input if available
	if player_input and player_input.has_signal("sequence_submitted"):
		if not player_input.is_connected("sequence_submitted", Callable(self, "_on_sequence_submitted")):
			player_input.sequence_submitted.connect(Callable(self, "_on_sequence_submitted"))
	if player_input and player_input.has_signal("sequence_reset"):
		if not player_input.is_connected("sequence_reset", Callable(self, "_on_sequence_reset")):
			player_input.sequence_reset.connect(Callable(self, "_on_sequence_reset"))
	_update_hearts_ui()
	_update_combo_ui()
	
	pot.play("normal")
	MusicManager.stop_bgm()

func _process(delta: float) -> void:
	if game_paused:
		return
	ingredient_speed_multiplier = min(max_multiplier, ingredient_speed_multiplier + speed_increase_per_second * delta)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_infinite_ingredient()
		var jitter: float = start_spawn_interval * (1.0 + randf_range(-spawn_interval_jitter, spawn_interval_jitter))
		spawn_timer = max(0.05, jitter)

func _physics_process(delta: float) -> void:
	_cleanup_missed_ingredients()
#region Spawn Ingredients
func _build_infinite_pool() -> void:
	infinite_pool.clear()
	var seen: Dictionary = {}
	if "levels" in LevelManager:
		for level in LevelManager.levels:
			if level.has("requirements"):
				for name in level["requirements"].keys():
					if seen.has(name):
						continue
					seen[name] = true
					var combo_copy: Array[String] = []
					var req = level["requirements"][name]
					
					if req.has("combo") and req["combo"] is Array:
						for c in req["combo"]:
							combo_copy.append(str(c))
					infinite_pool.append({"name": name, "combo": combo_copy})
	if infinite_pool.is_empty():
		infinite_pool.append({"name":"Potato","combo":["↑","↓","Z"]})
		infinite_pool.append({"name":"Meat","combo":["→","↑","Z"]})
		infinite_pool.append({"name":"Carrot","combo":["↑","↑","↑","Z"]})

func _spawn_infinite_ingredient() -> void:
	if ingredient_container.get_child_count() >= max_active_ingredients:
		return
	
	# Filter pool based on checklist
	var available_pool = []
	for item in infinite_pool:
		var name = item["name"]
		var max_amount = LevelManager.get_requirement_for(name).get("amount", 999)
		if checklist.get(name, 0) < max_amount:
			available_pool.append(item)
	
	if available_pool.size() == 0:
		return
	
	# Pick random ingredient
	var pick: Dictionary = available_pool[rng.randi() % available_pool.size()]
	var combo_copy: Array = pick.get("combo", []).duplicate(true)
	
	var s: Ingredient = ingredient_scene.instantiate() as Ingredient
	if not is_instance_valid(s):
		push_error("InfiniteMode: failed to instantiate ingredient scene.")
		return
	
	if s.has_method("set_combo_and_name"):
		s.call_deferred("set_combo_and_name", combo_copy, pick["name"])
	
	s.position = Vector2(rng.randf_range(spawn_min_x, spawn_max_x), spawn_start_y)
	s.front_container = ingredient_container
	s._game_node = self
	
	if s.has_signal("chop_completed") and not s.is_connected("chop_completed", Callable(self, "_on_ingredient_chopped")):
		s.connect("chop_completed", Callable(self, "_on_ingredient_chopped"))
	
	ingredient_container.add_child(s)
#endregion
#region Player Input
func _on_sequence_submitted(sequence: Array) -> void:
	var clean_sequence: Array = sequence.duplicate()
	var matched: bool = false
	# Try to match against spawned ingredients (closest first)
	for i in range(ingredient_container.get_child_count() - 1, -1, -1):
		var node: Node = ingredient_container.get_child(i)
		if not is_instance_valid(node):
			continue
		node.get("is_chopped")
		var ing_combo: Array = node.get("combo")
		if _sequences_match(clean_sequence, ing_combo):
			matched = true
			node.play_slash_sequence(clean_sequence)
			break
	if not matched:
		_lose_heart("Wrong combo!", 0.5)
	if player_input and player_input.has_method("_clear_buffer"):
		player_input._clear_buffer()
	elif player_input and "input_buffer" in player_input:
		player_input.input_buffer.clear()
		if player_input.has_method("_update_display"):
			player_input._update_display()

func _on_sequence_reset() -> void:
	combo = 0
	_update_combo_ui()

func _on_ingredient_chopped(ingredient_name: String) -> void:
	# Update checklist
	if checklist.has(ingredient_name):
		checklist[ingredient_name] += 1
		# Clamp to max amount
		var max_amount = LevelManager.get_requirement_for(ingredient_name).get("amount", 999)
		checklist[ingredient_name] = min(checklist[ingredient_name], max_amount)

	# Existing combo + popup
	combo += 1
	if combo > highest_combo:
		highest_combo = combo
	_update_combo_ui()
	var popup_pos: Vector2 = ingredient_container.global_position + Vector2(270, 400)
	_spawn_text_popup("Collected %s!" % ingredient_name, popup_pos)
	MusicManager.play_sfx("chop")
#endregion
#region Missed Ingredient
func _cleanup_missed_ingredients() -> void:
	for ing_node in ingredient_container.get_children():
		if not is_instance_valid(ing_node):
			print("instance not valid")
			continue
		
		# Only care about Ingredients, not sauces or other objects
		if ing_node is Ingredient:
			var ing: Ingredient = ing_node as Ingredient
			
			if ing.global_position.y > kill_line_y:
				print("cleaning3")
				# If the ingredient wasn't chopped, player loses a heart
				if not ing.is_chopped:
					_lose_heart("Missed %s!" % ing.ingredient_name, 1.0)
					print("cleaned")
				# Remove the ingredient
				ing.queue_free()

func _lose_heart(reason: String, amount: float = 1.0) -> void:
	current_hearts -= amount
	current_hearts = max(0, current_hearts)
	combo = 0
	_update_combo_ui()
	_update_hearts_ui()
	MusicManager.play_sfx("wrong")
	var popup_pos: Vector2 = ingredient_container.global_position + Vector2(270, 400)
	_spawn_text_popup(reason, popup_pos)
	if current_hearts <= 0:
		_on_game_over()
#endregion
#region Helpers
func _update_hearts_ui() -> void:
	if not hearts_ui:
		return
	for i in range(hearts_ui.get_child_count()):
		var heart: TextureRect = hearts_ui.get_child(i)
		var full_heart_index: int = i * 2
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
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

func _initialize_checklist() -> void:
	checklist.clear()
	for ing_name in LevelManager.get_current_requirements().keys():
		checklist[ing_name] = 0
#endregion
