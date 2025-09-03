# res://Scenes/Shiba_Boss.gd
extends AnimatedSprite2D
class_name ShibaBoss

signal boss_defeated

# --- Editable properties ---
@export var combo_sets: Array = [
	["↓","↓","↓","Z"],
	["↑","→","↓","←","Z"],
	["→","→","↓","↓","←","←","↑","↑","Z"],
	["↓","↑","↓","↑","↓","↑","↓","↑","↓","↑","Z"]
]

# Size for each arrow (adjust as needed)
@export var arrow_size: Vector2 = Vector2(24, 24)

# vertical offset of the combo display relative to the boss
@export var combo_offset: Vector2 = Vector2(-60, -80)

# pool size (max number of arrows that will be shown) - auto-calculated in _ready
@export var pool_size: int = 12

# --- State ---
var current_combo_index: int = 0
var waiting_for_input: bool = true
var _defeated: bool = false

# Nodes
@onready var combo_display: Control = $ComboDisplay
@onready var combo_hbox: HBoxContainer = $ComboDisplay/CenterContainer/HBoxContainer

# Preload arrow textures
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

func _ready() -> void:
	play("Idle")
	# compute pool size from max combo length
	var max_len := 0
	for cs in combo_sets:
		if cs.size() > max_len:
			max_len = cs.size()
	if max_len > pool_size:
		pool_size = max_len

	# Pre-create icon pool
	for i in range(pool_size):
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.custom_minimum_size = arrow_size
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		combo_hbox.add_child(icon)

	_update_combo_display()

func _process(delta: float) -> void:
	if combo_display:
		combo_display.position = combo_offset

# --- Display combo arrows ---
func _update_combo_display() -> void:
	if current_combo_index < 0 or current_combo_index >= combo_sets.size():
		return

	var combo: Array = combo_sets[current_combo_index]
	var combo_len: int = combo.size()
	var pool_count: int = combo_hbox.get_child_count()

	# Ensure enough icons
	if pool_count < combo_len:
		for i in range(pool_count, combo_len):
			var icon := TextureRect.new()
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			icon.custom_minimum_size = arrow_size
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.visible = false
			combo_hbox.add_child(icon)

	# Update visible icons
	for i in range(combo_len):
		var icon := combo_hbox.get_child(i) as TextureRect
		var step: String = str(combo[i])
		var tex: Texture2D = arrow_textures.get(step, null) as Texture2D
		if icon.texture != tex:
			icon.texture = tex
		icon.visible = true

	# Hide extras
	for i in range(combo_len, combo_hbox.get_child_count()):
		var icon := combo_hbox.get_child(i) as TextureRect
		icon.visible = false

# --- Input checking ---
func check_sequence(sequence: Array) -> bool:
	if not waiting_for_input:
		return false

	var expected: Array = combo_sets[current_combo_index]
	if sequence.size() != expected.size():
		return false

	for i in range(sequence.size()):
		if str(sequence[i]) != str(expected[i]):
			return false

	_on_combo_success()
	return true

func _on_combo_success() -> void:
	play("Hurt")
	current_combo_index += 1

	if current_combo_index >= combo_sets.size():
		_defeat()
	else:
		waiting_for_input = false
		await get_tree().create_timer(0.9).timeout
		waiting_for_input = true
		play("Idle")
		_update_combo_display()

func _defeat() -> void:
	_defeated = true
	play("Defeated")
	emit_signal("boss_defeated")
	await animation_finished
	queue_free()

func react_wrong_input() -> void:
	if _defeated:
		return
	play("Attack")
	await animation_finished
	play("Idle")
	get_tree().call_group("Game", "_on_pest_failed", "Wrong combo on boss!")
