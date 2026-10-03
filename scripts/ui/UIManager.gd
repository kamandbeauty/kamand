class_name UIManager
extends Control

signal restart_requested()
signal next_level_requested()
signal swap_requested()
signal pause_toggled(is_paused: bool)
signal level_selected(level_id: int)
signal return_to_map_requested()

@onready var header_panel: Panel = $HeaderPanel
@onready var level_label: Label = $HeaderPanel/HBox/LevelLabel
@onready var score_label: Label = $HeaderPanel/HBox/ScoreLabel
@onready var stars_label: Label = $HeaderPanel/HBox/StarsLabel
@onready var shots_label: Label = $HeaderPanel/HBox/ShotsLabel
@onready var combo_label: Label = $HeaderPanel/HBox/ComboLabel
@onready var pause_btn: Button = $HeaderPanel/HBox/PauseBtn

@onready var win_overlay: Panel = $WinOverlay
@onready var win_title: Label = $WinOverlay/VBox/WinTitle
@onready var win_stars_label: Label = $WinOverlay/VBox/StarsContainer/StarsLabel
@onready var win_score_label: Label = $WinOverlay/VBox/ScoreLabel
@onready var win_next_btn: Button = $WinOverlay/VBox/NextBtn
@onready var win_restart_btn: Button = $WinOverlay/VBox/RestartBtn
@onready var win_map_btn: Button = $WinOverlay/VBox/MapBtn if has_node("WinOverlay/VBox/MapBtn") else null

@onready var lose_overlay: Panel = $LoseOverlay
@onready var lose_title: Label = $LoseOverlay/VBox/LoseTitle
@onready var lose_reason_label: Label = $LoseOverlay/VBox/ReasonLabel
@onready var lose_restart_btn: Button = $LoseOverlay/VBox/RestartBtn
@onready var lose_map_btn: Button = $LoseOverlay/VBox/MapBtn if has_node("LoseOverlay/VBox/MapBtn") else null

@onready var pause_overlay: Panel = $PauseOverlay
@onready var resume_btn: Button = $PauseOverlay/VBox/ResumeBtn
@onready var pause_restart_btn: Button = $PauseOverlay/VBox/RestartBtn
@onready var pause_map_btn: Button = $PauseOverlay/VBox/MapBtn if has_node("PauseOverlay/VBox/MapBtn") else null
@onready var effects_toggle_btn: CheckButton = $PauseOverlay/VBox/EffectsToggle
@onready var accessibility_toggle_btn: CheckButton = $PauseOverlay/VBox/AccessibilityToggle
@onready var sound_toggle_btn: CheckButton = $PauseOverlay/VBox/SoundToggle

var is_paused: bool = false
var target_score: int = 300

func _ready() -> void:
	hide_overlays()
	_connect_ui_signals()

func _connect_ui_signals() -> void:
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
	if win_next_btn:
		win_next_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			next_level_requested.emit()
		)
	if win_restart_btn:
		win_restart_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			restart_requested.emit()
		)
	if win_map_btn:
		win_map_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			return_to_map_requested.emit()
		)
	if lose_restart_btn:
		lose_restart_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			restart_requested.emit()
		)
	if lose_map_btn:
		lose_map_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			return_to_map_requested.emit()
		)
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if pause_restart_btn:
		pause_restart_btn.pressed.connect(func():
			_on_resume_pressed()
			restart_requested.emit()
		)
	if pause_map_btn:
		pause_map_btn.pressed.connect(func():
			_on_resume_pressed()
			return_to_map_requested.emit()
		)
	if effects_toggle_btn:
		effects_toggle_btn.toggled.connect(func(toggled_on: bool):
			SaveManager.reduced_effects = toggled_on
			SaveManager.save_game()
		)
	if accessibility_toggle_btn:
		accessibility_toggle_btn.toggled.connect(func(toggled_on: bool):
			SaveManager.show_accessibility_symbols = toggled_on
			SaveManager.save_game()
		)
	if sound_toggle_btn:
		sound_toggle_btn.toggled.connect(func(toggled_on: bool):
			SaveManager.sound_enabled = toggled_on
			SaveManager.save_game()
		)

func update_level_info(level_name: String, level_id: int, tgt_score: int) -> void:
	target_score = tgt_score
	if level_label:
		level_label.text = "LVL %d: %s" % [level_id, level_name]
	update_stars_display(0)

func update_score(score: int, high_score: int) -> void:
	if score_label:
		score_label.text = "SCORE: %d" % score
		
	# Calculate current stars based on target score
	var stars: int = 1
	if score >= target_score:
		stars = 2
	if score >= int(float(target_score) * 1.5):
		stars = 3
	update_stars_display(stars)

func update_stars_display(stars: int) -> void:
	if stars_label:
		match stars:
			1: stars_label.text = "★ ☆ ☆"
			2: stars_label.text = "★ ★ ☆"
			3: stars_label.text = "★ ★ ★"
			_: stars_label.text = "☆ ☆ ☆"

func update_shots(shots_left: int) -> void:
	if shots_label:
		shots_label.text = "SHOTS: %d" % shots_left
		if shots_left <= 3:
			shots_label.modulate = Color(1.0, 0.3, 0.3)
		else:
			shots_label.modulate = Color(0.4, 0.95, 0.6)

func update_combo(combo: int) -> void:
	if combo_label:
		if combo > 1:
			combo_label.text = "COMBO x%d!" % combo
			combo_label.visible = true
			if not SaveManager.reduced_effects:
				var tween: Tween = create_tween()
				combo_label.scale = Vector2(1.3, 1.3)
				tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
		else:
			combo_label.visible = false

func show_win(score: int, high_score: int, is_new_high: bool, stars: int) -> void:
	hide_overlays()
	win_overlay.visible = true
	var high_text: String = "\n(NEW HIGH SCORE!)" if is_new_high else "\nBest: %d" % high_score
	win_score_label.text = "Final Score: %d%s" % [score, high_text]
	
	if win_stars_label:
		match stars:
			1: win_stars_label.text = "★ ☆ ☆"
			2: win_stars_label.text = "★ ★ ☆"
			3: win_stars_label.text = "★ ★ ★"
			_: win_stars_label.text = "★ ★ ★"
			
	if not SaveManager.reduced_effects:
		win_overlay.scale = Vector2(0.8, 0.8)
		var tween: Tween = create_tween()
		tween.tween_property(win_overlay, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func show_lose(reason: String, score: int) -> void:
	hide_overlays()
	lose_overlay.visible = true
	lose_reason_label.text = "%s\nScore: %d" % [reason, score]
	
	if not SaveManager.reduced_effects:
		lose_overlay.scale = Vector2(0.8, 0.8)
		var tween: Tween = create_tween()
		tween.tween_property(lose_overlay, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_pause_pressed() -> void:
	AudioManager.play_ui_click()
	is_paused = true
	if effects_toggle_btn:
		effects_toggle_btn.button_pressed = SaveManager.reduced_effects
	if accessibility_toggle_btn:
		accessibility_toggle_btn.button_pressed = SaveManager.show_accessibility_symbols
	if sound_toggle_btn:
		sound_toggle_btn.button_pressed = SaveManager.sound_enabled
		
	pause_overlay.visible = true
	pause_toggled.emit(true)

func _on_resume_pressed() -> void:
	AudioManager.play_ui_click()
	is_paused = false
	pause_overlay.visible = false
	pause_toggled.emit(false)

func hide_overlays() -> void:
	if win_overlay:
		win_overlay.visible = false
	if lose_overlay:
		lose_overlay.visible = false
	if pause_overlay:
		pause_overlay.visible = false
