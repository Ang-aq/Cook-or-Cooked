extends Node2D
class_name SaucePowerUp

signal poured  # emitted when sauce finishes pouring

# --- Properties ---
@export var speed: float = 60.0  # horizontal floating speed
@export var combo: Array[String] = []  # set by manager
var poured_flag: bool = false
var target_pos_x: float = 1200  # x at which to remove if not poured

# --- Nodes ---
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var combo_display: HBoxContainer = $ComboDisplay/HBoxContainer

# --- Arrow textures ---
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

# ----------------------------------------------------------------
func _ready() -> void:
	if anim_sprite.sprite_frames.has_animation("floating"):
		anim_sprite.play("floating")
	_update_combo_display()

# ----------------------------------------------------------------
func _process(delta: float) -> void:
	if poured_flag:
		return  # stop moving while pouring

	# move right
	position.x += speed * delta

	# remove if goes off screen
	if position.x > target_pos_x:
		queue_free()

	# update combo display above sprite
	if combo_display:
		combo_display.position = Vector2(0, -50)

# ----------------------------------------------------------------
func set_combo(new_combo: Array[String]) -> void:
	combo = []
	if new_combo is Array:
		combo = new_combo.duplicate(true)
	_update_combo_display()

# ----------------------------------------------------------------
func check_sequence(player_sequence: Array[String]) -> void:
	if player_sequence == combo and not poured_flag:
		_play_pour_animation()

# ----------------------------------------------------------------
func _play_pour_animation() -> void:
	poured_flag = true
	if anim_sprite.sprite_frames.has_animation("pour"):
		anim_sprite.play("pour")
		anim_sprite.animation_finished.connect(Callable(self, "_on_animation_finished"))

# ----------------------------------------------------------------
func _on_animation_finished(anim_name: String) -> void:
	emit_signal("poured")
	queue_free()

# ----------------------------------------------------------------
func _update_combo_display() -> void:
	if combo_display == null:
		return
	# clear old arrows
	for child in combo_display.get_children():
		child.queue_free()
	# add new arrows
	for step in combo:
		if arrow_textures.has(step):
			var tex := TextureRect.new()
			tex.texture = arrow_textures[step]
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(32, 32)
			combo_display.add_child(tex)
