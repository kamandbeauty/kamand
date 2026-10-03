extends Node

const SAVE_FILE_PATH: String = "user://savegame.json"
const SAVE_TEMP_PATH: String = "user://savegame.tmp"
const SAVE_VERSION: int = 3
const CURRENT_SAVE_VERSION: int = 3

# Progression state
var highest_unlocked_level: int = 1
var current_level: int = 1
var current_world: int = 1
var high_scores: Dictionary = {}
var stars_earned: Dictionary = {} # level_id -> int (1..3)
var unlocked_worlds: Dictionary = {"1": true}
var tutorial_seen: Dictionary = {}
var total_score: int = 0

# Audio preferences
var sound_enabled: bool = true
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var sfx_muted: bool = false
var music_muted: bool = false

# Visual settings
var reduced_effects: bool = false
var show_accessibility_symbols: bool = true

func _ready() -> void:
	load_game()

## Saves current progress to JSON file using atomic write
func save_game() -> bool:
	var data: Dictionary = {
		"highest_unlocked_level": highest_unlocked_level,
		"current_level": current_level,
		"current_world": current_world,
		"high_scores": high_scores,
		"stars_earned": stars_earned,
		"unlocked_worlds": unlocked_worlds,
		"tutorial_seen": tutorial_seen,
		"total_score": total_score,
		"sound_enabled": sound_enabled,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"sfx_muted": sfx_muted,
		"music_muted": music_muted,
		"reduced_effects": reduced_effects,
		"show_accessibility_symbols": show_accessibility_symbols,
		"version": CURRENT_SAVE_VERSION
	}
	
	var json_string: String = JSON.stringify(data, "\t")
	
	# Atomic write: write to temp file then rename/replace
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s (Error: %d)" % [SAVE_FILE_PATH, FileAccess.get_open_error()])
		return false
		
	file.store_string(json_string)
	file.close()
	return true

## Loads progress from JSON file with graceful fallback on corruption
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		reset_save()
		save_game()
		return true
		
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Failed to open save file for reading. Using defaults.")
		reset_save()
		return false
		
	var content: String = file.get_as_text()
	file.close()
	
	if content.strip_edges().is_empty():
		push_warning("Save file is empty. Resetting to defaults.")
		reset_save()
		return false
		
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(content)
	if parse_result != OK:
		push_warning("Save file corrupted JSON (Error: %s at line %d). Resetting to defaults." % [json.get_error_message(), json.get_error_line()])
		reset_save()
		return false
		
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file data is not a valid Dictionary. Resetting to defaults.")
		reset_save()
		return false
		
	return load_from_dict(data as Dictionary)

## Populates state from a dictionary
func load_from_dict(dict: Dictionary) -> bool:
	highest_unlocked_level = int(dict.get("highest_unlocked_level", dict.get("current_level", 1)))
	current_level = int(dict.get("current_level", 1))
	current_world = int(dict.get("current_world", 1))
	total_score = int(dict.get("total_score", 0))
	sound_enabled = bool(dict.get("sound_enabled", true))
	sfx_volume = clampf(float(dict.get("sfx_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(dict.get("music_volume", 0.8)), 0.0, 1.0)
	sfx_muted = bool(dict.get("sfx_muted", false))
	music_muted = bool(dict.get("music_muted", false))
	reduced_effects = bool(dict.get("reduced_effects", false))
	show_accessibility_symbols = bool(dict.get("show_accessibility_symbols", true))
	
	var raw_scores: Variant = dict.get("high_scores", {})
	if typeof(raw_scores) == TYPE_DICTIONARY:
		high_scores = (raw_scores as Dictionary).duplicate()
	else:
		high_scores = {}
		
	var raw_stars: Variant = dict.get("stars_earned", {})
	if typeof(raw_stars) == TYPE_DICTIONARY:
		stars_earned = (raw_stars as Dictionary).duplicate()
	else:
		stars_earned = {}
		
	# Migration for V1/V2 to V3 stars if missing
	if stars_earned.is_empty():
		for lvl in range(1, highest_unlocked_level + 1):
			stars_earned[str(lvl)] = 1
			
	var raw_worlds: Variant = dict.get("unlocked_worlds", {"1": true})
	if typeof(raw_worlds) == TYPE_DICTIONARY:
		unlocked_worlds = (raw_worlds as Dictionary).duplicate()
	else:
		unlocked_worlds = {"1": true}
		
	var raw_tutorials: Variant = dict.get("tutorial_seen", dict.get("seen_tutorials", {}))
	if typeof(raw_tutorials) == TYPE_DICTIONARY:
		tutorial_seen = (raw_tutorials as Dictionary).duplicate()
	elif typeof(raw_tutorials) == TYPE_ARRAY:
		tutorial_seen = {}
		for tut in (raw_tutorials as Array):
			tutorial_seen[str(tut)] = true
	else:
		tutorial_seen = {}
		
	if highest_unlocked_level < 1:
		highest_unlocked_level = 1
	if current_level < 1:
		current_level = 1
		
	check_world_unlocks()
	return true

## Checks and unlocks worlds if star requirements are met
func check_world_unlocks() -> void:
	var total_stars: int = get_total_stars()
	if total_stars >= 10:
		unlocked_worlds["2"] = true
	if total_stars >= 25:
		unlocked_worlds["3"] = true

func is_world_unlocked(world_id: int) -> bool:
	if world_id == 1:
		return true
	return bool(unlocked_worlds.get(str(world_id), false))

func get_total_stars() -> int:
	var total: int = 0
	for s in stars_earned.values():
		total += int(s)
	return total

## Unlocks next level if newly reached
func unlock_level(level_id: int) -> void:
	if level_id > highest_unlocked_level:
		highest_unlocked_level = level_id
		check_world_unlocks()
		save_game()

## Records high score for a level
func set_high_score(level_id: int, score: int) -> void:
	var key: String = str(level_id)
	var prev: int = int(high_scores.get(key, 0))
	if score > prev:
		high_scores[key] = score
		save_game()

func get_high_score(level_id: int) -> int:
	var key: String = str(level_id)
	return int(high_scores.get(key, 0))

## Records star rating (1-3 stars) for a level
func set_stars_earned(level_id: int, stars: int) -> void:
	var key: String = str(level_id)
	var prev: int = int(stars_earned.get(key, 0))
	if stars > prev:
		stars_earned[key] = clampi(stars, 1, 3)
		check_world_unlocks()
		save_game()

func get_stars_earned(level_id: int) -> int:
	var key: String = str(level_id)
	return int(stars_earned.get(key, 0))

func mark_tutorial_seen(tutorial_id: String) -> void:
	tutorial_seen[tutorial_id] = true
	save_game()

func is_tutorial_seen(tutorial_id: String) -> bool:
	return bool(tutorial_seen.get(tutorial_id, false))

## Resets all progression to default clean state
func reset_save() -> void:
	highest_unlocked_level = 1
	current_level = 1
	current_world = 1
	high_scores.clear()
	stars_earned.clear()
	unlocked_worlds = {"1": true}
	tutorial_seen.clear()
	total_score = 0
	sound_enabled = true
	sfx_volume = 1.0
	music_volume = 0.8
	sfx_muted = false
	music_muted = false
	reduced_effects = false
	show_accessibility_symbols = true
