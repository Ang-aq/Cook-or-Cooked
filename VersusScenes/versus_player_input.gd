extends Node

@export var player_id: int = 2
var input_buffer: Array[String] = []

@onready var input_display: HBoxContainer = $InputDisplay
@export var max_buffer_size: int = 5

signal sequence_submitted(sequence: Array, player_id: int)
signal sequence_reset(player_id: int)
signal buffer_changed(sequence: Array, player_id: int)

# small arrow textures (reuse your sprite assets)
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

var ACTIONS := {
	1: {"up":"p1_up","down":"p1_down","left":"p1_left","right":"p1_right","submit":"p1_submit","reset":"p1_reset"},
	2: {"up":"p2_up","down":"p2_down","left":"p2_left","right":"p2_right","submit":"p2_submit","reset":"p2_reset"}
}

func _unhandled_input(event: InputEvent) -> void:
	var map = ACTIONS.get(player_id, ACTIONS[1])
	var added := false
	var step_pressed := ""

	if event.is_action_pressed(map.up) and input_buffer.size() < max_buffer_size:
		input_buffer.append("↑"); step_pressed = "↑"; added = true
	elif event.is_action_pressed(map.down) and input_buffer.size() < max_buffer_size:
		input_buffer.append("↓"); step_pressed = "↓"; added = true
	elif event.is_action_pressed(map.left) and input_buffer.size() < max_buffer_size:
		input_buffer.append("←"); step_pressed = "←"; added = true
	elif event.is_action_pressed(map.right) and input_buffer.size() < max_buffer_size:
		input_buffer.append("→"); step_pressed = "→"; added = true
	elif event.is_action_pressed(map.submit):
		if input_buffer.size() > 0:
			input_buffer.append("Z")
			emit_signal("sequence_submitted", input_buffer.duplicate(), player_id)
			input_buffer.clear()
			added = true
	elif event.is_action_pressed(map.reset):
		if input_buffer.size() > 0:
			input_buffer.clear()
			emit_signal("sequence_reset", player_id)
			added = true

	if added:
		_update_display()
		emit_signal("buffer_changed", input_buffer.duplicate(), player_id)
		if step_pressed != "":
			var mm = get_tree().get_root().get_node_or_null("/root/MusicManager")
			if mm and mm.has_method("play_sfx"):
				mm.play_sfx("chop")

func _update_display() -> void:
	for ch in input_display.get_children():
		ch.queue_free()
	for step in input_buffer:
		if arrow_textures.has(step):
			var tex := TextureRect.new()
			tex.texture = arrow_textures[step]
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(48, 48)  # smaller arrows for 1v1
			input_display.add_child(tex)
