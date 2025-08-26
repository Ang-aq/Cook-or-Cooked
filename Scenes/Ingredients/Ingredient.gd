extends Node2D
class_name Ingredient

@export var speed := 150.0
var combo := []
var ingredient_name := ""

@onready var sprite := $AnimatedSprite2D
@onready var input_display := $InputDisplay   # HBoxContainer holding arrow images

# Mapping string symbols to images
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

# Define scales per ingredient
var ingredient_scales := {
	"Potato": Vector2(2, 2),
	"Onion": Vector2(2, 2),
	"Carrot": Vector2(1, 1),
	"Meat": Vector2(2, 2)
}

func set_combo_and_name(new_combo: Array, new_name: String) -> void:
	combo = new_combo.duplicate()
	ingredient_name = new_name

	# Clear previous arrows
	for child in input_display.get_children():
		child.queue_free()

	# Add arrows as TextureRects
	for step in combo:
		if arrow_textures.has(step):
			var tex := TextureRect.new()
			tex.texture = arrow_textures[step]
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.size_flags_horizontal = Control.SIZE_FILL
			tex.size_flags_vertical = Control.SIZE_FILL
			input_display.add_child(tex)

	# Play sprite animation
	if sprite.sprite_frames.has_animation(ingredient_name):
		sprite.play(ingredient_name)
	else:
		push_warning("No animation for ingredient: %s" % ingredient_name)

	# Scale sprite individually
	if ingredient_scales.has(ingredient_name):
		sprite.scale = ingredient_scales[ingredient_name]
	else:
		sprite.scale = Vector2(3, 3)  # default scale

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > get_viewport_rect().size.y:
		queue_free()
