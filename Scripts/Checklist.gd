extends Control

@export var use_jp_font: bool = true
@onready var en_font: Font = preload("res://Fonts/CutePixel.ttf")
@onready var jp_font: Font = preload("res://Fonts/BestTen-CRT.otf")

var ingredient_labels: Dictionary = {}
var ingredient_required: Dictionary = {}

func setup_checklist(ingredients: Dictionary) -> void:
	print("Checklist setup called with:", ingredients)
	
	for child in $VBoxContainer.get_children():
		child.queue_free()
	ingredient_labels.clear()
	ingredient_required.clear()
	var font_to_use: Font = LocalizationManager.get_font()

	for name in ingredients.keys():
		var raw_value = ingredients[name]
		
		var count: int
		if typeof(raw_value) == TYPE_DICTIONARY and raw_value.has("amount"):
			count = raw_value["amount"]
		elif typeof(raw_value) == TYPE_INT:
			count = raw_value
		else:
			push_error("Unexpected ingredient format for %s: %s" % [name, str(raw_value)])
			continue
		ingredient_required[name] = count

		var translated_name := LocalizationManager.t(name)
		
		var label = Label.new()
		label.text = "%s: 0 / %d" % [translated_name, count]
		label.modulate = Color.BLACK
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(0, 32)
		label.add_theme_font_override("font", font_to_use)
		label.add_theme_font_size_override("font_size", 22)

		label.set_meta("ingredient_name", name)
		
		$VBoxContainer.add_child(label)
		ingredient_labels[name] = label
		
func update_progress(name: String, current: int) -> void:
	if not ingredient_labels.has(name):
		return
	
	var label: Label = ingredient_labels[name]
	if not is_instance_valid(label):
		return

	var required_count: int = ingredient_required[name]
	label.text = "%s: %d / %d" % [LocalizationManager.t(name), current, required_count]

	if current >= required_count and (is_instance_valid(label) and label.get_meta("striked") != true):
		var line = ColorRect.new()
		line.color = Color(1, 0, 0)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_FILL
		line.anchor_left = 0
		line.anchor_right = 0
		line.anchor_top = 0.3
		line.anchor_bottom = 0.4
		line.pivot_offset = Vector2(0, 1)

		if not is_instance_valid(label):
			return
		label.add_child(line)

		await get_tree().process_frame

		if not is_instance_valid(label):
			return

		var target_width = label.get_size().x
		var tween := create_tween()
		tween.tween_property(
			line, "custom_minimum_size:x", target_width, 0.4
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		MusicManager.play_sfx("crossout")
			
		if is_instance_valid(label):
			label.set_meta("striked", true)

func refresh_translations() -> void:
	for name in ingredient_labels.keys():
		var label: Label = ingredient_labels[name]
		if not is_instance_valid(label):
			continue
		var translated_name := LocalizationManager.t(name)
		var required_count: int = int(ingredient_required[name])
		
		var text_parts = label.text.split(":")
		if text_parts.size() > 1:
			var progress_str = text_parts[1].strip_edges()
			label.text = "%s: %s" % [translated_name, progress_str]
		else:
			label.text = "%s: 0 / %d" % [translated_name, required_count]
