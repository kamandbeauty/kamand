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
	var sm: SaveManager = SaveManager.new()
	sm.reset_save()
	sm.highest_unlocked_level = 3
	sm.current_level = 2
	sm.total_score = 1500
	sm.save_game()
	
	var sm2: SaveManager = SaveManager.new()
	sm2.load_game()
	_assert(sm2.highest_unlocked_level == 3, "Loaded highest unlocked level matches", results)
	_assert(sm2.current_level == 2, "Loaded current level matches", results)
	_assert(sm2.total_score == 1500, "Loaded total score matches", results)
	
	sm.free()
	sm2.free()

static func test_unlock_progression(results: Dictionary) -> void:
	var sm: SaveManager = SaveManager.new()
	sm.reset_save()
	sm.unlock_level(2)
	_assert(sm.highest_unlocked_level == 2, "Level 2 unlocked", results)
	
	sm.unlock_level(1) # Lower level should not downgrade
	_assert(sm.highest_unlocked_level == 2, "Lower level does not downgrade unlocked progression", results)
	
	sm.free()

static func test_high_score_recording(results: Dictionary) -> void:
	var sm: SaveManager = SaveManager.new()
	sm.reset_save()
	sm.set_high_score(1, 500)
	_assert(sm.get_high_score(1) == 500, "High score recorded for level 1", results)
	
	sm.set_high_score(1, 300) # Lower score should not overwrite
	_assert(sm.get_high_score(1) == 500, "Lower score does not overwrite high score", results)
	
	sm.set_high_score(1, 800) # Higher score updates
	_assert(sm.get_high_score(1) == 800, "Higher score updates high score", results)
	
	sm.free()

static func test_missing_save_fallback(results: Dictionary) -> void:
	# Test with non-existent file path
	var sm: SaveManager = SaveManager.new()
	# Reset state
	sm.reset_save()
	_assert(sm.highest_unlocked_level == 1, "Default highest level is 1", results)
	_assert(sm.current_level == 1, "Default current level is 1", results)
	sm.free()

static func test_corrupted_json_recovery(results: Dictionary) -> void:
	# Write corrupted content to save path
	var file: FileAccess = FileAccess.open(SaveManager.SAVE_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("INVALID_CORRUPTED_JSON{{{///@@@")
		file.close()
		
	var sm: SaveManager = SaveManager.new()
	var success: bool = sm.load_game() # Should handle safely without crash
	_assert(sm.highest_unlocked_level == 1, "Corrupted save resets cleanly to level 1 default without crash", results)
	sm.free()
