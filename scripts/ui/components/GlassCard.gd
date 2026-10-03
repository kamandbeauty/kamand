class_name GlassCard
extends PanelContainer

## ==============================================================================
## LUMI GLASS CARD COMPONENT (Section 7, 50)
## Multi-depth crystal glass card with soft rounded borders and subtle sheen
## ==============================================================================

@export var corner_radius: int = 20:
	set(v):
		corner_radius = v
		_update_style()

func _ready() -> void:
	_update_style()

func _update_style() -> void:
	add_theme_stylebox_override("panel", GlassDesignSystem.create_glass_card_style(corner_radius))
