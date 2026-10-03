class_name GlassPopup
extends Control

## ==============================================================================
## LUMI GLASS POPUP COMPONENT (Section 30, 31, 33, 50, 52)
## Modal backdrop overlay with spring animated glass card presentation
## ==============================================================================

signal popup_opened()
signal popup_closed()

@onready var backdrop: ColorRect = $Backdrop if has_node("Backdrop") else null
@onready var card_container: Control = $CardContainer if has_node("CardContainer") else null

var _tween: Tween

func _ready() -> void:
	visible = false
	if card_container:
		card_container.pivot_offset = card_container.size / 2.0

func open_popup() -> void:
	visible = true
	if _tween: _tween.kill()
	
	if backdrop:
		backdrop.modulate.a = 0.0
	if card_container:
		card_container.scale = Vector2(0.85, 0.85)
		card_container.modulate.a = 0.0
		
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if backdrop:
		_tween.tween_property(backdrop, "modulate:a", 1.0, GlassDesignSystem.TIME_PANEL_OPEN)
	if card_container:
		_tween.tween_property(card_container, "scale", Vector2.ONE, GlassDesignSystem.TIME_PANEL_OPEN)
		_tween.tween_property(card_container, "modulate:a", 1.0, GlassDesignSystem.TIME_PANEL_OPEN * 0.75)
		
	popup_opened.emit()

func close_popup() -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if backdrop:
		_tween.tween_property(backdrop, "modulate:a", 0.0, 0.15)
	if card_container:
		_tween.tween_property(card_container, "scale", Vector2(0.9, 0.9), 0.15)
		_tween.tween_property(card_container, "modulate:a", 0.0, 0.15)
		
	_tween.finished.connect(func():
		visible = false
		popup_closed.emit()
	, CONNECT_ONE_SHOT)
