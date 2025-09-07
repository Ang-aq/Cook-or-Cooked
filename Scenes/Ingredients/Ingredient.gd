extends Node2D
class_name Ingredient

@export var speed: float = 150.0
@export var chopped_fallback: Texture2D    # optional fallback if no chopped animation
@export var flash_offset: Vector2 = Vector2(0, 0) # this is unused fix soon

var combo: Array = []
var ingredient_name: String = ""

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash: AnimatedSprite2D = $AnimatedSprite2D/Slash
@onready var chopped_sprite: Sprite2D = $Chopped
@onready var input_display: HBoxContainer = $InputDisplay

# SFX
@export var sfx_up: AudioStream
@export var sfx_down: AudioStream
@export var sfx_left: AudioStream
@export var sfx_right: AudioStream

# State
var movement_enabled := true
var is_chopped := false
var is_animating := false
var combo_queue: Array = []
var _game_node = null

# Containers assigned by Main
var front_container: Node2D = null
var behind_container: Node2D = null
var spawned := false  
var original_speed: float = 150.0

# Visual resources
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
	"Spring Onion": Vector2(2, 2)
}

var slash_anim_map := {
	"←": "slash_left",
	"→": "slash_right",
	"↑": "slash_up",
	"↓": "slash_down",
}

const DEFAULT_SLASH_DURATION := 0.18

signal chop_completed(ingredient_name: String)

func _ready() -> void:
	# existing initialization
	if chopped_sprite:
		chopped_sprite.visible = false
	if slash:
		slash.visible = false
	spawned = true  # mark as added to tree safely

	# Cache the Game node by group (Main already does add_to_group("Game"))
	# This is safe even if Main is not autoloaded; it finds the node in the scene.
	var nodes := get_tree().get_nodes_in_group("Game")
	if nodes.size() > 0:
		# pick the first node in the group as the central Game node
		self._game_node = nodes[0]
	else:
		self._game_node = null

# Setup
func set_combo_and_name(new_combo: Array, new_name: String) -> void:
	combo = new_combo.duplicate(true) if new_combo is Array else []
	ingredient_name = new_name

	# rebuild arrows UI
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

	# play the base animation if present (name should match ingredient_name)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ingredient_name):
		sprite.play(ingredient_name)
	else:
		push_warning("Ingredient: no animation for: %s" % ingredient_name)

	# scale sprite
	sprite.scale = ingredient_scales.get(ingredient_name, Vector2(3, 3))
	if is_instance_valid(chopped_sprite):
		chopped_sprite.scale = sprite.scale
		chopped_sprite.visible = false

# Process
func _process(delta: float) -> void:
	# Movement: use the global multiplier from the Game node when present.
	var mult: float = 1.0
	if _game_node and _game_node.has_method("get"):
		if "ingredient_speed_multiplier" in _game_node:
			mult = float(_game_node.ingredient_speed_multiplier)

	# Apply movement using the multiplier
	if movement_enabled:
		position.y += speed * mult * delta

	# Also scale animation playback speed
	if is_instance_valid(sprite):
		sprite.speed_scale = max(0.05, mult)
	if is_instance_valid(slash):
		slash.speed_scale = max(0.05, mult)

	# --- Kill line check ---
	if _game_node and _game_node.has_node("KillLine"):
		var line_y = _game_node.get_node("KillLine").global_position.y
		if global_position.y >= line_y:
			queue_free()  # disappear when touching the line
			return

	# Free if fully off the screen (fallback)
	if spawned and position.y > get_viewport_rect().size.y:
		queue_free()

# Chop / Slash
func play_slash_sequence(sequence: Array) -> void:
	if is_chopped or is_animating:
		return

	# build animation queue
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

	if slash and slash.sprite_frames and slash.sprite_frames.has_animation(anim_name):
		slash.animation = anim_name
		slash.play()
		_play_sfx_for_anim_name(anim_name)
		await get_tree().create_timer(DEFAULT_SLASH_DURATION).timeout
		_play_next_slash()
	else:
		_play_sfx_for_anim_name(anim_name)
		await get_tree().create_timer(0.08).timeout
		_play_next_slash()

func _finish_chop() -> void:
	if slash:
		slash.stop()
		slash.visible = false

	# try chopped animation
	var chopped_anim := "%s_chopped" % ingredient_name
	var played_chopped_anim := false
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(chopped_anim):
		sprite.visible = true
		sprite.animation = chopped_anim
		sprite.play()
		played_chopped_anim = true

	# fallback static sprite
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

	# move behind pot
	_move_to_behind()

	emit_signal("chop_completed", ingredient_name)

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

	# move behind pot
	_move_to_behind()

	emit_signal("chop_completed", ingredient_name)

# -----------------------
# Helpers
# -----------------------
func _move_to_behind() -> void:
	if behind_container and is_instance_valid(behind_container):
		if get_parent() != behind_container:
			get_parent().remove_child(self)
			behind_container.add_child(self)

# -----------------------
# Audio helper
# -----------------------
func _play_sfx_for_anim_name(anim_name: String) -> void:
	var dir := ""
	match anim_name:
		"slash_up": dir = "up"
		"slash_down": dir = "down"
		"slash_left": dir = "left"
		"slash_right": dir = "right"
		"slash_stab": dir = "up"
		_: dir = ""

	var stream: AudioStream = null
	match dir:
		"up": stream = sfx_up
		"down": stream = sfx_down
		"left": stream = sfx_left
		"right": stream = sfx_right
		
	if stream != null:
		var p := AudioStreamPlayer2D.new()
		p.stream = stream
		add_child(p)
		p.play()
		var t := Timer.new()
		t.one_shot = true
		t.wait_time = p.stream.get_length() if p.stream != null else 0.15
		add_child(t)
		t.autostart = true
		t.timeout.connect(Callable(self, "_on_sfx_timer_timeout").bind(p))
		return
		
	var gm = get_node_or_null("/root/SFXManager")
	if gm != null and gm.has_method("play_sfx"):
		gm.play_sfx("chop")

func _on_sfx_timer_timeout(player: AudioStreamPlayer2D) -> void:
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
# Ingredient.gd

# Flash a red X over the ingredient.
# `offset_override` is optional and added to the exported flash_offset.
func flash_x(offset_override: Vector2 = Vector2.ZERO) -> void:
	var final_offset := flash_offset + offset_override

	# create sprite
	var x_sprite := Sprite2D.new()
	x_sprite.texture = preload("res://Sprites/X.png")
	x_sprite.z_index = 1000
	x_sprite.modulate = Color(1, 0, 0, 1.0)

	# add to the ingredient so it follows the node (we'll set global_position explicitly)
	add_child(x_sprite)

	# position: prefer sprite center if available, else ingredient global position
	if is_instance_valid(sprite):
		# sprite.global_position is the center of the sprite in world space
		x_sprite.global_position = sprite.global_position + final_offset
	else:
		x_sprite.global_position = global_position + final_offset

	# animation: quick pop + fade
	var tween := create_tween()
	tween.tween_property(x_sprite, "scale", x_sprite.scale * 1.25, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(x_sprite, "modulate:a", 0.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if is_instance_valid(x_sprite):
			x_sprite.queue_free()
	)
