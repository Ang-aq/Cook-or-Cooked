extends Control

@onready var star = $Star
@onready var dish = $Dish
@onready var dish_title_label = $Label

func show_dish(dish_texture: Texture2D, dish_name: String) -> void:
	visible = true
	set_process(true)

	# Assign dish image and title
	dish.texture = dish_texture
	dish_title_label.text = dish_name
	dish_title_label.modulate.a = 0.0

	# Fade in title
	var tween = get_tree().create_tween()
	tween.tween_property(dish_title_label, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	# Spin the star slowly while visible
	if visible:
		star.rotation += 1.5 * delta
	else:
		set_process(false)
