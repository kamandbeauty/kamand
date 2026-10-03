class_name ScreenFeedback
extends Node2D

var trauma: float = 0.0
var max_offset: Vector2 = Vector2(16.0, 16.0)
var max_roll: float = 0.05
var trauma_decay: float = 2.5

@onready var target_node: Node2D = get_parent() as Node2D

func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		if not SaveManager.reduced_effects:
			_apply_shake()
		else:
			if target_node:
				target_node.position = Vector2.ZERO
				target_node.rotation = 0.0
	else:
		if target_node and (target_node.position != Vector2.ZERO or target_node.rotation != 0.0):
			target_node.position = Vector2.ZERO
			target_node.rotation = 0.0

func add_trauma(amount: float) -> void:
	if SaveManager.reduced_effects:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _apply_shake() -> void:
	if not target_node:
		return
	var shake_intensity: float = trauma * trauma
	var offset_x: float = max_offset.x * shake_intensity * randf_range(-1.0, 1.0)
	var offset_y: float = max_offset.y * shake_intensity * randf_range(-1.0, 1.0)
	var roll: float = max_roll * shake_intensity * randf_range(-1.0, 1.0)
	
	target_node.position = Vector2(offset_x, offset_y)
	target_node.rotation = roll

## Spawns floating score popup
func spawn_score_popup(pos: Vector2, text: String, color: Color = Color(1.0, 0.9, 0.3), font_size: int = 24) -> void:
	var popup: ScorePopup = ScorePopup.new()
	add_child(popup)
	popup.setup(pos, text, color, font_size)
