class_name GlassButton
extends Button

## ==============================================================================
## LUMI GLASS BUTTON COMPONENT (Section 8, 9, 10, 50)
## Tactile glass pill with upper-left light sheen, inner highlight, responsive micro-animations
## ==============================================================================

@export var is_primary: bool = false:
	set(v):
		is_primary = v
		_update_styles()

@export var corner_radius: int = 24:
	set(v):
		corner_radius = v
		_update_styles()

var _tween: Tween

func _ready() -> void:
	_update_styles()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)

func _update_styles() -> void:
	add_theme_stylebox_override("normal", GlassDesignSystem.create_glass_button_style("normal", is_primary, corner_radius))
	add_theme_stylebox_override("hover", GlassDesignSystem.create_glass_button_style("hover", is_primary, corner_radius))
	add_theme_stylebox_override("pressed", GlassDesignSystem.create_glass_button_style("pressed", is_primary, corner_radius))
	add_theme_stylebox_override("disabled", GlassDesignSystem.create_glass_button_style("disabled", is_primary, corner_radius))
	add_theme_stylebox_override("focus", GlassDesignSystem.create_glass_button_style("hover", is_primary, corner_radius))

func _on_mouse_entered() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.04, 1.04), GlassDesignSystem.TIME_BUTTON_TWEEN)

func _on_mouse_exited() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, GlassDesignSystem.TIME_BUTTON_TWEEN)

func _on_button_down() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.08)

func _on_button_up() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.08)
