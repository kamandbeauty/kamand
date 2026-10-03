class_name ObjectiveManager
extends RefCounted

## Evaluates whether the current level objective has been satisfied
static func is_objective_complete(level_data: LevelData, grid: BubbleGrid, current_score: int, cleared_color_counts: Dictionary, cleared_specials_count: int) -> bool:
	if level_data == null:
		return grid.is_board_empty()
		
	match level_data.objective_type:
		Enums.ObjectiveType.CLEAR_ALL:
			return grid.is_board_empty()
			
		Enums.ObjectiveType.CLEAR_COLOR:
			var target_col: int = level_data.objective_target_color
			var count: int = int(cleared_color_counts.get(target_col, 0))
			return count >= level_data.objective_target_count or grid.is_board_empty()
			
		Enums.ObjectiveType.REACH_SCORE:
			return current_score >= level_data.target_score
			
		Enums.ObjectiveType.CLEAR_SPECIAL:
			return cleared_specials_count >= level_data.objective_target_count or grid.is_board_empty()
			
		_:
			return grid.is_board_empty()

## Returns a clear human-readable description string of the objective
static func get_objective_description(level_data: LevelData) -> String:
	if level_data == null:
		return "Clear all bubbles!"
		
	match level_data.objective_type:
		Enums.ObjectiveType.CLEAR_ALL:
			return "Clear all bubbles from the board!"
		Enums.ObjectiveType.CLEAR_COLOR:
			var col_name: String = Constants.COLOR_NAMES.get(level_data.objective_target_color, "color")
			return "Pop %d %s bubbles!" % [level_data.objective_target_count, col_name]
		Enums.ObjectiveType.REACH_SCORE:
			return "Reach %d points!" % level_data.target_score
		Enums.ObjectiveType.CLEAR_SPECIAL:
			return "Clear %d special obstacles!" % level_data.objective_target_count
		_:
			return "Clear all bubbles!"
