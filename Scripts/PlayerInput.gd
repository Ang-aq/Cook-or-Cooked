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

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
		
	var added := false
	var step_pressed := "" 

	if event.is_action_pressed("joystickUp"):
		input_buffer.append("↑")
		step_pressed = "↑"
		added = true
	elif event.is_action_pressed("joystickDown"):
		input_buffer.append("↓")
		step_pressed = "↓"
		added = true
	elif event.is_action_pressed("joystickLeft"):
		input_buffer.append("←")
		step_pressed = "←"
		added = true
	elif event.is_action_pressed("joystickRight"):
		input_buffer.append("→")
		step_pressed = "→"
		added = true
	elif event.is_action_pressed("joystickStart"): # Z (submit)
		input_buffer.append("Z")
		emit_signal("sequence_submitted", input_buffer.duplicate())
		input_buffer.clear()
		added = true
	elif event.is_action_pressed("joystickReset"): # X (reset)
		input_buffer.clear()
		emit_signal("sequence_reset")
		added = true

	if added:
		_update_display()
		emit_signal("buffer_changed", input_buffer.duplicate())

		if step_pressed != "":
			MusicManager.play_sfx("chop")

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
