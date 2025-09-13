extends Control

@onready var star: TextureRect = $Star
@onready var dish: TextureRect = $Dish
@onready var dish_label: Label = $Label

@export var display_time: float = 1.8
@export var fade_time: float = 0.28

var _visible_timer: Timer = null
var _is_showing: bool = false

func _ready() -> void:
	visible = false
	set_process(false)
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dish.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func show_dish(dish_texture: Texture2D, dish_name: String) -> void:
	dish.texture = dish_texture
	dish_label.text = dish_name

	visible = true
	_is_showing = true
	set_process(true)

	modulate.a = 1.0
	star.modulate.a = 0.0
	dish.modulate.a = 0.0
	dish.scale = Vector2(0.7, 0.7)
	dish_label.modulate.a = 0.0

	MusicManager.play_sfx("level_up")

	var tween = create_tween()
	tween.tween_property(star, "modulate:a", 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(dish, "modulate:a", 1.0, fade_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(dish, "scale", Vector2(1, 1), fade_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(dish_label, "modulate:a", 1.0, fade_time * 1.1)

	if _visible_timer:
		_visible_timer.queue_free()
	_visible_timer = Timer.new()
	_visible_timer.one_shot = true
	_visible_timer.wait_time = display_time
	add_child(_visible_timer)
	_visible_timer.start()
	_visible_timer.timeout.connect(_on_hide_timeout) 

func _on_hide_timeout() -> void:
	_hide_immediately()

func _hide_immediately() -> void:
	var tween = create_tween()
	tween.tween_property(star, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(dish, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(dish_label, "modulate:a", 0.0, fade_time)
	tween.finished.connect(func():
		visible = false
		_is_showing = false
		set_process(false)
		if _visible_timer:
			_visible_timer.queue_free()
			_visible_timer = null
	)

func _process(delta: float) -> void:
	if _is_showing:
		star.rotation += 1.5 * delta
