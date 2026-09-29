class_name TestPhase2Visuals
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_save_manager_audio_visual_prefs(results)
	test_star_rating_system(results)
	test_companion_lumi_states(results)
	test_screen_feedback_trauma(results)
	test_reduced_effects_setting(results)
	test_bubble_visual_runes(results)
	test_audio_manager_voices(results)
	test_safe_restart_during_effects(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_save_manager_audio_visual_prefs(results: Dictionary) -> void:
	var sm: SaveManager = SaveManager.new()
	sm.reset_save()
	sm.sfx_volume = 0.75
	sm.music_volume = 0.50
	sm.reduced_effects = true
	sm.show_accessibility_symbols = true
	sm.save_game()
	
	var sm2: SaveManager = SaveManager.new()
	sm2.load_game()
	_assert(is_equal_approx(sm2.sfx_volume, 0.75), "SFX volume persisted and loaded", results)
	_assert(is_equal_approx(sm2.music_volume, 0.50), "Music volume persisted and loaded", results)
	_assert(sm2.reduced_effects == true, "Reduced effects persisted and loaded", results)
	_assert(sm2.show_accessibility_symbols == true, "Accessibility symbols persisted and loaded", results)
	
	sm.free()
	sm2.free()

static func test_star_rating_system(results: Dictionary) -> void:
	var sm: SaveManager = SaveManager.new()
	sm.reset_save()
	sm.set_stars_earned(1, 2)
	_assert(sm.get_stars_earned(1) == 2, "Level 1 awarded 2 stars", results)
	
	sm.set_stars_earned(1, 1) # Lower stars shouldn't overwrite
	_assert(sm.get_stars_earned(1) == 2, "Lower star rating does not downgrade", results)
	
	sm.set_stars_earned(1, 3) # Higher stars update
	_assert(sm.get_stars_earned(1) == 3, "Higher star rating updates to 3 stars", results)
	
	sm.free()

static func test_companion_lumi_states(results: Dictionary) -> void:
	var lumi: CompanionLumi = CompanionLumi.new()
	_assert(lumi.current_state == CompanionLumi.LumiState.IDLE, "Lumi default state is IDLE", results)
	
	lumi.set_state(CompanionLumi.LumiState.AIMING)
	_assert(lumi.current_state == CompanionLumi.LumiState.AIMING, "Lumi state changes to AIMING", results)
	
	lumi.set_state(CompanionLumi.LumiState.MATCH_SUCCESS)
	_assert(lumi.current_state == CompanionLumi.LumiState.MATCH_SUCCESS, "Lumi state changes to MATCH_SUCCESS", results)
	
	lumi.set_state(CompanionLumi.LumiState.LARGE_COMBO)
	_assert(lumi.current_state == CompanionLumi.LumiState.LARGE_COMBO, "Lumi state changes to LARGE_COMBO", results)
	
	lumi.set_state(CompanionLumi.LumiState.WIN)
	_assert(lumi.current_state == CompanionLumi.LumiState.WIN, "Lumi state changes to WIN", results)
	
	lumi.set_state(CompanionLumi.LumiState.LOSE)
	_assert(lumi.current_state == CompanionLumi.LumiState.LOSE, "Lumi state changes to LOSE", results)
	
	lumi.free()

static func test_screen_feedback_trauma(results: Dictionary) -> void:
	var feedback: ScreenFeedback = ScreenFeedback.new()
	_assert(feedback.trauma == 0.0, "Initial camera trauma is 0", results)
	
	SaveManager.reduced_effects = false
	feedback.add_trauma(0.5)
	_assert(is_equal_approx(feedback.trauma, 0.5), "Trauma increases to 0.5", results)
	
	feedback.add_trauma(0.8) # Clamped at 1.0
	_assert(is_equal_approx(feedback.trauma, 1.0), "Trauma clamped at 1.0 max", results)
	
	SaveManager.reduced_effects = true
	feedback.trauma = 0.0
	feedback.add_trauma(0.5) # In reduced-effects, trauma ignored
	_assert(feedback.trauma == 0.0, "Reduced effects prevents camera trauma", results)
	
	SaveManager.reduced_effects = false
	feedback.free()

static func test_reduced_effects_setting(results: Dictionary) -> void:
	var p_mgr: ParticleManager = ParticleManager.new()
	SaveManager.reduced_effects = true
	p_mgr.emit_bounce_sparks(Vector2(100, 100))
	_assert(p_mgr.get_child_count() == 0, "No particles spawned when reduced_effects is true", results)
	
	SaveManager.reduced_effects = false
	p_mgr.free()

static func test_bubble_visual_runes(results: Dictionary) -> void:
	var b: Bubble = Bubble.new()
	for color_val in [
		Enums.BubbleColor.RED,
		Enums.BubbleColor.BLUE,
		Enums.BubbleColor.GREEN,
		Enums.BubbleColor.YELLOW,
		Enums.BubbleColor.PURPLE,
		Enums.BubbleColor.CYAN
	]:
		b.set_bubble_type(color_val)
		_assert(b.bubble_color == color_val, "Bubble configured for color %d" % color_val, results)
	b.free()

static func test_audio_manager_voices(results: Dictionary) -> void:
	_assert(AudioManager.MAX_SFX_VOICES == 8, "Audio manager configured with 8 SFX voice pool", results)

static func test_safe_restart_during_effects(results: Dictionary) -> void:
	var p_mgr: ParticleManager = ParticleManager.new()
	p_mgr.clear_all_effects()
	_assert(p_mgr.get_child_count() == 0, "Effects cleared safely during restart", results)
	p_mgr.free()
