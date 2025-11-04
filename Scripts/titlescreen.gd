extends CanvasLayer

@export var solo_scene_path: String = "res://Scenes/tutorial.tscn"
@export var versus_scene_path: String = "res://VersusScenes/versus_main.tscn"
@export var infinite_scene_path: String = "res://Scenes/infinite.tscn"

@onready var fade_rect: ColorRect = $ColorRect
@onready var options: Array[Label] = [
	$VBoxContainer/Solo,
	$VBoxContainer/Versus,
	$VBoxContainer/Infinite
]
@onready var arrow: Label = $Arrow
@onready var title: AnimatedSprite2D = $Title
@onready var language_button: Button = $LanguageButton

var bounce_tween: Tween
var option_selected: bool = false

# 0 = gamemode select, 1 = language button
var menu_zone: int = 0
var selected_index: int = 0

# Prevent repeated joystick input
var input_cooldown := 0.0
const INPUT_COOLDOWN_TIME := 0.25  # seconds

func _ready() -> void:
	option_selected = false
	MusicManager.play_bgm(preload("res://Audio/Backgroundre.ogg"), true)
	_update_arrow_position()
	_start_bounce()
	language_button.pressed.connect(_on_language_button_pressed)
	_apply_language_to_ui()

func _process(delta: float) -> void:
	if input_cooldown > 0.0:
		input_cooldown -= delta

# -----------------------------
# Input
# -----------------------------
func _unhandled_input(event: InputEvent) -> void:
	if input_cooldown > 0.0:
		return

	if event.is_action_pressed("joystickUp") and menu_zone == 0:
		selected_index = (selected_index - 1 + options.size()) % options.size()
		MusicManager.play_sfx("menu")
		_update_arrow_position()
		input_cooldown = INPUT_COOLDOWN_TIME

	elif event.is_action_pressed("joystickDown") and menu_zone == 0:
		selected_index = (selected_index + 1) % options.size()
		MusicManager.play_sfx("menu")
		_update_arrow_position()
		input_cooldown = INPUT_COOLDOWN_TIME

	elif event.is_action_pressed("joystickRight"):
		if menu_zone < 1:
			menu_zone += 1
			selected_index = 0
			MusicManager.play_sfx("menu")
			_update_arrow_position() # instantly, no tween
			input_cooldown = INPUT_COOLDOWN_TIME

	elif event.is_action_pressed("joystickLeft"):
		if menu_zone > 0:
			menu_zone -= 1
			selected_index = 0
			MusicManager.play_sfx("menu")
			_update_arrow_position() # instantly, no tween
			input_cooldown = INPUT_COOLDOWN_TIME

	elif event.is_action_pressed("joystickStart"):
		_handle_accept()
		input_cooldown = INPUT_COOLDOWN_TIME

# -----------------------------
# Update Arrow
# -----------------------------
func _update_arrow_position() -> void:
	if bounce_tween and bounce_tween.is_running():
		bounce_tween.kill()

	var target_pos: Vector2
	var rotation: float

	match menu_zone:
		0:
			# Gamemode select — arrow to the left of text
			var target_label := options[selected_index]
			var label_rect := target_label.get_global_rect()
			var left_edge := label_rect.position.x
			var vertical_center := label_rect.position.y + label_rect.size.y / 2
			target_pos = Vector2(left_edge - arrow.size.x + 220, vertical_center - arrow.size.y / 2)
			rotation = 0

		1:
			# Language button — arrow below and pointing up
			var button_rect := language_button.get_global_rect()
			var button_bottom := button_rect.position.y + button_rect.size.y
			var button_center_x := button_rect.position.x + button_rect.size.x / 2
			target_pos = Vector2(button_center_x - arrow.size.x / 2 + 105, button_bottom + 35)
			rotation = -90

	arrow.global_position = target_pos
	arrow.rotation_degrees = rotation
	_start_bounce()

# -----------------------------
# Arrow bounce
# -----------------------------
func _start_bounce() -> void:
	if bounce_tween and bounce_tween.is_running():
		bounce_tween.kill()

	bounce_tween = create_tween().set_loops()

	if menu_zone == 0:
		# Small left-right wiggle for gamemode select
		var left_x := arrow.position.x - 6
		var right_x := arrow.position.x
		bounce_tween.tween_property(arrow, "position:x", left_x, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bounce_tween.tween_property(arrow, "position:x", right_x, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		# Vertical bounce for language button
		var up_y := arrow.position.y - 6
		var down_y := arrow.position.y
		bounce_tween.tween_property(arrow, "position:y", up_y, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bounce_tween.tween_property(arrow, "position:y", down_y, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# -----------------------------
# Handle Accept
# -----------------------------
func _handle_accept() -> void:
	MusicManager.play_sfx("select")
	if menu_zone == 0:
		_select_option()
	elif menu_zone == 1:
		_on_language_button_pressed()

# -----------------------------
# Language Button
# -----------------------------
func _on_language_button_pressed() -> void:
	await fade_out(0.3)
	if LocalizationManager.current_language == "jp":
		LocalizationManager.current_language = "en"
	else:
		LocalizationManager.current_language = "jp"
	_apply_language_to_ui()
	await fade_in(0.3)

# -----------------------------
# Level Select Option
# -----------------------------
func _select_option() -> void:
	option_selected = true
	if bounce_tween and bounce_tween.is_running():
		bounce_tween.kill()

	var selected_label := options[selected_index]
	var arrow_orig_x := arrow.position.x
	var label_orig_x := selected_label.position.x
	var original_color := selected_label.modulate

	var select_tween := create_tween()
	select_tween.tween_property(arrow, "position:x", arrow.position.x + 30, 0.15)
	select_tween.parallel().tween_property(selected_label, "position:x", selected_label.position.x + 20, 0.15)
	select_tween.parallel().tween_property(selected_label, "modulate", Color(1,1,0.8), 0.15)
	select_tween.tween_property(arrow, "position:x", arrow_orig_x, 0.1).set_delay(0.15)
	select_tween.parallel().tween_property(selected_label, "position:x", label_orig_x, 0.1).set_delay(0.15)
	select_tween.parallel().tween_property(selected_label, "modulate", original_color, 0.1).set_delay(0.15)

	await select_tween.finished
	await fade_out(0.5)

	var path: String
	match selected_index:
		0: path = solo_scene_path
		1: path = versus_scene_path
		2: path = infinite_scene_path
	get_tree().change_scene_to_file(path)

# -----------------------------
# Fade
# -----------------------------
func fade_out(time: float = 0.5) -> void:
	fade_rect.visible = true
	var shader_mat := fade_rect.material
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		shader_mat.set_shader_parameter("alpha", timer / time)
		await get_tree().create_timer(0.0).timeout
	shader_mat.set_shader_parameter("alpha", 1.0)

func fade_in(time: float = 0.5) -> void:
	var shader_mat := fade_rect.material
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		shader_mat.set_shader_parameter("alpha", 1.0 - (timer / time))
		await get_tree().create_timer(0.0).timeout
	shader_mat.set_shader_parameter("alpha", 0.0)
	fade_rect.visible = false

# -----------------------------
# Language + Fonts
# -----------------------------
func _apply_language_to_ui() -> void:
	var font = LocalizationManager.get_font()
	for label in options:
		label.add_theme_font_override("font", font)

	options[0].text = LocalizationManager.t("Solo")
	options[1].text = LocalizationManager.t("Versus")
	options[2].text = LocalizationManager.t("Infinite")

	if LocalizationManager.current_language == "jp":
		title.play("jp_title")
	else:
		title.play("title")

	await get_tree().process_frame
	_update_arrow_position()
	_start_bounce()
