class_name ScorePopup
extends Node2D

func setup(pos: Vector2, text: String, color: Color = Color(1.0, 0.9, 0.3), font_size: int = 24) -> void:
	position = pos
	
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", font_size)
	
	# Center label on origin
	label.position = Vector2(-80.0, -20.0)
	label.custom_minimum_size = Vector2(160.0, 40.0)
	add_child(label)
	
	scale = Vector2(0.5, 0.5)
	
	var tween: Tween = create_tween()
	# Scale bounce
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Drift upward
	tween.parallel().tween_property(self, "position:y", pos.y - 50.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.2)
	tween.tween_callback(queue_free)
