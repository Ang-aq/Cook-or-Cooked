extends Node2D
class_name Ingredient

# movement
@export var speed: float = 150.0
var movement_enabled: bool = true

# combo / identity
var combo: Array = []
var ingredient_name: String = ""

# children (must match nodes in your Ingredient.tscn)
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash: AnimatedSprite2D = $AnimatedSprite2D/Slash
@onready var chopped_sprite: Sprite2D = $Chopped
@onready var input_display: HBoxContainer = $InputDisplay

# exported SFX (optional per-ingredient)
@export var chopped_texture: Texture2D
@export var sfx_up: AudioStream
@export var sfx_down: AudioStream
@export var sfx_left: AudioStream
@export var sfx_right: AudioStream

# state
var is_chopped: bool = false
var is_animating: bool = false
var combo_queue: Array = []

# arrow textures
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

# per-ingredient scale
var ingredient_scales := {
	"Potato": Vector2(2, 2),
	"Onion": Vector2(2, 2),
	"Carrot": Vector2(1, 1),
	"Meat": Vector2(2, 2)
}

# map input symbol -> slash animation name
var slash_anim_map := {
	"←": "slash_left",
	"→": "slash_right",
	"↑": "slash_up",
	"↓": "slash_down",
}

# default per-animation play time (seconds) — tweak to match your frames
const DEFAULT_SLASH_DURATION: float = 0.18

signal chop_completed(ingredient_name: String)

func _ready() -> void:
	# hide chopped and slash overlay initially
	if chopped_sprite:
		chopped_sprite.visible = false
	if slash:
		slash.visible = false

func set_combo_and_name(new_combo: Array, new_name: String) -> void:
	# copy combo and set ingredient name
	combo = []
	if new_combo is Array:
		combo = new_combo.duplicate(true)
	ingredient_name = new_name

	# rebuild arrows UI
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

	# play ingredient animation if exists
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(ingredient_name):
		sprite.play(ingredient_name)
	else:
		push_warning("Ingredient: no animation for: %s" % ingredient_name)

	# scale per-ingredient
	if ingredient_scales.has(ingredient_name):
		sprite.scale = ingredient_scales[ingredient_name]
	else:
		sprite.scale = Vector2(3, 3)

	# ensure chopped hidden
	if chopped_sprite:
		chopped_sprite.visible = false

func _process(delta: float) -> void:
	if movement_enabled and not is_chopped:
		position.y += speed * delta

	# cleanup when off bottom
	if position.y > get_viewport_rect().size.y:
		queue_free()

# ---- public: play the sequence of slashes in order (symbols array: ["→","↑","Z"]) ----
func play_slash_sequence(sequence: Array) -> void:
	if is_chopped or is_animating:
		return

	# build the queue of animation names (only those mapped)
	combo_queue.clear()
	for s in sequence:
		var sym := str(s)
		if slash_anim_map.has(sym):
			combo_queue.append(slash_anim_map[sym])

	# if nothing mapped, finish immediately
	if combo_queue.size() == 0:
		_finish_chop()
		return

	# stop movement, hide arrows and show slash overlay
	movement_enabled = false
	is_animating = true
	if input_display:
		input_display.visible = false
	if slash:
		slash.visible = true

	_play_next_slash()

# internal: play next queued slash animation (awaits a small duration per anim)
func _play_next_slash() -> void:
	if combo_queue.size() == 0:
		_finish_chop()
		return

	var anim_name: String = combo_queue.pop_front()

	# try to play animation on slash AnimatedSprite2D
	if slash and slash.sprite_frames and slash.sprite_frames.has_animation(anim_name):
		# set animation and play (we'll wait a fixed time after starting)
		slash.animation = anim_name
		slash.play()
		# try to calculate duration from frames if possible (fallback to constant)
		var duration: float = DEFAULT_SLASH_DURATION
		if slash.sprite_frames:
			if slash.sprite_frames.has_animation(anim_name):
				pass

		# play sfx for this anim
		_play_sfx_for_anim_name(anim_name)

		# wait then continue
		await get_tree().create_timer(DEFAULT_SLASH_DURATION).timeout
		# continue to next
		_play_next_slash()
	else:
		# missing animation on slash: still play SFX and continue shortly
		_play_sfx_for_anim_name(anim_name)
		await get_tree().create_timer(0.08).timeout
		_play_next_slash()

# finalize the chop (swap visuals, resume falling, emit signal)
func _finish_chop() -> void:
	# set chopped texture if provided
	if chopped_texture and chopped_sprite:
		chopped_sprite.texture = chopped_texture
		chopped_sprite.visible = true

	# hide original sprite
	if sprite:
		sprite.stop()
		sprite.visible = false

	# hide slash overlay
	if slash:
		slash.stop()
		slash.visible = false

	is_chopped = true
	is_animating = false

	# remove arrows UI so it can't be chopped again
	if input_display and is_instance_valid(input_display):
		input_display.queue_free()

	# resume falling for chopped items (optional)
	movement_enabled = true

	# emit name (string) so main can increment checklist safely
	emit_signal("chop_completed", ingredient_name)

# immediate chop (no animation) convenience
func become_chopped() -> void:
	if chopped_texture and chopped_sprite:
		chopped_sprite.texture = chopped_texture
		chopped_sprite.visible = true
	if sprite:
		sprite.stop()
		sprite.visible = false
	is_chopped = true
	if input_display and is_instance_valid(input_display):
		input_display.queue_free()
	emit_signal("chop_completed", ingredient_name)

# ---- audio helper: map animation name -> direction -> play exported stream or global SFX fallback ----
func _play_sfx_for_anim_name(anim_name: String) -> void:
	var dir := ""
	match anim_name:
		"slash_up": dir = "up"
		"slash_down": dir = "down"
		"slash_left": dir = "left"
		"slash_right": dir = "right"
		"slash_stab": dir = "up"
		_:
			dir = ""

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

	# fallback to global SFX manager 'chop' if available
	var gm = get_node_or_null("/root/SFXManager")
	if gm != null and gm.has_method("play_sfx"):
		gm.play_sfx("chop")
		return

func _on_sfx_timer_timeout(player: AudioStreamPlayer2D) -> void:
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
