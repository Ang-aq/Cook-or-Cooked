extends Node2D
class_name Mosquito

signal defeated
signal attacked

# --- Properties ---
@export var speed: float = 30.0          # very slow toward the pot
@export var attack_delay: float = 10.0   # seconds before it attacks
@export var approach_threshold: float = 24.0  # distance to start hover/attack

var combo: Array = []
var target_pos: Vector2 = Vector2.ZERO
var defeated_flag: bool = false

# --- Nodes ---
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var combo_display: HBoxContainer = $ComboDisplay/HBoxContainer  # mini combo above mosquito

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
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("fly"):
		sprite.play("fly")
	_start_attack_countdown()

# ----------------------------------------------------------------
func set_combo_and_target(new_combo: Array, new_target_pos: Vector2) -> void:
	combo = []
	if new_combo is Array:
		combo = new_combo.duplicate(true)
	target_pos = new_target_pos
	_update_combo_display()

func get_combo() -> Array:
	return combo

# ----------------------------------------------------------------
func defeat() -> void:
	if defeated_flag:
		return
	defeated_flag = true
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
	await get_tree().create_timer(0.4).timeout
	emit_signal("defeated", self)
	queue_free()

# ----------------------------------------------------------------
func _start_attack_countdown() -> void:
	await get_tree().create_timer(attack_delay).timeout
	if defeated_flag:
		return
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	await get_tree().create_timer(0.4).timeout
	if defeated_flag:
		return
	emit_signal("attacked", self)
	queue_free()

# ----------------------------------------------------------------
func _process(delta: float) -> void:
	if defeated_flag:
		return

	# move toward target
	var dir := target_pos - global_position
	var dist := dir.length()
	if dist > approach_threshold:
		dir = dir.normalized()
		global_position += dir * speed * delta
	else:
		# hover effect: small sine bob
		global_position.y += sin(Time.get_ticks_msec() / 300.0) * 0.2

	# update combo display position above mosquito
	if combo_display:
		combo_display.position = Vector2(0, -50)  # 50 px above sprite

# ----------------------------------------------------------------
# Update mini combo arrows above the mosquito
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
