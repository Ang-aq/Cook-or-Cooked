extends Label

var visible_characters: int = 0

func scroll_text(input_text:String, speed: float = 0.05) -> void:
	visible_characters = 0
	text = ""
	
	for i in range(input_text.length()):
		visible_characters += 1
		text = input_text.substr(0, visible_characters)
		await get_tree().create_timer(speed).timeout
