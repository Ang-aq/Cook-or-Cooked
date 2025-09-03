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

# Size for each arrow (adjust to taste)
@export var arrow_size: Vector2 = Vector2(4, 4)

# vertical offset of the combo display relative to the boss
@export var combo_offset: Vector2 = Vector2(-60, -90)

# pool size (max number of arrows that will be shown) - auto-calculated in _ready
@export var pool_size: int = 12

# --- State ---
var current_combo_index: int = 0
var waiting_for_input: bool = true
var _defeated: bool = false

# Nodes
@onready var combo_display: Control = $ComboDisplay
@onready var combo_hbox: HBoxContainer = $ComboDisplay/HBoxContainer

# Preload arrow textures (same approach as Mosquito)
var arrow_textures := {
	"↑": preload("res://Sprites/arrow_up.png"),
	"↓": preload("res://Sprites/arrow_down.png"),
	"←": preload("res://Sprites/arrow_left.png"),
	"→": preload("res://Sprites/arrow_right.png"),
	"Z": preload("res://Sprites/Z.png")
}

func _ready() -> void:
	# ensure we start in idle animation
	play("Idle")

	# compute a safe pool size from combo_sets (max combo length)
	var max_len := 0
	for cs in combo_sets:
		if cs.size() > max_len:
			max_len = cs.size()
	if max_len > pool_size:
		pool_size = max_len

	# Pre-create icon pool (so we don't create/free nodes during runtime)
	for i in range(pool_size):
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = arrow_size
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		combo_hbox.add_child(icon)

	# initial display
	_update_combo_display()

func _process(delta: float) -> void:
	# keep the combo display positioned above the boss (local offset)
	if combo_display:
		combo_display.position = combo_offset

# --- Display combo arrows (efficient reuse / pool) ---
func _update_combo_display() -> void:
	# safety checks
	if combo_hbox == null:
		return
	if current_combo_index < 0 or current_combo_index >= combo_sets.size():
		return

	var combo: Array = combo_sets[current_combo_index]
	var combo_len: int = int(combo.size())
	var pool_count: int = int(combo_hbox.get_child_count())

	# ensure pool has enough icons
	if pool_count < combo_len:
		for i in range(pool_count, combo_len):
			var icon: TextureRect = TextureRect.new()
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = arrow_size
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.visible = false
			combo_hbox.add_child(icon)

	# update only what's needed (typed variables, explicit casts)
	for i in range(combo_len):
		var node: Node = combo_hbox.get_child(i)
		var icon: TextureRect = node as TextureRect
		var step: String = str(combo[i])
		var tex: Texture2D = arrow_textures.get(step, null) as Texture2D
		if icon.texture != tex:
			icon.texture = tex
		icon.visible = true

	# hide remaining pool icons
	var total_children: int = int(combo_hbox.get_child_count())
	for i in range(combo_len, total_children):
		var node2: Node = combo_hbox.get_child(i)
		var icon2: TextureRect = node2 as TextureRect
		if icon2.visible:
			icon2.visible = false

# --- Input checking (called by Main) ---
# Returns true if boss consumed the sequence (i.e. matched)
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
	# brief hurt/feedback animation, then advance
	play("Hurt")
	current_combo_index += 1

	if current_combo_index >= combo_sets.size():
		_defeat()
	else:
		# refresh the displayed arrows for next combo after a short pause
		waiting_for_input = false
		await get_tree().create_timer(0.9).timeout
		waiting_for_input = true
		play("Idle")
		_update_combo_display()

func _defeat() -> void:
	_defeated = true
	play("Defeated")
	emit_signal("boss_defeated")
	# wait for animation to finish before freeing (awaiting the animation_finished signal)
	await animation_finished
	queue_free()

# Called by Main when player enters a wrong combo during the boss fight
func react_wrong_input() -> void:
	if _defeated:
		return
	# boss attack anim + punish player
	play("Attack")
	await animation_finished
	play("Idle")
	# notify Game to handle heart loss (Main listens to _on_pest_failed)
	get_tree().call_group("Game", "_on_pest_failed", "Wrong combo on boss!")
