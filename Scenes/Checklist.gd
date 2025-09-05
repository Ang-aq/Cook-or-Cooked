extends Control

var ingredient_labels: Dictionary = {}
var ingredient_required: Dictionary = {}

# Initialize the checklist
func setup_checklist(ingredients: Dictionary) -> void:
	print("Checklist setup called with:", ingredients)
	
	# Clear old labels
	for child in $VBoxContainer.get_children():
		child.queue_free()
	ingredient_labels.clear()
	ingredient_required.clear()

	# Create new labels
	for name in ingredients.keys():
		var raw_value = ingredients[name]

		# Handle both formats: { "amount": X } or just X
		var count: int
		if typeof(raw_value) == TYPE_DICTIONARY and raw_value.has("amount"):
			count = raw_value["amount"]
		elif typeof(raw_value) == TYPE_INT:
			count = raw_value
		else:
			push_warning("Unexpected ingredient format for %s: %s" % [name, str(raw_value)])
			continue

		ingredient_required[name] = count

		var label = Label.new()
		label.text = "%s: 0 / %d" % [name, count]
		label.modulate = Color.BLACK
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size = Vector2(0, 32)

		# Make text larger
		label.add_theme_font_size_override("font_size", 22)

		$VBoxContainer.add_child(label)
		ingredient_labels[name] = label

# Update progress
func update_progress(name: String, current: int) -> void:
	if not ingredient_labels.has(name):
		return

	var label: Label = ingredient_labels[name]
	var required_count: int = ingredient_required[name]
	label.text = "%s: %d / %d" % [name, current, required_count]

	# Strike-through once completed
	if current >= required_count and label.get_meta("striked") != true:
		# Create line
		var line = ColorRect.new()
		line.color = Color(1, 0, 0)
		line.custom_minimum_size = Vector2(0, 2)  # start at 0 width
		line.size_flags_horizontal = Control.SIZE_FILL
		line.anchor_left = 0
		line.anchor_right = 0   # keep right edge fixed while animating
		line.anchor_top = 0.3
		line.anchor_bottom = 0.4
		line.pivot_offset = Vector2(0, 1)  # pivot left

		label.add_child(line)

		# Animate line width
		await get_tree().process_frame  # let layout update so we know the label size
		var target_width = label.size.x

		var tween := create_tween()
		tween.tween_property(
			line, "custom_minimum_size:x", target_width, 0.4
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		MusicManager.play_sfx("crossout")
		
		label.set_meta("striked", true)
