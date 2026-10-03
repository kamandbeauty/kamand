class_name TestSave
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_save_and_load_cycle(results)
	test_unlock_progression(results)
	test_high_score_recording(results)
	test_missing_save_fallback(results)
	test_corrupted_json_recovery(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_save_and_load_cycle(results: Dictionary) -> void:
	SaveManager.reset_save()
	SaveManager.highest_unlocked_level = 3
	SaveManager.current_level = 2
	SaveManager.total_score = 1500
	SaveManager.save_game()
	
	SaveManager.load_game()
	_assert(SaveManager.highest_unlocked_level == 3, "Loaded highest unlocked level matches", results)
	_assert(SaveManager.current_level == 2, "Loaded current level matches", results)
	_assert(SaveManager.total_score == 1500, "Loaded total score matches", results)

static func test_unlock_progression(results: Dictionary) -> void:
	SaveManager.reset_save()
	SaveManager.unlock_level(2)
	_assert(SaveManager.highest_unlocked_level == 2, "Level 2 unlocked", results)
	
	SaveManager.unlock_level(1)
	_assert(SaveManager.highest_unlocked_level == 2, "Lower level does not downgrade unlocked progression", results)

static func test_high_score_recording(results: Dictionary) -> void:
	SaveManager.reset_save()
	SaveManager.set_high_score(1, 500)
	_assert(SaveManager.get_high_score(1) == 500, "High score recorded for level 1", results)
	
	SaveManager.set_high_score(1, 300)
	_assert(SaveManager.get_high_score(1) == 500, "Lower score does not overwrite high score", results)
	
	SaveManager.set_high_score(1, 800)
	_assert(SaveManager.get_high_score(1) == 800, "Higher score updates high score", results)

static func test_missing_save_fallback(results: Dictionary) -> void:
	SaveManager.reset_save()
	_assert(SaveManager.highest_unlocked_level == 1, "Default highest level is 1", results)
	_assert(SaveManager.current_level == 1, "Default current level is 1", results)

static func test_corrupted_json_recovery(results: Dictionary) -> void:
	var file: FileAccess = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file != null:
		file.store_string("INVALID_CORRUPTED_JSON{{{///@@@")
		file.close()
		
	SaveManager.load_game()
	_assert(SaveManager.highest_unlocked_level == 1, "Corrupted save resets cleanly to level 1 default without crash", results)
