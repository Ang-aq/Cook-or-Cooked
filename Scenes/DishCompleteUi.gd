extends Control

signal continue_pressed

@onready var star = $Star
@onready var dish = $Dish
@onready var dish_title_label = $Label

var input_enabled: bool = false  # <- Prevent early input

func show_dish(dish_texture: Texture2D, dish_name: String) -> void:
	visible = true
	set_process(true)
	input_enabled = false  # disable input initially
	
	# Assign dish image
	dish.texture = dish_texture
	dish_title_label.text = dish_name
	dish_title_label.modulate.a = 0.0

	# Fade in title
	var tween = get_tree().create_tween()
	tween.tween_property(dish_title_label, "modulate:a", 1.0, 0.5)

	# Enable input after 1 second
	await get_tree().create_timer(1.0).timeout
	input_enabled = true

func _process(delta):
	# Spin the star slowly
	star.rotation += 1.5 * delta

func _unhandled_input(event):
	if visible and input_enabled and event.is_pressed():
		visible = false
		set_process(false)
		emit_signal("continue_pressed")
