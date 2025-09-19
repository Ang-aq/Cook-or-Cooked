extends Node2D
class_name Mosquito

signal defeated
signal attacked

@export var speed: float = 30.0         
@export var attack_delay: float = 8.0        
@export var combos_stages := [["→", "Z"]]
@export var require_all_stages: bool = true

var target_pos: Vector2 = Vector2.ZERO
var _current_stage: int = 0
var _defeated: bool = false
var _base_y: float = 0.0
var _bob_time: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var combo_display: Control = $ComboDisplay

var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

func _ready() -> void:
	_base_y = global_position.y
	_update_combo_display()
	sprite.play("floating")
	_start_attack_countdown()

func set_target_pos(p: Vector2) -> void:
	target_pos = p

func get_current_combo() -> Array:
	if _current_stage >= 0 and _current_stage < combos_stages.size():
		return combos_stages[_current_stage]
	return []

func check_sequence(sequence: Array) -> bool:
	if _defeated:
		return false
	var combo_req := get_current_combo()
	if sequence.size() != combo_req.size():
		return false  
	if _arrays_equal_normalized(sequence, combo_req):
		_on_stage_success()
		return true
	else:
		emit_signal("pest_failed", "You entered the wrong combo!")
		queue_free()
		return true

func _on_stage_success() -> void:
	if require_all_stages:
		_current_stage += 1
		if _current_stage >= combos_stages.size():
			_defeat()
			return
		_update_combo_display()
	else:
		_defeat()

func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	sprite.play("death")
	await get_tree().create_timer(0.35).timeout
	emit_signal("defeated", self)
	MusicManager.stop_sfx("mosquito")
	MusicManager.play_sfx("splat")
	queue_free()

func _start_attack_countdown() -> void:
	MusicManager.play_sfx("mosquito")
	MusicManager.set_sfx_volume_for("mosquito", 15)
	await get_tree().create_timer(attack_delay).timeout
	if _defeated:
		return
	
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	await get_tree().create_timer(0.35).timeout
	if _defeated:
		return
	emit_signal("attacked", self)
	emit_signal("pest_failed", "A mosquito bit you!")
	MusicManager.stop_sfx("mosquito")
	queue_free()

func _process(delta: float) -> void:
	if _defeated:
		return

	if target_pos != Vector2.ZERO:
		var dir := (target_pos - global_position)
		var dist := dir.length()
		_bob_time += delta
		global_position.y = _base_y + sin(_bob_time * 5.0) * 6.0
	else:
		global_position.y += speed * 0.2 * delta
		_bob_time += delta
		global_position.y = _base_y + sin(_bob_time * 2.0) * 6.0

	if combo_display:
		combo_display.position = Vector2(0, -50)

func _update_combo_display() -> void:
	if combo_display == null:
		return
	for child in combo_display.get_children():
		child.queue_free()

	var combo_req := get_current_combo()
	var x_offset := 0
	for step in combo_req:
		if arrow_textures.has(step):
			var icon := TextureRect.new()
			icon.texture = arrow_textures[step]
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(32,32)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.position = Vector2(x_offset, 0)
			x_offset += 36
			combo_display.add_child(icon)

func _normalize_step(s) -> String:
	var st := str(s)
	if st == "↑" or st.to_lower() == "up":
		return "UP"
	if st == "↓" or st.to_lower() == "down":
		return "DOWN"
	if st == "←" or st.to_lower() == "left":
		return "LEFT"
	if st == "→" or st.to_lower() == "right":
		return "RIGHT"
	if st == "Z" or st.to_lower() == "z" or st.to_lower() == "ui_accept":
		return "Z"
	return st.to_upper()

func _normalize_array(arr: Array) -> Array:
	var out := []
	for e in arr:
		out.append(_normalize_step(e))
	return out

func _arrays_equal_normalized(a: Array, b: Array) -> bool:
	if a == null or b == null:
		return false
	if a.size() != b.size():
		return false
	var na := _normalize_array(a)
	var nb := _normalize_array(b)
	for i in range(na.size()):
		if str(na[i]) != str(nb[i]):
			return false
	return true
