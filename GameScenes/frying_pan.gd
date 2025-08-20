extends Area2D

var is_using_pan = false
var current_weapon = "frying_pan"
var overlapping_pests = []


func _process(delta):
	position = get_global_mouse_position()

	if Input.is_action_pressed("use_frying_pan"):
		if current_weapon == "frying_pan":
			is_using_pan = true
			print("Swing frying pan!")
			# Check overlapping pests right when Z is pressed
			for pest in overlapping_pests:
				if pest and pest.is_in_group("pests"):
					pest.call_deferred("queue_free")  # <-- FIXED
					print("Mouse hit!")
	else:
		is_using_pan = false

	if Input.is_action_just_pressed("switch_weapon"):
		current_weapon = "spatula" if current_weapon == "frying_pan" else "frying_pan"
		print("Switched to: ", current_weapon)


func _on_FryingPan_body_exited(body):
	if body in overlapping_pests:
		overlapping_pests.erase(body)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("pests"):
		overlapping_pests.append(body)
		print("Mouse present")
