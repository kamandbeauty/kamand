class_name ColorGenerator
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_val: int = 0) -> void:
	if seed_val != 0:
		_rng.seed = seed_val
	else:
		_rng.randomize()

func set_seed(seed_val: int) -> void:
	_rng.seed = seed_val

## Returns next bubble color prioritizing colors currently on the board
func get_next_color(allowed_colors: Array[int], active_board_colors: Array[int]) -> int:
	# If no specific allowed colors provided, fallback to all standard colors
	var pool: Array[int] = allowed_colors
	if pool.is_empty():
		pool = [
			Enums.BubbleColor.RED,
			Enums.BubbleColor.BLUE,
			Enums.BubbleColor.GREEN,
			Enums.BubbleColor.YELLOW,
			Enums.BubbleColor.PURPLE,
			Enums.BubbleColor.CYAN
		]
		
	# If active colors on the board exist, restrict pool to active colors that are in allowed_colors
	if not active_board_colors.is_empty():
		var valid_active: Array[int] = []
		for c in active_board_colors:
			if pool.has(c):
				valid_active.append(c)
		if not valid_active.is_empty():
			var idx: int = _rng.randi_range(0, valid_active.size() - 1)
			return valid_active[idx]
			
	# Fallback to general pool
	var idx2: int = _rng.randi_range(0, pool.size() - 1)
	return pool[idx2]
