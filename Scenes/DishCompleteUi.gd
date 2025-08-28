extends Control

signal continue_pressed

@onready var star = $Star
@onready var dish = $Dish
@onready var dish_title_label = $Label
@onready var instructions = $Instructions

func show_dish(dish_texture: Texture2D, dish_name: String, dish_scale: float = 1.0):
	# Reset visibility
	visible = true	
	set_process(true)

	# Apply dish properties
	dish.texture = dish_texture
	dish.scale = Vector2(dish_scale, dish_scale)

	# Title fade-in
	dish_title_label.text = dish_name
	dish_title_label.modulate.a = 0.0
	instructions.modulate.a = 0.0
	
	var tween = get_tree().create_tween()
	tween.tween_property(dish_title_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(instructions, "modulate:a", 1.0, 0.5)


func _process(delta):
	star.rotation += 1.5 * delta

func _unhandled_input(event):
	if visible and event.is_pressed():
		visible = false
		set_process(false)
		emit_signal("continue_pressed")
