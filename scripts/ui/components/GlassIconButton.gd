class_name GlassIconButton
extends Button

## ==============================================================================
## LUMI GLASS ICON BUTTON COMPONENT (Section 11, 45, 50)
## Circular crystal glass button with glowing hover state and tactile spring response
## ==============================================================================

@export var circle_radius: int = 24:
	set(v):
		circle_radius = v
		_update_styles()

var _tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(circle_radius * 2, circle_radius * 2)
	_update_styles()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pivot_offset = custom_minimum_size / 2.0

func _update_styles() -> void:
	add_theme_stylebox_override("normal", GlassDesignSystem.create_glass_button_style("normal", false, circle_radius))
	add_theme_stylebox_override("hover", GlassDesignSystem.create_glass_button_style("hover", false, circle_radius))
	add_theme_stylebox_override("pressed", GlassDesignSystem.create_glass_button_style("pressed", false, circle_radius))
	add_theme_stylebox_override("disabled", GlassDesignSystem.create_glass_button_style("disabled", false, circle_radius))
	add_theme_stylebox_override("focus", GlassDesignSystem.create_glass_button_style("hover", false, circle_radius))

func _on_mouse_entered() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.08, 1.08), GlassDesignSystem.TIME_BUTTON_TWEEN)

func _on_mouse_exited() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, GlassDesignSystem.TIME_BUTTON_TWEEN)

func _on_button_down() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.08)

func _on_button_up() -> void:
	if disabled: return
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.08)
