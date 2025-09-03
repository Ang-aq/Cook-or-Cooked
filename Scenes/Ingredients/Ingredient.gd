extends Node2D
class_name Ingredient

# -----------------------
# Tunables
# -----------------------
@export var speed: float = 150.0
@export var chopped_fallback: Texture2D    # optional fallback if no chopped animation

# -----------------------
# Identity / combo
# -----------------------
var combo: Array = []
var ingredient_name: String = ""

# -----------------------
# Children (expected nodes)
# -----------------------
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash: AnimatedSprite2D = $AnimatedSprite2D/Slash
@onready var chopped_sprite: Sprite2D = $Chopped
@onready var input_display: HBoxContainer = $InputDisplay

# -----------------------
# SFX (optional)
# -----------------------
@export var sfx_up: AudioStream
@export var sfx_down: AudioStream
@export var sfx_left: AudioStream
@export var sfx_right: AudioStream

# -----------------------
# State
# -----------------------
var movement_enabled := true
var is_chopped := false
var is_animating := false
var combo_queue: Array = []

# Containers assigned by Main.gd
var front_container: Node2D = null
var behind_container: Node2D = null
var spawned := false  

# -----------------------
# Visual resources
# -----------------------
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
	"Tomato": Vector2(2, 2)
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
	if chopped_sprite:
		chopped_sprite.visible = false
	if slash:
		slash.visible = false
	spawned = true  # mark as added to tree safely

# -----------------------
# Setup
# -----------------------
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

# -----------------------
# Process
# -----------------------
func _process(delta: float) -> void:
	if movement_enabled:
		position.y += speed * delta
	# Only free if the ingredient has been fully spawned in the scene
	if spawned and position.y > get_viewport_rect().size.y:
		queue_free()

# -----------------------
# Chop / Slash
# -----------------------
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
