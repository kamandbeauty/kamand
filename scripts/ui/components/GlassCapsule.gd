class_name GlassCapsule
extends PanelContainer

## ==============================================================================
## LUMI GLASS CAPSULE COMPONENT (Section 25, 28, 50)
## Compact pill badge for combo counters, objective indicators, and star counters
## ==============================================================================

@export var capsule_tint: Color = GlassDesignSystem.COLOR_AQUA:
	set(v):
		capsule_tint = v
		_update_style()

func _ready() -> void:
	_update_style()

func _update_style() -> void:
	add_theme_stylebox_override("panel", GlassDesignSystem.create_glass_capsule_style(capsule_tint))
