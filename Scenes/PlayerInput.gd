extends Node

# Current sequence being typed
var input_buffer: Array[String] = []

@onready var input_display: HBoxContainer = $InputDisplay  # Container for arrow images

signal sequence_submitted(sequence: Array[String])
signal sequence_reset()

# Map input symbols to textures
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

func _unhandled_input(event: InputEvent) -> void:
	var added := false
	if event.is_action_pressed("joystickUp"):
		input_buffer.append("↑")
		added = true
	elif event.is_action_pressed("joystickDown"):
		input_buffer.append("↓")
		added = true
	elif event.is_action_pressed("joystickLeft"):
		input_buffer.append("←")
		added = true
	elif event.is_action_pressed("joystickRight"):
		input_buffer.append("→")
		added = true
	elif event.is_action_pressed("joystickStart"): # Z
		input_buffer.append("Z")
		emit_signal("sequence_submitted", input_buffer.duplicate())
		input_buffer.clear()
		added = true
	elif event.is_action_pressed("joystickReset"): # X
		input_buffer.clear()
		emit_signal("sequence_reset")
		added = true

	if added:
		_update_display()

# Display current input sequence as arrow images
func _update_display() -> void:
	# Clear old arrows
	for child in input_display.get_children():
		child.queue_free()

	# Add new arrows
	for step in input_buffer:
		if arrow_textures.has(step):
			var tex := TextureRect.new()
			tex.texture = arrow_textures[step]
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

			# Make the arrow bigger
			tex.custom_minimum_size = Vector2(80, 80)  # adjust size as needed

			input_display.add_child(tex)
