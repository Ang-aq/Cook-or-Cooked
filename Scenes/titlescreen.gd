extends CanvasLayer

@onready var vbox: VBoxContainer = $MenuVBox
@onready var arrow: TextureRect = $SelectorArrow
@onready var sfx_player: AudioStreamPlayer2D = $SfxPlayer

var buttons: Array[Button] = []
var selected_index: int = 0
var wobble_tween: Tween

func _ready() -> void:
	# Collect all buttons in the VBox
	for child in vbox.get_children():
		if child is Button:
			buttons.append(child)
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			child.focus_mode = Control.FOCUS_NONE

	# Place arrow at the first button instantly
	_move_arrow_to(selected_index, true)
	_start_wobble()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("joystickDown"):
		selected_index = (selected_index + 1) % buttons.size()
		_move_arrow_to(selected_index)

	elif event.is_action_pressed("joystickUp"):
		selected_index = (selected_index - 1 + buttons.size()) % buttons.size()
		_move_arrow_to(selected_index)

	elif event.is_action_pressed("joystickStart"): # Z key
		_press_selected_button()

func _move_arrow_to(index: int, instant := false) -> void:
	var btn: Button = buttons[index]

	var target_pos = btn.global_position + Vector2(
		-arrow.texture.get_width() - 70,
		btn.size.y / 2 - arrow.size.y / 2
	)

	if instant:
		arrow.global_position = target_pos
	else:
		var tween = create_tween()
		tween.tween_property(arrow, "global_position", target_pos, 0.25) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)

func _press_selected_button() -> void:
	var btn: Button = buttons[selected_index]

	# playButton sfx
	sfx_player.play()

	# Show pressed texture briefly
	btn.button_pressed = true
	await get_tree().create_timer(0.15).timeout
	btn.button_pressed = false

	# Do action
	match btn.name:
		"ButtonPlay":
			get_tree().change_scene_to_file("res://Scenes/main.tscn")
		"ButtonQuit":
			get_tree().quit()

func _start_wobble() -> void:
	if wobble_tween:
		wobble_tween.kill()

	wobble_tween = create_tween().set_loops()
	var base_x = arrow.position.x
	wobble_tween.tween_property(arrow, "position:x", base_x - 5, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_tween.tween_property(arrow, "position:x", base_x + 5, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_tween.tween_property(arrow, "position:x", base_x, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
