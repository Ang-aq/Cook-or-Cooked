extends Node

@onready var tutorial_dialog: TutorialDialog = $TutorialDialog
@onready var meat: AnimatedSprite2D = $Meat
@onready var indicator: Node2D = $UI/Right
@onready var combo_container: Node2D = $UI/ComboDisplay
@onready var player_input: Node = $UI/PlayerInput
@onready var arrow_indicator: ArrowIndicator = $UI/Directions
@onready var keys: AnimatedSprite2D = $UI/Keys
@onready var pot: AnimatedSprite2D = $Pot
@onready var skip_label: Label = $Skip

# UI references
@onready var HeartTarget = $UI/HeartT
@onready var TimerTarget = $UI/TimerT
@onready var ChecklistTarget = $UI/ChecklistT

var arrow_combo: Array[String] = ["ui_right", "ui_up"]
var player_progress: int = 0
var waiting_for_input: bool = false
var ready_for_combo: bool = false
var input_locked: bool = false

@export var fall_speed: float = 160.0
@export var stop_y: float = 400.0
@export var start_x: float = 300.0
@export var start_y: float = -50.0
@export var main_scene_path: String = "res://Scenes/main.tscn"

@export var arrow_textures: Dictionary = {
	"ui_up": preload("res://Sprites/arrow_up.png"),
	"ui_down": preload("res://Sprites/arrow_down.png"),
	"ui_left": preload("res://Sprites/arrow_left.png"),
	"ui_right": preload("res://Sprites/arrow_right.png")
}

var meat_falling: bool = false
var meat_already_stopped: bool = false
var instruction_shown: bool = false

func _ready() -> void:
	var tween := create_tween()
	tween.set_loops() 
	tween.tween_property(skip_label, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(skip_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pot.play("boil")
	
	if not tutorial_dialog.dialogue_finished.is_connected(_on_intro_dialogue_finished):
		tutorial_dialog.dialogue_finished.connect(_on_intro_dialogue_finished)
	if not player_input.sequence_submitted.is_connected(_on_sequence_submitted):
		player_input.sequence_submitted.connect(_on_sequence_submitted)

	meat.visible = false
	indicator.visible = false
	combo_container.visible = false
	player_input.input_display.visible = false
	arrow_indicator.hide()

	var intro_lines: Array[String] = [
		"Oh hello, you must be the chef's new apprentice!",
		"I work here too. I'll teach you the basics of this place.",
		"First is to collect ingredients. Look, there's one now!"
	]
	var portraits: Array[Texture] = [
		load("res://Sprites/Portrait1.png"),
		load("res://Sprites/Portrait2.png"),
		load("res://Sprites/Portrait3.png")
	]
	tutorial_dialog.start_dialogue(intro_lines, portraits)

func _on_intro_dialogue_finished() -> void:
	tutorial_dialog.dialogue_finished.disconnect(_on_intro_dialogue_finished)
	_start_meat_tutorial()

func _start_meat_tutorial() -> void:
	if meat_already_stopped: return
	meat.position = Vector2(start_x, start_y)
	meat.visible = true
	meat.play("Meat")
	meat_falling = true
	waiting_for_input = false
	ready_for_combo = false
	player_progress = 0
	combo_container.visible = false
	player_input.input_display.visible = false

func _process(delta: float) -> void:
	if meat_falling:
		meat.position.y += fall_speed * delta
		if meat.position.y >= stop_y:
			meat.position.y = stop_y
			meat_falling = false
			meat_already_stopped = true
			if not instruction_shown:
				_show_instruction_dialogue()

func _show_instruction_dialogue() -> void:
	instruction_shown = true
	tutorial_dialog.get_node("UI").position = Vector2(100, -60)
	tutorial_dialog.get_node("Transition").position = Vector2(420, 68)
	
	keys.show()
	indicator.show()
	keys.play("click")
	var prompt: Array[String] = ["Use ARROW KEYS to chop ingredients then press Z to confirm. If you mess up press X to reset."]
	var portraits: Array[Texture] = [load("res://Sprites/Portrait1.png")]

	if not tutorial_dialog.dialogue_finished.is_connected(_on_instruction_dialogue_finished):
		tutorial_dialog.dialogue_finished.connect(_on_instruction_dialogue_finished)

	tutorial_dialog.start_dialogue(prompt, portraits)

func _flash_and_wobble_arrow() -> void:
	if arrow_indicator == null:
		return
	
	var flash = arrow_indicator.create_tween()
	flash.set_loops()  # infinite
	flash.tween_property(arrow_indicator, "modulate", Color.RED, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flash.tween_property(arrow_indicator, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Wobble infinitely....
	var original_x = arrow_indicator.position.x
	var wobble = arrow_indicator.create_tween()
	wobble.set_loops()  
	wobble.tween_property(arrow_indicator, "position:x", original_x + 10, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(arrow_indicator, "position:x", original_x - 10, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(arrow_indicator, "position:x", original_x, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_instruction_dialogue_finished() -> void:
	tutorial_dialog.dialogue_finished.disconnect(_on_instruction_dialogue_finished)
	
	tutorial_dialog.input_locked = true  
	
	_show_combo_arrows()
	player_input.input_display.visible = true

	ready_for_combo = true
	waiting_for_input = true
	player_progress = 0

func _show_combo_arrows() -> void:
	for child in combo_container.get_children():
		child.queue_free()
	combo_container.visible = true
	indicator.show()

func _on_sequence_submitted(sequence: Array[String]) -> void:
	if input_locked or not (ready_for_combo and waiting_for_input):
		return

	if sequence.size() > arrow_combo.size():
		sequence = sequence.slice(0, arrow_combo.size())

	var success = true
	for i in range(sequence.size()):
		var expected = arrow_combo[i]
		var actual = ""
		match sequence[i]:
			"↑": actual = "ui_up"
			"↓": actual = "ui_down"
			"←": actual = "ui_left"
			"→": actual = "ui_right"
		if actual != expected:
			success = false
			break

	if success and sequence.size() == arrow_combo.size():
		_on_combo_success()
	else:
		player_progress = 0
		_update_combo_visual()
		if tutorial_dialog.input_locked == true:
			_show_wrong_input_dialogue()

func _show_wrong_input_dialogue() -> void:
	var wrong_prompt: Array[String] = ["Wrong input, try again!"]
	var portraits: Array[Texture] = [load("res://Sprites/sadt.png")]
	
	tutorial_dialog.input_locked = false
	tutorial_dialog.start_dialogue(wrong_prompt, portraits)
	await tutorial_dialog.dialogue_finished
	tutorial_dialog.input_locked = true
	
	player_input.input_buffer.clear()
	player_input._update_display()

func _update_combo_visual(reset: bool=false) -> void:
	for i in range(combo_container.get_child_count()):
		var arrow = combo_container.get_child(i)
		if reset: arrow.modulate = Color.WHITE
		elif i < player_progress: arrow.modulate = Color(0,1,0)
		else: arrow.modulate = Color.WHITE

func _on_combo_success() -> void:
	waiting_for_input = false
	ready_for_combo = false
	keys.hide()
	meat.hide()
	
	# Unlock dialogue input now that combo is over
	tutorial_dialog.input_locked = false  

	indicator.visible = false
	combo_container.visible = false
	player_input.input_display.visible = false

	var success_lines: Array[String] = ["Perfect!! You're a natural!"]
	var portraits: Array[Texture] = [load("res://Sprites/Portrait3.png")]

	tutorial_dialog.start_dialogue(success_lines, portraits)
	tutorial_dialog.dialogue_finished.connect(_after_chopping)

# === New UI explanation sequence ===
func _after_chopping() -> void:
	tutorial_dialog.dialogue_finished.disconnect(_after_chopping)
	tutorial_dialog.get_node("UI").position = Vector2(100, 365) 
	tutorial_dialog.get_node("Transition").position = Vector2(420, 493) 
	
	arrow_indicator.point_to(HeartTarget)
	_flash_and_wobble_arrow()
	var lines: Array[String] = ["These are your lives. Make mistakes, lose hearts!"]
	var portraits: Array[Texture] = [load("res://Sprites/Portrait1.png")]
	tutorial_dialog.start_dialogue(lines, portraits)
	tutorial_dialog.dialogue_finished.connect(_show_timer_tutorial)

func _show_timer_tutorial() -> void:
	tutorial_dialog.dialogue_finished.disconnect(_show_timer_tutorial)
	arrow_indicator.point_to(TimerTarget)
	_flash_and_wobble_arrow()
	var lines: Array[String] = ["This is the timer. Finish your dish before the time runs out!"]
	var portraits: Array[Texture] = [load("res://Sprites/Portrait1.png")]

	tutorial_dialog.start_dialogue(lines, portraits)
	tutorial_dialog.dialogue_finished.connect(_show_checklist_tutorial)

func _show_checklist_tutorial() -> void:
	tutorial_dialog.dialogue_finished.disconnect(_show_checklist_tutorial)
	arrow_indicator.point_to(ChecklistTarget)
	_flash_and_wobble_arrow()
	var lines: Array[String] = ["This is your ingredient checklist. Complete everything to win!"]
	tutorial_dialog.start_dialogue(lines)
	tutorial_dialog.dialogue_finished.connect(finalLines)

func finalLines() -> void:
	tutorial_dialog.dialogue_finished.disconnect(finalLines)
	var lines: Array[String] = ["Also be careful of pests that like to steal your food or mess you up! If you see any make sure to swat them away."]
	var portraits: Array[Texture] = [load("res://Sprites/sadt.png")]

	tutorial_dialog.start_dialogue(lines, portraits)
	tutorial_dialog.dialogue_finished.connect(finish_tutorial)

func finish_tutorial() -> void:
	tutorial_dialog.dialogue_finished.disconnect(finish_tutorial)
	arrow_indicator.hide()
	get_tree().change_scene_to_file(main_scene_path)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("skipTutorial"):
		_skip_tutorial()

func _skip_tutorial() -> void:
	if tutorial_dialog.dialogue_finished.is_connected(_on_intro_dialogue_finished):
		tutorial_dialog.dialogue_finished.disconnect(_on_intro_dialogue_finished)
	if tutorial_dialog.dialogue_finished.is_connected(_on_instruction_dialogue_finished):
		tutorial_dialog.dialogue_finished.disconnect(_on_instruction_dialogue_finished)
	if tutorial_dialog.dialogue_finished.is_connected(_after_chopping):
		tutorial_dialog.dialogue_finished.disconnect(_after_chopping)
	if tutorial_dialog.dialogue_finished.is_connected(_show_timer_tutorial):
		tutorial_dialog.dialogue_finished.disconnect(_show_timer_tutorial)
	if tutorial_dialog.dialogue_finished.is_connected(_show_checklist_tutorial):
		tutorial_dialog.dialogue_finished.disconnect(_show_checklist_tutorial)
	if tutorial_dialog.dialogue_finished.is_connected(finalLines):
		tutorial_dialog.dialogue_finished.disconnect(finalLines)
	if tutorial_dialog.dialogue_finished.is_connected(finish_tutorial):
		tutorial_dialog.dialogue_finished.disconnect(finish_tutorial)

	meat.hide()
	indicator.hide()
	combo_container.hide()
	keys.hide()
	arrow_indicator.hide()
	player_input.input_display.visible = false
	tutorial_dialog.input_locked = false

	get_tree().change_scene_to_file(main_scene_path)
