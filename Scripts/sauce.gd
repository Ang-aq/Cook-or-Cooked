extends Node2D
class_name Sauce

@export var sauce_type: String = "hot"        # "hot","soy","sweet","mystery"
@export var combo: Array = []                # optional combo array (e.g. ["→","Z"])
@export var fall_speed: float = 60.0
@export var lifetime: float = 12.0           # despawn after seconds
@export var spawn_min_x: float = -445.0
@export var spawn_max_x: float = 445.0

signal sauce_collected(sauce_type: String)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var combo_display: Node = $ComboDisplay

var _spawn_time: float = 0.0
var _collected: bool = false
# default combos per type if user doesn't set them in the scene
const DEFAULT_COMBOS := {
	"hot": ["↑","↑","↓","↓","Z"],
	"soy": ["→","↓","→","↓","Z"],
	"sweet": ["↑","→","↓","←","Z"],
	"mystery": ["↓","→","→","↓","Z"]
}

func _ready() -> void:
	_spawn_time = Time.get_ticks_msec() / 1000.0
	# If combo not set, assign default combo for type
	if combo == null or combo.size() == 0:
		if DEFAULT_COMBOS.has(sauce_type):
			combo = DEFAULT_COMBOS[sauce_type].duplicate(true)
	
	# choose animation
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(sauce_type):
			sprite.play(sauce_type)
		elif sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
			
	_update_combo_display()

func _process(delta: float) -> void:
	position.y += fall_speed * delta
	
	var screen_h = get_viewport_rect().size.y
	if position.y > screen_h + 64:
		queue_free()
	if Time.get_ticks_msec() / 1000.0 - _spawn_time > lifetime:
		queue_free()
		
func check_sequence(sequence: Array) -> bool:
	if _collected:
		return false
	if combo == null or combo.size() == 0:
		return false
	if sequence.size() != combo.size():
		return false
		
	for i in range(sequence.size()):
		if _normalize_step(sequence[i]) != _normalize_step(combo[i]):
			return false
			
	# matched -> collect
	_collected = true
	emit_signal("sauce_collected", sauce_type)
	queue_free()
	return true

# small normalization to match arrows, keys, names
func _normalize_step(s) -> String:
	var st := str(s).strip_edges()
	if st == "↑" or st.to_lower() == "up" or st.to_lower() == "ui_up":
		return "UP"
	if st == "↓" or st.to_lower() == "down" or st.to_lower() == "ui_down":
		return "DOWN"
	if st == "←" or st.to_lower() == "left" or st.to_lower() == "ui_left":
		return "LEFT"
	if st == "→" or st.to_lower() == "right" or st.to_lower() == "ui_right":
		return "RIGHT"
	if st == "Z" or st.to_lower() == "z" or st.to_lower() == "ui_accept":
		return "Z"
	return st.to_upper()

func _update_combo_display() -> void:
	if combo_display == null:
		return
	# clear
	for c in combo_display.get_children():
		c.queue_free()

	var arrow_textures := {
		"↑": preload("res://Sprites/arrow_up.png"),
		"↓": preload("res://Sprites/arrow_down.png"),
		"←": preload("res://Sprites/arrow_left.png"),
		"→": preload("res://Sprites/arrow_right.png"),
		"Z": preload("res://Sprites/Z.png")
	}
	var x := 0
	for step in combo:
		# show the same visual whether step is "Z" or arrow
		var key := str(step)
		if arrow_textures.has(key):
			var icon := TextureRect.new()
			icon.texture = arrow_textures[key]
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(28, 28)
			icon.position = Vector2(x, 0)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			combo_display.add_child(icon)
			x += 34
		else:
			# fallback label for unknown steps
			var lbl := Label.new()
			lbl.text = key
			lbl.position = Vector2(x, 0)
			combo_display.add_child(lbl)
			x += 30
