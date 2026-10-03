class_name MainMenu
extends Control

signal play_pressed()
signal map_pressed()
signal settings_pressed()

@onready var title_label: Label = $VBox/TitleLabel
@onready var play_btn: Button = $VBox/PlayBtn
@onready var map_btn: Button = $VBox/MapBtn
@onready var settings_btn: Button = $VBox/SettingsBtn
@onready var companion_lumi: CompanionLumi = $CompanionLumi

func _ready() -> void:
	if play_btn:
		play_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			play_pressed.emit()
		)
	if map_btn:
		map_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			map_pressed.emit()
		)
	if settings_btn:
		settings_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			settings_pressed.emit()
		)
	if companion_lumi:
		companion_lumi.set_state(CompanionLumi.LumiState.IDLE)
