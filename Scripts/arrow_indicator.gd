extends Node2D
class_name ArrowIndicator

@onready var sprite = $ArrowIndicator

func point_to(target: Node2D):
	visible = true
	global_position = target.global_position + Vector2(0, 0)
	look_at(target.global_position)

func hideArrow():
	visible = false
