extends Node

var input_buffer: Array[String] = []

signal sequence_submitted(sequence: Array[String])
signal sequence_reset()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("joystickUp"):
		input_buffer.append("↑")
	elif Input.is_action_just_pressed("joystickDown"):
		input_buffer.append("↓")
	elif Input.is_action_just_pressed("joystickLeft"):
		input_buffer.append("←")
	elif Input.is_action_just_pressed("joystickRight"):
		input_buffer.append("→")

	elif Input.is_action_just_pressed("joystickStart"):
		input_buffer.append("Z")
		emit_signal("sequence_submitted", input_buffer.duplicate())
		input_buffer.clear()

	elif Input.is_action_just_pressed("joystickReset"):
		input_buffer.clear()
		emit_signal("sequence_reset")
