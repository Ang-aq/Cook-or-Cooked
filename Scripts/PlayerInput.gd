extends Node

var input_buffer: Array[String] = []
var input_enabled: bool = true
@onready var input_display: HBoxContainer = $InputDisplay

signal sequence_submitted(sequence: Array[String])
signal sequence_reset()
signal buffer_changed(sequence: Array)

var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

const MAX_BUFFER_SIZE := 10
const DEADZONE := 0.4  # ignore small movements

var last_direction := ""        # last pressed direction
var same_dir_locked := false    # prevents repeating same dir until recentered

func _process(delta: float) -> void:
	if not input_enabled:
		return

	var axis_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var axis_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	var new_direction := ""
	if abs(axis_x) > DEADZONE or abs(axis_y) > DEADZONE:
		# choose the dominant axis
		if abs(axis_x) > abs(axis_y):
			new_direction = "→" if axis_x > 0 else "←"
		else:
			new_direction = "↓" if axis_y > 0 else "↑"

		# Only register if:
		# 1. It’s a *different* direction, OR
		# 2. The stick was previously neutral and we’re reusing the same direction
		if new_direction != last_direction or not same_dir_locked:
			_add_to_buffer(new_direction)
			MusicManager.play_sfx("chop")
			same_dir_locked = true
			last_direction = new_direction
	else:
		# Stick in neutral → allow repeating same direction again
		same_dir_locked = false

	# Handle submit/reset
	if Input.is_action_just_pressed("joystickStart"):
		_add_to_buffer("Z")
		emit_signal("sequence_submitted", input_buffer.duplicate())
		input_buffer.clear()
	elif Input.is_action_just_pressed("joystickReset"):
		input_buffer.clear()
		emit_signal("sequence_reset")

	_update_display()
	emit_signal("buffer_changed", input_buffer.duplicate())

# -------------------------
# Add with buffer limit
# -------------------------
func _add_to_buffer(step: String) -> void:
	if input_buffer.size() >= MAX_BUFFER_SIZE:
		return
	input_buffer.append(step)

# -------------------------
# Update display visuals
# -------------------------
func _update_display() -> void:
	for child in input_display.get_children():
		child.queue_free()

	for step in input_buffer:
		if arrow_textures.has(step):
			var tex := TextureRect.new()
			tex.texture = arrow_textures[step]
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(80, 80)
			input_display.add_child(tex)
