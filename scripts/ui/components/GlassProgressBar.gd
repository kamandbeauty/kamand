class_name GlassProgressBar
extends ProgressBar

## ==============================================================================
## LUMI GLASS PROGRESS BAR COMPONENT (Section 28, 29, 50)
## Crystal groove with glowing gradient fill and smooth animated transitions
## ==============================================================================

@export var fill_tint: Color = GlassDesignSystem.COLOR_AQUA:
	set(v):
		fill_tint = v
		_update_styles()

var _target_val: float = 0.0
var _anim_tween: Tween

func _ready() -> void:
	_update_styles()
	show_percentage = false

func _update_styles() -> void:
	add_theme_stylebox_override("background", GlassDesignSystem.create_glass_progress_bg_style())
	add_theme_stylebox_override("fill", GlassDesignSystem.create_glass_progress_fill_style(fill_tint))

func set_smooth_value(new_value: float, duration: float = 0.25) -> void:
	_target_val = clampf(new_value, min_value, max_value)
	if _anim_tween: _anim_tween.kill()
	_anim_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(self, "value", _target_val, duration)
