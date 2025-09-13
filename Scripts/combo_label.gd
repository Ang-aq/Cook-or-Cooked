extends Label

func update_combo(combo_count: int):
	text = str(combo_count) + "x Combo!"
	
	# Animate: pop scale
	var tween = get_tree().create_tween()
	scale = Vector2.ONE
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Animate: color flash
	modulate = Color(1,1,0) # yellow
	var tween2 = get_tree().create_tween()
	tween2.tween_property(self, "modulate", Color(1,1,1), 0.3)
