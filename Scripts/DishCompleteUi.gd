extends Control

@onready var star = $Star
@onready var dish = $Dish
@onready var dish_title_label = $DishTitle
@onready var level_label = $LevelUp

func show_dish(dish_texture: Texture2D, dish_name_key: String) -> void:
	visible = true
	set_process(true)

	dish.texture = dish_texture

	dish_title_label.text = LocalizationManager.t(dish_name_key)
	level_label.text = LocalizationManager.t("Level Up!")
	
	dish_title_label.add_theme_font_override("font", LocalizationManager.get_font())
	level_label.add_theme_font_override("font", LocalizationManager.get_font())
	
	dish_title_label.modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(dish_title_label, "modulate:a", 1.0, 0.5)

func _process(delta: float) -> void:
	if visible:
		star.rotation += 1.5 * delta
	else:
		set_process(false)
