extends Node

# Stores the current input sequence the player is typing
var input_buffer: Array[String] = []

signal sequence_submitted(sequence: Array[String])
signal sequence_reset()


func _input(event: InputEvent) -> void:
	# Arrow keys → add to buffer
	if Input.is_action_just_pressed("joystickUp"):
		input_buffer.append("↑")
	elif Input.is_action_just_pressed("joystickDown"):
		input_buffer.append("↓")
	elif Input.is_action_just_pressed("joystickLeft"):
		input_buffer.append("←")
	elif Input.is_action_just_pressed("joystickRight"):
		input_buffer.append("→")

	# Confirm → send sequence
	elif Input.is_action_just_pressed("joystickStart"):
		input_buffer.append("Z")
		emit_signal("sequence_submitted", input_buffer.duplicate())
		input_buffer.clear()

	# Reset → clear buffer
	elif Input.is_action_just_pressed("joystickReset"):
		input_buffer.clear()
		emit_signal("sequence_reset")
