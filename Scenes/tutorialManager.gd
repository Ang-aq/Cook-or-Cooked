extends Node2D

@onready var tutorial_dialog = $TutorialDialog
@onready var spawner = $IngredientSpawner
@onready var hud = $HUD

func _ready() -> void:
	# Start the tutorial
	start_tutorial()

func start_tutorial() -> void:
	var intro_lines = [
		"Welcome to Cook or Cooked!",
		"In this tutorial, you will learn how to collect ingredients and make a dish."
	]
	tutorial_dialog.start_dialogue(intro_lines)
	tutorial_dialog.connect("dialogue_finished", Callable(self, "_on_intro_finished"))

func _on_intro_finished() -> void:
	# Spawn Meat ingredient and stop it in middle
	spawner.spawn_ingredient("Meat", true)

	# Show next dialogue line about input
	var input_lines = [
		"Press the correct key on top of the ingredient to collect it!"
	]
	tutorial_dialog.start_dialogue(input_lines)
	tutorial_dialog.connect("dialogue_finished", Callable(self, "_on_first_input_ready"))

func _on_first_input_ready() -> void:
	# Enable player input for Meat
	var meat = $Meat
	meat.set_process(true)
	# The player will input the key to collect
	# Once collected, call `_on_meat_collected` (you need to detect this in Meat.gd)

func _on_meat_collected() -> void:
	# Move UI to bottom and show HUD (lives, timer)
	hud.visible = true
	# Continue tutorial with SpringOnion spawn and dialogue
	spawner.spawn_ingredient("SpringOnion", true)
	var lines = [
		"Now try collecting the Spring Onion ingredient!"
	]
	tutorial_dialog.start_dialogue(lines)
	tutorial_dialog.connect("dialogue_finished", Callable(self, "_on_second_input_ready"))

func _on_second_input_ready() -> void:
	# Enable player input for Spring Onion
	var spring_onion = $SpringOnion
	spring_onion.set_process(true)
	# After this, when dish is complete, show normal dish ending
