extends Control

var ingredient_labels: Dictionary = {}
var ingredient_required: Dictionary = {}

# Call this to initialize the checklist
func setup_checklist(ingredients: Dictionary) -> void:
	print("Checklist setup called with:", ingredients)

	# Clear old labels
	for child in $VBoxContainer.get_children():
		child.queue_free()
	ingredient_labels.clear()
	ingredient_required.clear()

	# Create new labels
	for name in ingredients.keys():
		var count: int = ingredients[name]
		ingredient_required[name] = count

		var label = Label.new()
		label.text = "%s: 0 / %d" % [name, count]
		label.modulate = Color.BLACK
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$VBoxContainer.add_child(label)

		ingredient_labels[name] = label

# Call this to update the progress
func update_progress(name: String, current: int) -> void:
	if not ingredient_labels.has(name):
		return

	var label: Label = ingredient_labels[name]
	var required: int = ingredient_required[name]
	label.text = "%s: %d / %d" % [name, current, required]

	# Draw strike-through once completed
	if current >= required and label.get_child_count() == 0:
		var line = Line2D.new()
		line.width = 2
		line.default_color = Color.RED

		# Use a fixed height for the line (half the label height)
		var label_height = 20  # adjust if needed
		var width = label.get_minimum_size().x
		line.points = [
			Vector2(0, label_height / 2),
			Vector2(width, label_height / 2)
		]

		label.add_child(line)
