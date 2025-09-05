extends Node2D

@onready var label: Label = $Label

@export var rise: float = 50.0
@export var duration: float = 2
@export var start_scale: float = 2.0
@export var end_scale: float = 2.0
@export var z_top: int = 9999

func show_text(t: String) -> void:
	label.text = t
	z_index = z_top
	scale = Vector2.ONE * start_scale
	modulate.a = 1.0
	

	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	# rise
	tween.tween_property(self, "position:y", position.y - rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# fade
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	# optional scale
	if end_scale != start_scale:
		tween.tween_property(self, "scale", Vector2.ONE * end_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(queue_free)
