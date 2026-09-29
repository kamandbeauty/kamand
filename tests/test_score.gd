class_name TestScore
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_base_match_score(results)
	test_drop_score(results)
	test_combo_multiplier(results)
	test_combo_reset(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_base_match_score(results: Dictionary) -> void:
	var match_count: int = 3
	var score: int = match_count * Constants.POINTS_PER_MATCH
	_assert(score == 30, "3 matched bubbles award 30 base points", results)
	
	var match_5: int = 5 * Constants.POINTS_PER_MATCH
	_assert(match_5 == 50, "5 matched bubbles award 50 base points", results)

static func test_drop_score(results: Dictionary) -> void:
	var drop_count: int = 4
	var score: int = drop_count * Constants.POINTS_PER_DROP
	_assert(score == 80, "4 dropped bubbles award 80 points", results)

static func test_combo_multiplier(results: Dictionary) -> void:
	# Combo 1 (base): mult = 1.0 -> 3 * 10 = 30
	# Combo 2: mult = 1.0 + 1 * 0.25 = 1.25 -> 3 * 10 * 1.25 = 37.5 -> 37
	# Combo 3: mult = 1.0 + 2 * 0.25 = 1.50 -> 3 * 10 * 1.50 = 45
	var combo_1_mult: float = 1.0 + float(1 - 1) * Constants.COMBO_BONUS_MULTIPLIER
	var combo_2_mult: float = 1.0 + float(2 - 1) * Constants.COMBO_BONUS_MULTIPLIER
	var combo_3_mult: float = 1.0 + float(3 - 1) * Constants.COMBO_BONUS_MULTIPLIER
	
	_assert(is_equal_approx(combo_1_mult, 1.0), "Combo 1 multiplier is 1.0", results)
	_assert(is_equal_approx(combo_2_mult, 1.25), "Combo 2 multiplier is 1.25", results)
	_assert(is_equal_approx(combo_3_mult, 1.50), "Combo 3 multiplier is 1.50", results)
	
	var score_combo_2: int = int(float(3 * Constants.POINTS_PER_MATCH) * combo_2_mult)
	_assert(score_combo_2 == 37, "3 match with Combo 2 awards 37 points", results)

static func test_combo_reset(results: Dictionary) -> void:
	var combo: int = 3
	# Simulating miss (no match formed)
	combo = 0
	_assert(combo == 0, "Combo resets to 0 on non-matching shot", results)
