extends CanvasLayer
class_name TutorialDialog

@onready var ui_bg = $UI
@onready var fade_fx = $Transition
@onready var text_label = $UI/TextLabel
@onready var continue_label = $UI/ContinueLabel
@onready var portrait = $UI/Portrait

signal dialogue_finished

var lines: Array[String] = []
var portraits: Array[Texture] = []
var current_line: int = 0
var is_scrolling: bool = false
var dialogue_active: bool = false
var input_locked: bool = false


func start_dialogue(new_lines: Array[String], new_portraits: Array[Texture] = []) -> void:
	continue_label.text = LocalizationManager.t("Continue")
	lines = new_lines
	portraits = new_portraits
	current_line = 0
	dialogue_active = true
	visible = true
	input_locked = true

	ui_bg.visible = false
	text_label.text = ""
	continue_label.visible = false

	fade_fx.visible = true
	fade_fx.play("fade_in")
	await fade_fx.animation_finished
	fade_fx.visible = false

	ui_bg.visible = true
	input_locked = false
	_show_line()

func _show_line() -> void:
	if current_line >= lines.size():
		_end_dialogue()
		return
	is_scrolling = true
	text_label.text = ""
	continue_label.visible = false

	if current_line < portraits.size() and portraits[current_line] != null:
		portrait.texture = portraits[current_line]

	await _scroll_text(lines[current_line])
	is_scrolling = false
	continue_label.visible = true

func _scroll_text(text: String) -> void:
	text_label.text = "" 
	for i in text.length():
		if not is_scrolling:
			break
		text_label.text += text[i]
		await get_tree().create_timer(0.04).timeout
	text_label.text = text
	is_scrolling = false

func _input(event: InputEvent) -> void:
	if not dialogue_active or input_locked:
		return
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseButton:
		if is_scrolling:
			is_scrolling = false
		else:
			_next_line()

func _next_line() -> void:
	current_line += 1
	if current_line < lines.size():
		_show_line()
	else:
		_end_dialogue()

func _end_dialogue() -> void:
	dialogue_active = false
	continue_label.visible = false
	ui_bg.visible = false

	fade_fx.visible = true
	fade_fx.play("fade_out")
	await fade_fx.animation_finished

	fade_fx.visible = false
	visible = false
	emit_signal("dialogue_finished")
