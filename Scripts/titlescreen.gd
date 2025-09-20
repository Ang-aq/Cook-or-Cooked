extends CanvasLayer

@export var solo_scene_path: String = "res://Scenes/tutorial.tscn"
@export var versus_scene_path: String = "res://VersusScenes/versus_main.tscn"
@export var infinite_scene_path: String = "res://infinite.tscn"

@onready var fade_rect: ColorRect = $ColorRect

@onready var options: Array[Label] = [
	$VBoxContainer/Solo,
	$VBoxContainer/Versus,
	$VBoxContainer/Infinite
]
@onready var arrow: Label = $Arrow
@onready var title: AnimatedSprite2D = $Title

@onready var volume_button: Button = $VolumeButton
@onready var volume_menu: Control = $VolumeMenu   
@onready var music_slider: HSlider = $VolumeMenu/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $VolumeMenu/VBoxContainer/SfxSlider

var selected_index: int = 0
var bounce_tween: Tween
var option_selected: bool = false


func _disable_focus_recursive(node: Node) -> void:
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_disable_focus_recursive(child)

func _ready() -> void:
	option_selected = false
	MusicManager.play_bgm(preload("res://Audio/Backgroundre.ogg"), true)
	_update_arrow_position()
	_start_bounce()
	title.play("title")
	
	volume_button.focus_mode = Control.FOCUS_NONE
	volume_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Hide menu at start
	volume_menu.visible = false
	_disable_focus_recursive(volume_menu)

	# Connect button
	volume_button.pressed.connect(_on_volume_button_pressed)

	# Connect sliders
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_value_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)

	# Set slider values from MusicManager
	var mv := MusicManager.get_music_volume()
	var sv := MusicManager.get_sfx_volume()
	if music_slider:
		music_slider.value = mv
	if sfx_slider:
		sfx_slider.value = sv


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("joystickUp"):
		selected_index = (selected_index - 1 + options.size()) % options.size()
		_update_arrow_position()
		MusicManager.play_sfx("menu")
	elif event.is_action_pressed("joystickDown"):
		selected_index = (selected_index + 1) % options.size()
		_update_arrow_position()
		MusicManager.play_sfx("menu")
	elif event.is_action_pressed("joystickStart"):
		if option_selected == false:
			_select_option()
			MusicManager.play_sfx("select")


func _update_arrow_position() -> void:
	var target_label := options[selected_index]
	arrow.global_position = target_label.global_position + Vector2(-40, 0)


func _start_bounce() -> void:
	if bounce_tween and bounce_tween.is_running():
		bounce_tween.kill()
	bounce_tween = create_tween().set_loops()
	bounce_tween.tween_property(arrow, "position:x", arrow.position.x - 10, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce_tween.tween_property(arrow, "position:x", arrow.position.x, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _select_option() -> void:
	option_selected = true
	var selected_label := options[selected_index]

	if bounce_tween and bounce_tween.is_running():
		bounce_tween.kill()

	var arrow_orig_x := arrow.position.x
	var label_orig_x := selected_label.position.x
	var original_color := selected_label.modulate

	var select_tween := create_tween()

	select_tween.tween_property(arrow, "position:x", arrow.position.x + 30, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	select_tween.parallel().tween_property(selected_label, "position:x", selected_label.position.x + 20, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	select_tween.parallel().tween_property(selected_label, "modulate", Color(1,1,0.8), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	select_tween.tween_property(arrow, "position:x", arrow_orig_x, 0.1) \
		.set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	select_tween.parallel().tween_property(selected_label, "position:x", label_orig_x, 0.1) \
		.set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	select_tween.parallel().tween_property(selected_label, "modulate", original_color, 0.1) \
		.set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await select_tween.finished
	await fade_out(0.5)

	var path: String
	match selected_index:
		0:
			path = solo_scene_path
		1:
			path = versus_scene_path
		2:
			path = infinite_scene_path
		_:
			path = solo_scene_path  # fallback

	var err = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (err %s)" % [path, str(err)])

func fade_out(time: float = 0.5) -> void:
	fade_rect.visible = true
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = timer / time
		await get_tree().create_timer(0.0).timeout
	fade_rect.modulate.a = 1.0

func fade_in(time: float = 0.5) -> void:
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = 1.0 - (timer / time)
		await get_tree().create_timer(0.0).timeout
	fade_rect.modulate.a = 0.0
	fade_rect.visible = false

func _on_volume_button_pressed() -> void:
	volume_menu.visible = not volume_menu.visible

func _on_music_slider_value_changed(value: float) -> void:
	MusicManager.set_music_volume(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	MusicManager.set_all_sfx_volume(value)
