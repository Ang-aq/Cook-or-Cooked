extends CanvasLayer
class_name TutorialDialog

# --- Nodes ---
@onready var ui_bg = $UI                  # TextureRect / Panel for static UI
@onready var fade_fx = $Transition        # AnimatedSprite2D for fade animations
@onready var text_label = $UI/TextLabel
@onready var continue_label = $UI/ContinueLabel
@onready var portrait = $UI/Portrait      # TextureRect for character expression

signal dialogue_finished

# --- State ---
var lines: Array[String] = []
var portraits: Array[Texture] = []
var current_line: int = 0
var is_scrolling: bool = false
var dialogue_active: bool = false

# --- Start Dialogue ---
func start_dialogue(new_lines: Array[String], new_portraits: Array[Texture] = []) -> void:
	lines = new_lines
	portraits = new_portraits
	current_line = 0
	dialogue_active = true
	visible = true

	# Reset UI
	ui_bg.visible = false
	text_label.text = ""
	continue_label.visible = false

	# Fade in transition
	fade_fx.visible = true
	fade_fx.play("fade_in")
	await fade_fx.animation_finished
	fade_fx.visible = false

	# Show static background
	ui_bg.visible = true
	_show_line()

# --- Show one line ---
func _show_line() -> void:
	is_scrolling = true
	text_label.text = ""
	continue_label.visible = false

	# Set portrait if provided
	if current_line < portraits.size() and portraits[current_line] != null:
		portrait.texture = portraits[current_line]

	await _scroll_text(lines[current_line])
	is_scrolling = false
	continue_label.visible = true

# --- Typewriter effect ---
func _scroll_text(text: String) -> void:
	var i := 0
	while i < text.length():
		text_label.text += text[i]
		i += 1
		await get_tree().create_timer(0.04).timeout
		if not is_scrolling:
			text_label.text = text
			return
	is_scrolling = false

# --- Input ---
func _input(event: InputEvent) -> void:
	if not dialogue_active:
		return
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseButton:
		if is_scrolling:
			is_scrolling = false
			text_label.text = lines[current_line]
			continue_label.visible = true
		else:
			_next_line()

# --- Next line ---
func _next_line() -> void:
	current_line += 1
	if current_line < lines.size():
		_show_line()
	else:
		_end_dialogue()

# --- End dialogue ---
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
