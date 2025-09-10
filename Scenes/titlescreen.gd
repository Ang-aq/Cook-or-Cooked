extends CanvasLayer

@export var solo_scene_path: String = "res://Scenes/tutorial_options.tscn"
@export var versus_scene_path: String = "res://VersusScenes/versus_main.tscn"
@onready var fade_rect: ColorRect = $ColorRect

@onready var options: Array[Label] = [
	$VBoxContainer/Solo,
	$VBoxContainer/Versus
]
@onready var arrow: Label = $Arrow
@onready var title: AnimatedSprite2D = $Title

var selected_index: int = 0
var bounce_tween: Tween

func _ready() -> void:
	MusicManager.play_bgm(preload("res://Audio/Backgroundre.ogg"), true)
	_update_arrow_position()
	_start_bounce()
	title.play("title")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("joystickUp"):
		selected_index = (selected_index - 1 + options.size()) % options.size()
		_update_arrow_position()
	elif event.is_action_pressed("joystickDown"):
		selected_index = (selected_index + 1) % options.size()
		_update_arrow_position()
	elif event.is_action_pressed("joystickStart"):
		_select_option()

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
	# fade to black first
	if selected_index != 0: 
		await fade_out(0.5)

	# pick path and change the current scene properly (so get_tree().current_scene stays valid)
	var path := solo_scene_path if selected_index == 0 else versus_scene_path
	var err = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (err %s)" % [path, str(err)])

func fade_out(time: float = 0.5) -> void:
	fade_rect.visible = true
	var timer := 0.0
	while timer < time:
		timer += get_process_delta_time()
		fade_rect.modulate.a = timer / time
		# wait one frame portably in Godot 4
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
