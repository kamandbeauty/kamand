class_name LevelManager
extends RefCounted

const TOTAL_LEVELS: int = 30
const TOTAL_WORLDS: int = 3
const LEVELS_PER_WORLD: int = 10
const LEVEL_PATH_TEMPLATE: String = "res://data/levels/level_%d.json"

## Loads LevelData for a specific level ID with fallback protection
static func load_level(level_id: int) -> LevelData:
	var path: String = LEVEL_PATH_TEMPLATE % level_id
	if not FileAccess.file_exists(path):
		push_warning("Level file not found: %s. Loading fallback level." % path)
		return create_fallback_level(level_id)
		
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to read level file: %s" % path)
		return create_fallback_level(level_id)
		
	var content: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var err: Error = json.parse(content)
	if err != OK:
		push_error("JSON Parse error in %s: %s" % [path, json.get_error_message()])
		return create_fallback_level(level_id)
		
	var dict: Variant = json.data
	if typeof(dict) != TYPE_DICTIONARY:
		push_error("Level data root must be Dictionary in %s" % path)
		return create_fallback_level(level_id)
		
	var level_data: LevelData = LevelData.from_dict(dict as Dictionary)
	return level_data

## Returns fallback level if file is missing or corrupted
static func create_fallback_level(level_id: int) -> LevelData:
	var lvl: LevelData = LevelData.new()
	lvl.level_id = level_id
	lvl.world_id = get_world_for_level(level_id)
	lvl.level_name = "Level %d (Fallback)" % level_id
	lvl.description = "Fallback test level."
	lvl.max_shots = 30
	lvl.danger_row = Constants.DEFAULT_DANGER_ROW
	lvl.target_score = 300
	lvl.allowed_colors = [Enums.BubbleColor.RED, Enums.BubbleColor.BLUE, Enums.BubbleColor.GREEN]
	lvl.layout_rows = [
		"RR..BB..",
		".R...B.",
		"..R...B."
	]
	return lvl

static func get_total_level_count() -> int:
	return TOTAL_LEVELS

static func get_world_for_level(level_id: int) -> int:
	if level_id > 20:
		return 3
	elif level_id > 10:
		return 2
	return 1

static func get_next_level_id(current_id: int) -> int:
	if current_id >= TOTAL_LEVELS:
		return 1 # Wrap around to Level 1
	return current_id + 1
