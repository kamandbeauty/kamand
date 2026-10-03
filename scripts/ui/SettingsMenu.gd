class_name SettingsMenu
extends Control

signal back_pressed()

@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var sound_toggle: CheckButton = $Panel/VBox/SoundToggle
@onready var effects_toggle: CheckButton = $Panel/VBox/EffectsToggle
@onready var runes_toggle: CheckButton = $Panel/VBox/RunesToggle
@onready var reset_btn: Button = $Panel/VBox/ResetBtn
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog

func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			back_pressed.emit()
		)
	if sound_toggle:
		sound_toggle.button_pressed = SaveManager.sound_enabled
		sound_toggle.toggled.connect(func(toggled: bool):
			SaveManager.sound_enabled = toggled
			SaveManager.save_game()
		)
	if effects_toggle:
		effects_toggle.button_pressed = SaveManager.reduced_effects
		effects_toggle.toggled.connect(func(toggled: bool):
			SaveManager.reduced_effects = toggled
			SaveManager.save_game()
		)
	if runes_toggle:
		runes_toggle.button_pressed = SaveManager.show_accessibility_symbols
		runes_toggle.toggled.connect(func(toggled: bool):
			SaveManager.show_accessibility_symbols = toggled
			SaveManager.save_game()
		)
	if reset_btn:
		reset_btn.pressed.connect(func():
			if confirm_dialog:
				confirm_dialog.popup_centered()
		)
	if confirm_dialog:
		confirm_dialog.confirmed.connect(func():
			SaveManager.reset_save()
			SaveManager.save_game()
			AudioManager.play_ui_click()
			back_pressed.emit()
		)
