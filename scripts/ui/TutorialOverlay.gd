class_name TutorialOverlay
extends Control

signal tutorial_dismissed()

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var ok_btn: Button = $Panel/VBox/HBox/OkBtn
@onready var skip_btn: Button = $Panel/VBox/HBox/SkipBtn
@onready var companion_lumi: CompanionLumi = $CompanionLumi

var current_tutorial_id: String = ""

func _ready() -> void:
	if ok_btn:
		ok_btn.pressed.connect(_on_dismiss)
	if skip_btn:
		skip_btn.pressed.connect(_on_dismiss)

func show_tutorial_for_level(level_id: int) -> bool:
	var tut_id: String = ""
	var tut_title: String = ""
	var tut_msg: String = ""
	
	match level_id:
		1:
			tut_id = "tut_aim_match"
			tut_title = "AIM & MATCH-3"
			tut_msg = "Drag anywhere on the screen to aim, and release to shoot! Connect 3 or more bubbles of the same color to pop them!"
		2:
			tut_id = "tut_wall_bounce"
			tut_title = "WALL BOUNCING"
			tut_msg = "Bank your bubbles off the side walls to reach high angles and tricky clusters!"
		3:
			tut_id = "tut_floating_drop"
			tut_title = "AVALANCHE DROPS"
			tut_msg = "Bubbles must stay connected to the ceiling! Pop the top anchor bubbles to drop all unsupported bubbles below for huge bonus points!"
		11:
			tut_id = "tut_bomb_bubble"
			tut_title = "BOMB BUBBLES 💣"
			tut_msg = "Detonate Bomb bubbles by hitting them! They blast away all surrounding bubbles and obstacles in a fiery explosion!"
		12:
			tut_id = "tut_rainbow_wild"
			tut_title = "RAINBOW WILDS 🌈"
			tut_msg = "Rainbow bubbles are wild! They connect and match with any colored bubble cluster on the board!"
		13:
			tut_id = "tut_lightning_beam"
			tut_title = "LIGHTNING BEAM ⚡"
			tut_msg = "Hit Lightning bubbles to trigger an electric surge that clears an entire horizontal line!"
		14:
			tut_id = "tut_stone_obstacle"
			tut_title = "STONE BLOCKS 🪨"
			tut_msg = "Stone bubbles are unbreakable obstacles. You cannot match them—drop them by severing ceiling anchors or blast them with Bombs!"
		15:
			tut_id = "tut_locked_ice"
			tut_title = "LOCKED ICE SHELLS ❄"
			tut_msg = "Locked bubbles are encased in ice. Make a match directly adjacent to them to crack the shell free!"
		21:
			tut_id = "tut_level_objectives"
			tut_title = "LEVEL OBJECTIVES"
			tut_msg = "Check your objective at the top! Clear the required target colors or obstacles before your shots run out!"
		_:
			return false
			
	if SaveManager.is_tutorial_seen(tut_id):
		return false
		
	current_tutorial_id = tut_id
	title_label.text = tut_title
	message_label.text = tut_msg
	visible = true
	
	if companion_lumi:
		companion_lumi.set_state(CompanionLumi.LumiState.AIMING)
		
	return true

func _on_dismiss() -> void:
	AudioManager.play_ui_click()
	if not current_tutorial_id.is_empty():
		SaveManager.mark_tutorial_seen(current_tutorial_id)
	visible = false
	tutorial_dismissed.emit()
