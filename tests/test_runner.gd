class_name TestRunner
extends SceneTree

func _init() -> void:
	print("\n========================================================")
	print("  BUBBLEWOOD (PHASE 1 + 2 + 3) — AUTOMATED TEST SUITE")
	print("========================================================\n")
	
	var total_passed: int = 0
	var total_failed: int = 0
	var all_errors: Array[String] = []
	
	var suites: Array[Dictionary] = [
		{"name": "Grid System (Hex Offset Math & Snap)", "fn": Callable(TestGrid, "run_all_tests")},
		{"name": "Match Detector (BFS 3+ Same Color)", "fn": Callable(TestMatch, "run_all_tests")},
		{"name": "Floating Detector (Ceiling BFS)", "fn": Callable(TestFloating, "run_all_tests")},
		{"name": "Scoring & Combo System", "fn": Callable(TestScore, "run_all_tests")},
		{"name": "Level System & 10 Base Levels", "fn": Callable(TestLevel, "run_all_tests")},
		{"name": "Save System (JSON Storage & Recovery)", "fn": Callable(TestSave, "run_all_tests")},
		{"name": "Color Generator (Deterministic Seed)", "fn": Callable(TestColorGen, "run_all_tests")},
		{"name": "Trajectory & Reflection Math", "fn": Callable(TestTrajectory, "run_all_tests")},
		{"name": "Phase 2 Visuals, Audio & Polish", "fn": Callable(TestPhase2Visuals, "run_all_tests")},
		{"name": "Phase 3 Special Bubbles, 30 Levels, Star Gates & Objectives", "fn": Callable(TestPhase3Features, "run_all_tests")},
	]
	
	for suite in suites:
		var s_name: String = suite["name"]
		var s_fn: Callable = suite["fn"]
		var res: Dictionary = s_fn.call()
		
		var p: int = res.get("passed", 0)
		var f: int = res.get("failed", 0)
		var errs: Array = res.get("errors", [])
		
		total_passed += p
		total_failed += f
		for e in errs:
			all_errors.append("[%s] %s" % [s_name, str(e)])
			
		var status_str: String = "PASS" if f == 0 else "FAIL"
		print("[%s] %s -> Passed: %d, Failed: %d" % [status_str, s_name, p, f])
		
	print("\n--------------------------------------------------------")
	print("TEST SUMMARY:")
	print("Total Tests Executed: %d" % (total_passed + total_failed))
	print("Passed: %d" % total_passed)
	print("Failed: %d" % total_failed)
	print("--------------------------------------------------------")
	
	if total_failed > 0:
		print("\nFAILURES:")
		for err in all_errors:
			print("  - ", err)
		print("\nOVERALL STATUS: FAILED")
	else:
		print("\nOVERALL STATUS: ALL TESTS PASSED (100% SUCCESS)")
	print("========================================================\n")
	
	quit(0 if total_failed == 0 else 1)
