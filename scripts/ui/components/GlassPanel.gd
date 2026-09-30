class_name GlassPanel
extends PanelContainer

## ==============================================================================
## LUMI GLASS PANEL COMPONENT (Section 6, 50)
## Semi-transparent crystal glass with edge highlight and soft shadow
## ==============================================================================

@export var corner_radius: int = 24:
	set(v):
		corner_radius = v
		_update_style()

@export_range(0.1, 0.9) var glass_opacity: float = 0.35:
	set(v):
		glass_opacity = v
		_update_style()

@export var border_highlight: Color = Color(1.0, 1.0, 1.0, 0.45):
	set(v):
		border_highlight = v
		_update_style()

@export var panel_tint: Color = Color(0.10, 0.14, 0.32):
	set(v):
		panel_tint = v
		_update_style()

func _ready() -> void:
	_update_style()

func _update_style() -> void:
	var style: StyleBoxFlat = GlassDesignSystem.create_glass_panel_style(
		corner_radius,
		glass_opacity,
		panel_tint,
		border_highlight,
		2
	)
	add_theme_stylebox_override("panel", style)
