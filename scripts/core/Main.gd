class_name Main
extends Node

@export var main_menu_scene: PackedScene
@export var world_map_scene: PackedScene
@export var gameplay_scene: PackedScene
@export var settings_menu_scene: PackedScene

var active_view: Node = null

func _ready() -> void:
	if main_menu_scene == null:
		main_menu_scene = load("res://scenes/menu/MainMenu.tscn")
	if world_map_scene == null:
		world_map_scene = load("res://scenes/menu/WorldMap.tscn")
	if gameplay_scene == null:
		gameplay_scene = load("res://scenes/gameplay/BubbleShooterGame.tscn")
	if settings_menu_scene == null:
		settings_menu_scene = load("res://scenes/menu/SettingsMenu.tscn")
		
	show_main_menu()

func _clear_active_view() -> void:
	if is_instance_valid(active_view):
		active_view.queue_free()
		active_view = null

func show_main_menu() -> void:
	_clear_active_view()
	var menu: MainMenu = main_menu_scene.instantiate() as MainMenu
	active_view = menu
	add_child(menu)
	menu.play_requested.connect(show_world_map)
	menu.settings_requested.connect(show_settings)

func show_world_map() -> void:
	_clear_active_view()
	var map: WorldMap = world_map_scene.instantiate() as WorldMap
	active_view = map
	add_child(map)
	map.level_selected.connect(start_game)
	map.back_requested.connect(show_main_menu)

func show_settings() -> void:
	_clear_active_view()
	var settings: SettingsMenu = settings_menu_scene.instantiate() as SettingsMenu
	active_view = settings
	add_child(settings)
	settings.back_requested.connect(show_main_menu)

## Instantiates and starts the Bubble Shooter game with level_id
func start_game(level_id: int) -> void:
	_clear_active_view()
	var game: BubbleShooterGame = gameplay_scene.instantiate() as BubbleShooterGame
	game.current_level_id = level_id
	active_view = game
	add_child(game)
	
	game.game_won.connect(_on_game_won)
	game.game_lost.connect(_on_game_lost)
	game.return_to_map_requested.connect(show_world_map)
	
	if game.ui_manager:
		game.ui_manager.return_to_map_requested.connect(show_world_map)

func _on_game_won(level_id: int, _final_score: int, stars: int) -> void:
	SaveManager.set_stars_earned(level_id, stars)
	SaveManager.unlock_level(level_id + 1)
	SaveManager.save_game()

func _on_game_lost(_level_id: int, _reason: String) -> void:
	pass
