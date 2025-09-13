extends Node2D
class_name Mosquito

signal defeated
signal attacked

# --- Editable properties per-pest instance ---
@export var speed: float = 30.0                # movement speed toward target
@export var attack_delay: float = 8.0         # seconds before attack if not defeated
@export var approach_threshold: float = 24.0   # distance to target to hover
@export var combos_stages := [["→", "Z"]]

@export var require_all_stages: bool = true

# Optional target (global position) to move toward (set by manager or defaults to center)
var target_pos: Vector2 = Vector2.ZERO

# runtime state
var _current_stage: int = 0
var _defeated: bool = false
var _base_y: float = 0.0
var _bob_time: float = 0.0

# nodes
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var combo_display: Control = $ComboDisplay
# arrow image map - use Texture or Sprite frames as TextureRect
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
	# start attack countdown
	_start_attack_countdown()

# Set target position (call from manager if desired)
func set_target_pos(p: Vector2) -> void:
	target_pos = p

# Return the current stage's combo (array) so external can inspect
func get_current_combo() -> Array:
	if _current_stage >= 0 and _current_stage < combos_stages.size():
		return combos_stages[_current_stage]
	return []

# Compare submitted sequence to the current stage combo and handle it.
# Returns true if the pest consumed/handled the sequence (so manager can stop further processing).
func check_sequence(sequence: Array) -> bool:
	if _defeated:
		return false
	var combo_req := get_current_combo()
	# Only check if the sequence length matches this pest's combo length
	if sequence.size() != combo_req.size():
		return false  # ignore, not for me
	if _arrays_equal_normalized(sequence, combo_req):
		_on_stage_success()
		return true
	else:
		# Only fail if the player *intended* to match (length is same)
		emit_signal("pest_failed", "You entered the wrong combo!")
		queue_free()
		return true

# Called when a stage is matched
func _on_stage_success() -> void:
	# if require_all_stages, advance or finish; otherwise finish immediately
	if require_all_stages:
		_current_stage += 1
		if _current_stage >= combos_stages.size():
			# fully defeated
			_defeat()
			return
		# else update display for next stage
		_update_combo_display()
	else:
		_defeat()

func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	sprite.play("death")
	# small delay to allow animation
	await get_tree().create_timer(0.35).timeout
	emit_signal("defeated", self)
	MusicManager.stop_sfx("mosquito")
	MusicManager.play_sfx("splat")
	MusicManager.set_sfx_volume_for("splat", 5)

	queue_free()

# attack countdown - if not defeated before time expires it attacks
func _start_attack_countdown() -> void:
	MusicManager.play_sfx("mosquito")
	MusicManager.set_sfx_volume_for("mosquito", 20)
	await get_tree().create_timer(attack_delay).timeout
	if _defeated:
		return
	# play attack anim if present
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
	await get_tree().create_timer(0.35).timeout
	if _defeated:
		return
	emit_signal("attacked", self)
	emit_signal("pest_failed", "A mosquito bit you!")
	queue_free()

# movement & hover
func _process(delta: float) -> void:
	if _defeated:
		return

	# move toward target (if set). Default: small downward drift
	if target_pos != Vector2.ZERO:
		var dir := (target_pos - global_position)
		var dist := dir.length()
		if dist > approach_threshold:
			global_position += dir.normalized() * speed * delta
		else:
			# hover in place if reached near target
			_bob_time += delta
			global_position.y = _base_y + sin(_bob_time * 5.0) * 6.0
	else:
		# simple downward movement if no target
		global_position.y += speed * 0.2 * delta
		_bob_time += delta
		global_position.y = _base_y + sin(_bob_time * 2.0) * 6.0

	# keep combo_display positioned relative to mosquito
	if combo_display:
		combo_display.position = Vector2(0, -50)

# helper to update arrow icons above pest
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

# small normalization and comparison helper
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
