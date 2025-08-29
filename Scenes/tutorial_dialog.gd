extends CanvasLayer

@onready var tutorial_ui = $UI/TutorialUI
@onready var text_label = $UI/TextLabel
@onready var continue_label = $UI/ContinueLabel
@onready var anim_sprite = $TutorialUI as AnimatedSprite2D

signal dialogue_finished

var lines: Array = []
var current_line: int = 0
var is_scrolling: bool = false

func start_dialogue(new_lines: Array) -> void:
	lines = new_lines
	current_line = 0
	visible = true
	text_label.text = ""
	continue_label.visible = false
	anim_sprite.visible = false
	_show_line()

func _show_line() -> void:
	is_scrolling = true
	text_label.text = ""
	continue_label.visible = false
	await scroll_text(lines[current_line])
	continue_label.visible = true

func scroll_text(input_text: String) -> void:
	var char_index := 0
	while char_index < input_text.length():
		text_label.text += input_text[char_index]
		char_index += 1
		await get_tree().create_timer(0.05).timeout
	is_scrolling = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseButton:
		if is_scrolling:
			# Skip to full line immediately
			text_label.text = lines[current_line]
			is_scrolling = false
			continue_label.visible = true
		else:
			_next_line()

func _next_line() -> void:
	current_line += 1
	if current_line < lines.size():
		_show_line()
	else:
		_play_fade_animation()

func _play_fade_animation() -> void:
	# Hide text and continue label
	text_label.text = ""
	continue_label.visible = false

	# Show animation sprite on top
	anim_sprite.visible = true
	anim_sprite.play("fade_out")

	# Wait for animation to finish
	await anim_sprite.animation_finished

	# Hide everything after animation
	anim_sprite.visible = false
	tutorial_ui.visible = false
	visible = false
	emit_signal("dialogue_finished")
