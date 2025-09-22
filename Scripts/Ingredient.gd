extends Node2D
class_name Ingredient

#region Variables, Nodes, etc.
@export var speed: float = 150.0
@export var chopped_fallback: Texture2D
@export var flash_offset: Vector2 = Vector2(0, 0) # this is unused fix soon

var combo: Array = []
var ingredient_name: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash: AnimatedSprite2D = $AnimatedSprite2D/Slash
@onready var chopped_sprite: Sprite2D = $Chopped
@onready var input_display: HBoxContainer = $InputDisplay

# State
var movement_enabled := true
var is_chopped := false
var is_animating := false
var combo_queue: Array = []
var _game_node = null

# these r actually assigned in ing manager
var front_container: Node2D = null
var behind_container: Node2D = null
var spawned := false  
var original_speed: float = 150.0

var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

var ingredient_scales := {
	"Potato": Vector2(2, 2),
	"Onion": Vector2(2, 2),
	"Carrot": Vector2(1, 1),
	"Meat": Vector2(2, 2),
	"GreenBean": Vector2(2, 2),
	"Tomato": Vector2(2, 2),
	"Spring Onion": Vector2(1.5, 1.5),
	"Scallion": Vector2(1.5, 1.5)
}

var slash_anim_map := {
	"←": "slash_left",
	"→": "slash_right",
	"↑": "slash_up",
	"↓": "slash_down",
}

const DEFAULT_SLASH_DURATION := 0.18

signal chop_completed(ingredient_name: String)

#endregion

func _ready() -> void:
	if chopped_sprite:
		chopped_sprite.visible = false
	if slash:
		slash.visible = false
	spawned = true  
	
	var nodes := get_tree().get_nodes_in_group("Game")
	if nodes.size() > 0:
		self._game_node = nodes[0]
	else:
		self._game_node = null

func set_combo_and_name(new_combo: Array, new_name: String) -> void:
	combo = new_combo.duplicate(true) if new_combo is Array else []
	ingredient_name = new_name

	if is_instance_valid(input_display):
		for child in input_display.get_children():
			child.queue_free()
		for step in combo:
			if arrow_textures.has(step):
				var tex := TextureRect.new()
				tex.texture = arrow_textures[step]
				tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex.size_flags_horizontal = Control.SIZE_FILL
				tex.size_flags_vertical = Control.SIZE_FILL
				input_display.add_child(tex)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ingredient_name):
		sprite.play(ingredient_name)
	else:
		push_warning("Ingredient: no animation for: %s" % ingredient_name)

	sprite.scale = ingredient_scales.get(ingredient_name, Vector2(3, 3))
	if is_instance_valid(chopped_sprite):
		chopped_sprite.scale = sprite.scale
		chopped_sprite.visible = false

func _process(delta: float) -> void:
	var mult: float = 1.0
	if _game_node and _game_node.has_method("get"):
		if "ingredient_speed_multiplier" in _game_node:
			mult = float(_game_node.ingredient_speed_multiplier)

	if movement_enabled:
		position.y += speed * mult * delta

	if is_instance_valid(sprite):
		sprite.speed_scale = max(0.05, mult)
	if is_instance_valid(slash):
		slash.speed_scale = max(0.05, mult)

	if _game_node and _game_node.has_node("KillLine"):
		var line_y = _game_node.get_node("KillLine").global_position.y
		if global_position.y >= line_y:
			queue_free()  
			return

	if spawned and position.y > get_viewport_rect().size.y:
		queue_free()

#region Ingredient Chopping
func play_slash_sequence(sequence: Array) -> void:
	if is_chopped or is_animating:
		return

	combo_queue.clear()
	for s in sequence:
		var sym := str(s)
		if sym == "Z":
			continue
		if slash_anim_map.has(sym):
			combo_queue.append(slash_anim_map[sym])

	if combo_queue.is_empty():
		_finish_chop()
		return

	movement_enabled = false
	is_animating = true
	if is_instance_valid(input_display):
		input_display.visible = false
	if is_instance_valid(slash):
		slash.visible = true

	_play_next_slash()

func _play_next_slash() -> void:
	if combo_queue.is_empty():
		_finish_chop()
		return

	var anim_name: String = combo_queue.pop_front()

	var speed_scale: float = 1.0
	if is_instance_valid(slash):
		speed_scale = max(0.05, slash.speed_scale)
	else:
		if _game_node and ("ingredient_speed_multiplier" in _game_node):
			speed_scale = max(0.05, float(_game_node.ingredient_speed_multiplier))

	if slash and slash.sprite_frames and slash.sprite_frames.has_animation(anim_name):
		slash.animation = anim_name
		slash.play()
		MusicManager.play_sfx("slash")

		var wait_time: float = DEFAULT_SLASH_DURATION / speed_scale
		await get_tree().create_timer(wait_time).timeout
		_play_next_slash()
	else:
		# fallback delay
		MusicManager.play_sfx("slash")
		var fallback_wait: float = 0.08 / speed_scale
		await get_tree().create_timer(fallback_wait).timeout
		_play_next_slash()

func _finish_chop() -> void:
	if slash:
		slash.stop()
		slash.visible = false
	
	var chopped_anim := "%s_chopped" % ingredient_name
	var played_chopped_anim := false
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(chopped_anim):
		sprite.visible = true
		sprite.animation = chopped_anim
		sprite.play()
		played_chopped_anim = true
	
	if not played_chopped_anim and is_instance_valid(chopped_sprite):
		if chopped_sprite.texture == null and chopped_fallback:
			chopped_sprite.texture = chopped_fallback
		chopped_sprite.visible = chopped_sprite.texture != null
		if chopped_sprite.visible and sprite:
			sprite.stop()
			sprite.visible = false
	
	is_chopped = true
	is_animating = false
	if is_instance_valid(input_display):
		input_display.queue_free()
	movement_enabled = true
	
	emit_signal("chop_completed", ingredient_name)
	emit_signal("chop_completed", ingredient_name, self)

func become_chopped() -> void:
	if is_instance_valid(chopped_sprite):
		if chopped_fallback and chopped_sprite.texture == null:
			chopped_sprite.texture = chopped_fallback
		chopped_sprite.visible = chopped_sprite.texture != null
		if chopped_sprite.visible and sprite:
			sprite.stop()
			sprite.visible = false

	is_chopped = true
	if is_instance_valid(input_display):
		input_display.queue_free()
	
	emit_signal("chop_completed", ingredient_name)
	
#endregion

#region SFX 
func _on_sfx_timer_timeout(player: AudioStreamPlayer2D) -> void:
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
#endregion

func flash_x(offset_override: Vector2 = Vector2.ZERO) -> void:
	var final_offset := flash_offset + offset_override

	var x_sprite := Sprite2D.new()
	x_sprite.texture = preload("res://Sprites/X.png")
	x_sprite.z_index = 1000
	x_sprite.modulate = Color(1, 0, 0, 1.0)

	add_child(x_sprite)

	if is_instance_valid(sprite):
		x_sprite.global_position = sprite.global_position + final_offset
	else:
		x_sprite.global_position = global_position + final_offset

	var tween := create_tween()
	tween.tween_property(x_sprite, "scale", x_sprite.scale * 1.25, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(x_sprite, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if is_instance_valid(x_sprite):
			x_sprite.queue_free()
	)
