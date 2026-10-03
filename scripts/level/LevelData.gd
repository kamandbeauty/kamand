class_name LevelData
extends Resource

@export var level_id: int = 1
@export var world_id: int = 1
@export var level_name: String = "Level 1"
@export var description: String = ""
@export var max_shots: int = 30
@export var danger_row: int = Constants.DEFAULT_DANGER_ROW
@export var target_score: int = 500

@export var objective_type: int = Enums.ObjectiveType.CLEAR_ALL
@export var objective_target_count: int = 0
@export var objective_target_color: int = Enums.BubbleColor.NONE

@export var allowed_colors: Array[int] = []
@export var layout_rows: Array[String] = []
@export var special_layout: Dictionary = {} # "r,c" -> special_type (int)

## Converts char symbol ('R', 'B', 'G', 'Y', 'P', 'C', '.') to BubbleColor enum
static func char_to_bubble_color(ch: String) -> int:
	match ch.to_upper():
		"R": return Enums.BubbleColor.RED
		"B": return Enums.BubbleColor.BLUE
		"G": return Enums.BubbleColor.GREEN
		"Y": return Enums.BubbleColor.YELLOW
		"P": return Enums.BubbleColor.PURPLE
		"C": return Enums.BubbleColor.CYAN
		_: return Enums.BubbleColor.NONE

## Converts BubbleColor enum to char symbol
static func bubble_color_to_char(color: int) -> String:
	match color:
		Enums.BubbleColor.RED: return "R"
		Enums.BubbleColor.BLUE: return "B"
		Enums.BubbleColor.GREEN: return "G"
		Enums.BubbleColor.YELLOW: return "Y"
		Enums.BubbleColor.PURPLE: return "P"
		Enums.BubbleColor.CYAN: return "C"
		_: return "."

## Serializes LevelData to Dictionary
func to_dict() -> Dictionary:
	return {
		"level_id": level_id,
		"world_id": world_id,
		"level_name": level_name,
		"description": description,
		"max_shots": max_shots,
		"danger_row": danger_row,
		"target_score": target_score,
		"objective_type": objective_type,
		"objective_target_count": objective_target_count,
		"objective_target_color": objective_target_color,
		"allowed_colors": allowed_colors,
		"layout_rows": layout_rows,
		"special_layout": special_layout
	}

## Deserializes LevelData from Dictionary with full backward compatibility
static func from_dict(dict: Dictionary) -> LevelData:
	var lvl: LevelData = LevelData.new()
	lvl.level_id = int(dict.get("level_id", 1))
	
	# Determine world from ID if not set
	var default_world: int = 1
	if lvl.level_id > 20:
		default_world = 3
	elif lvl.level_id > 10:
		default_world = 2
	lvl.world_id = int(dict.get("world_id", default_world))
	
	lvl.level_name = str(dict.get("level_name", "Level %d" % lvl.level_id))
	lvl.description = str(dict.get("description", ""))
	lvl.max_shots = int(dict.get("max_shots", 25))
	lvl.danger_row = int(dict.get("danger_row", Constants.DEFAULT_DANGER_ROW))
	lvl.target_score = int(dict.get("target_score", 300))
	
	lvl.objective_type = int(dict.get("objective_type", Enums.ObjectiveType.CLEAR_ALL))
	lvl.objective_target_count = int(dict.get("objective_target_count", 0))
	lvl.objective_target_color = int(dict.get("objective_target_color", Enums.BubbleColor.NONE))
	
	var raw_colors: Variant = dict.get("allowed_colors", [])
	if typeof(raw_colors) == TYPE_ARRAY:
		var cols: Array[int] = []
		for c in raw_colors:
			cols.append(int(c))
		lvl.allowed_colors = cols
	else:
		lvl.allowed_colors = [Enums.BubbleColor.RED, Enums.BubbleColor.BLUE, Enums.BubbleColor.GREEN]
		
	var raw_layout: Variant = dict.get("layout_rows", [])
	if typeof(raw_layout) == TYPE_ARRAY:
		var rows: Array[String] = []
		for r in raw_layout:
			rows.append(str(r))
		lvl.layout_rows = rows
	else:
		lvl.layout_rows = []
		
	var raw_spec: Variant = dict.get("special_layout", {})
	if typeof(raw_spec) == TYPE_DICTIONARY:
		lvl.special_layout = (raw_spec as Dictionary).duplicate()
	else:
		lvl.special_layout = {}
		
	return lvl
