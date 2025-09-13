extends Node2D
class_name VersusPowerUp

@export var powerup_type: String = "extra_life"  # "heart_breaker", "dish_snatcher", "extra_life", "mystery"
@export var combo: Array = []
@export var fall_speed: float = 120.0
@export var lifetime: float = 12.0

signal powerup_collected(player_id: int, powerup_type: String)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var combo_display: Node = $ComboDisplay if has_node("ComboDisplay") else null

var _reserved_by: int = 0
var _collected: bool = false
var _spawn_time: float = 0.0

const DEFAULT_COMBOS := {
	"heart_breaker": ["↑","↑","↓","↓","Z"],
	"dish_snatcher": ["→","↓","→","↓","Z"],
	"extra_life": ["↑","→","↓","←","Z"],
	"mystery": ["↓","→","→","↓","Z"]
}

func _ready() -> void:
	_spawn_time = Time.get_ticks_msec() / 1000.0
	if combo == null or combo.size() == 0:
		if DEFAULT_COMBOS.has(powerup_type):
			combo = DEFAULT_COMBOS[powerup_type].duplicate(true)
	_refresh_visuals()
	
	_update_combo_display()
	sprite.play(powerup_type)

func reserve(player_id: int) -> bool:
	if _reserved_by != 0 and _reserved_by != player_id:
		return false
	_reserved_by = player_id
	return true

func get_reserved_player() -> int:
	return _reserved_by

func set_fall_speed(s: float) -> void:
	fall_speed = s

func play_slash_sequence(sequence: Array) -> void:
	if _collected:
		return
	if combo == null or combo.size() == 0 or sequence.size() != combo.size():
		return
	for i in range(sequence.size()):
		if str(sequence[i]) != str(combo[i]):
			return
	
	_collected = true
	var collector := int(_reserved_by)
	if collector == 0:
		collector = -1
	
	var gm = _get_game_node()
	if gm != null and collector >= 1:
		_apply_effects_to_game(gm, collector)
	emit_signal("powerup_collected", collector, powerup_type)
	queue_free()

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	var screen_h = get_viewport_rect().size.y
	if position.y > screen_h + 64:
		queue_free()
	if Time.get_ticks_msec() / 1000.0 - _spawn_time > lifetime:
		queue_free()

func _get_game_node() -> Node:
	var nodes := get_tree().get_nodes_in_group("Game")
	if nodes.size() > 0:
		return nodes[0]
	return null

func _apply_effects_to_game(gm: Node, collector: int) -> void:
	var opponent := 1 if collector == 2 else 2

	match powerup_type:
		"heart_breaker":
			_apply_heart_breaker(gm, opponent)
			gm._spawn_powerup_popup(opponent, "-1 Heart!")
			MusicManager.play_sfx("wrong")
		"dish_snatcher":
			_apply_dish_snatcher(gm, opponent, collector)
			gm._spawn_powerup_popup(collector, "Dish Stolen!")
			MusicManager.play_sfx("level_up")
		"extra_life":
			_apply_extra_life(gm, collector)
			gm._spawn_powerup_popup(collector, "+1 Heart!")
			MusicManager.play_sfx("powerup")
		"mystery":
			var r = RandomNumberGenerator.new()
			r.randomize()
			var pick = r.randi_range(0, 2)
			if pick == 0:
				_apply_heart_breaker(gm, opponent)
				gm._spawn_powerup_popup(opponent, "-1 Heart!")
			elif pick == 1:
				_apply_dish_snatcher(gm, opponent, collector)
				gm._spawn_powerup_popup(opponent, "Dish Stolen!")
			else:
				_apply_extra_life(gm, collector)
				gm._spawn_powerup_popup(collector, "+1 Heart!")
			MusicManager.play_sfx("powerup")
		_:
			print("VersusPowerUp: unknown type:", powerup_type)

func _apply_heart_breaker(gm: Node, target_player: int) -> void:
	if not gm.lives.has(target_player):
		# initialize if not found
		gm.lives[target_player] = gm.lives_per_player if gm.has_method("lives_per_player") == false else gm.lives_per_player

	# subtract 1 life (was subtracting 2)
	gm.lives[target_player] = max(0, int(gm.lives[target_player]) - 1)

	if gm.has_method("_update_player_hearts_ui"):
		gm._update_player_hearts_ui(target_player)

	if int(gm.lives[target_player]) <= 0:
		if gm.has_method("_on_player_eliminated"):
			gm._on_player_eliminated(target_player)

func _apply_dish_snatcher(gm: Node, target_player: int, collector: int) -> void:
	if gm.dishes_completed.has(target_player):
		if int(gm.dishes_completed[target_player]) > 0:
			gm.dishes_completed[target_player] = max(0, int(gm.dishes_completed[target_player]) - 1)
		else:
			if gm.has_method("_spawn_powerup_popup"):
				gm._spawn_powerup_popup(target_player, "No dishes to steal!")

func _apply_extra_life(gm: Node, target_player: int) -> void:
	if not gm.lives.has(target_player):
		gm.lives[target_player] = 0
	gm.lives[target_player] = min(int(gm.lives_per_player), int(gm.lives[target_player]) + 1)
	if gm.has_method("_update_player_hearts_ui"):
		gm._update_player_hearts_ui(target_player)

func _update_combo_display() -> void:
	if combo_display == null:
		return
	for c in combo_display.get_children():
		c.queue_free()
	var arrow_textures := {
		"↑": preload("res://Sprites/arrow_up.png"),
		"↓": preload("res://Sprites/arrow_down.png"),
		"←": preload("res://Sprites/arrow_left.png"),
		"→": preload("res://Sprites/arrow_right.png"),
		"Z": preload("res://Sprites/Z.png")
	}
	var x := 0
	for step in combo:
		var key := str(step)
		if arrow_textures.has(key):
			var icon := TextureRect.new()
			icon.texture = arrow_textures[key]
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(28, 28)
			icon.position = Vector2(x, 0)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			combo_display.add_child(icon)
			x += 34
		else:
			var lbl := Label.new()
			lbl.text = key
			lbl.position = Vector2(x, 0)
			combo_display.add_child(lbl)
			x += 30

func _refresh_visuals() -> void:
	# Update combo list
	if DEFAULT_COMBOS.has(powerup_type):
		combo = DEFAULT_COMBOS[powerup_type].duplicate(true)
	_update_combo_display()

	# Update sprite animation
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(powerup_type):
			sprite.play(powerup_type)
		elif sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
