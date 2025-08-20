extends ProgressBar  # if attached directly to ProgressBar

@export var speed := 1  # units per second

func _process(delta):
	value += speed * delta
	if value > max_value:
		value = max_value  # stop at full
