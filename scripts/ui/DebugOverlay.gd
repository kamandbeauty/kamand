class_name DebugOverlay
extends CanvasLayer

signal debug_restart_level()
signal debug_next_level()
signal debug_win_game()
signal debug_lose_game()
signal debug_toggle_grid_coords()

@onready var container: PanelContainer = $Container
@onready var stats_label: Label = $Container/VBox/StatsLabel
@onready var debug_toggle_btn: Button = $ToggleBtn

var is_debug_visible: bool = false:
	set(value):
		is_debug_visible = value
		if container:
			container.visible = is_debug_visible

var debug_state_text: String = "PLAYING"
var debug_bubble_count: int = 0
var debug_aim_angle: float = 0.0
var debug_last_snap: Vector2i = Vector2i(-1, -1)
var debug_shots: int = 0
var debug_combo: int = 0
var debug_level_id: int = 1

func _ready() -> void:
	if container:
		container.visible = is_debug_visible
	if debug_toggle_btn:
		debug_toggle_btn.pressed.connect(func(): is_debug_visible = not is_debug_visible)

func _process(_delta: float) -> void:
	if is_debug_visible and stats_label:
		var fps: float = Engine.get_frames_per_second()
		var text: String = "=== DEBUG MODE ===\n"
		text += "FPS: %.1f\n" % fps
		text += "State: %s\n" % debug_state_text
		text += "Level: %d\n" % debug_level_id
		text += "Bubbles on Board: %d\n" % debug_bubble_count
		text += "Aim Angle: %.1f°\n" % rad_to_deg(debug_aim_angle)
		text += "Last Snap: (%d, %d)\n" % [debug_last_snap.x, debug_last_snap.y]
		text += "Shots Remaining: %d\n" % debug_shots
		text += "Current Combo: %d\n" % debug_combo
		text += "Keys: [R] Restart | [N] Next | [W] Win | [L] Lose | [D] Debug"
		stats_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		is_debug_visible = not is_debug_visible
	elif event.is_action_pressed("restart"):
		debug_restart_level.emit()
	elif event.is_action_pressed("next_level"):
		debug_next_level.emit()
	elif event.is_action_pressed("debug_win"):
		debug_win_game.emit()
	elif event.is_action_pressed("debug_lose"):
		debug_lose_game.emit()
