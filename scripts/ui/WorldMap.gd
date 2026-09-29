class_name WorldMap
extends Control

signal level_selected(level_id: int)
signal back_pressed()

@onready var stars_total_label: Label = $TopBar/StarsTotalLabel
@onready var back_btn: Button = $TopBar/BackBtn
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var levels_grid_container: GridContainer = $ScrollContainer/VBox/LevelsGrid

func _ready() -> void:
	if back_btn:
		back_btn.pressed.connect(func():
			AudioManager.play_ui_click()
			back_pressed.emit()
		)
	refresh_map()

func refresh_map() -> void:
	if stars_total_label:
		stars_total_label.text = "★ %d / 90 STARS" % SaveManager.get_total_stars()
		
	if levels_grid_container:
		# Clear existing children
		for child in levels_grid_container.get_children():
			child.queue_free()
			
		for i in range(1, Constants.TOTAL_LEVELS + 1):
			var world_id: int = LevelManager.get_world_for_level(i)
			var is_world_unlocked: bool = SaveManager.is_world_unlocked(world_id)
			var is_level_unlocked: bool = (i <= SaveManager.highest_unlocked_level) and is_world_unlocked
			var stars: int = SaveManager.get_stars_earned(i)
			
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(120.0, 95.0)
			
			var star_str: String = "☆☆☆"
			if stars == 1: star_str = "★☆☆"
			elif stars == 2: star_str = "★★☆"
			elif stars == 3: star_str = "★★★"
			
			if is_level_unlocked:
				btn.text = "LVL %d\n%s" % [i, star_str]
				btn.disabled = false
				btn.pressed.connect(func():
					AudioManager.play_ui_click()
					level_selected.emit(i)
				)
			else:
				var lock_reason: String = "🔒 LOCKED"
				if not is_world_unlocked:
					var req: int = 15 if world_id == 2 else 35
					lock_reason = "🔒 (%d★)" % req
				btn.text = "LVL %d\n%s" % [i, lock_reason]
				btn.disabled = true
				
			levels_grid_container.add_child(btn)
