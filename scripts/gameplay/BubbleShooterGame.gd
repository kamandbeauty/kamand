class_name BubbleShooterGame
extends Node2D

signal game_won(level_id: int, score: int, stars: int)
signal game_lost(level_id: int, reason: String)
signal level_restarted()
signal next_level_requested()
signal return_to_map_requested()

@export var bubble_scene: PackedScene

# Visual & Gameplay child systems
@onready var forest_bg: ForestBackground = $ForestBackground
@onready var bubble_grid: BubbleGrid = $BubbleGrid
@onready var shooter: Shooter = $Shooter
@onready var aim_guide: AimGuide = $AimGuide
@onready var particle_manager: ParticleManager = $ParticleManager
@onready var screen_feedback: ScreenFeedback = $ScreenFeedback
@onready var companion_lumi: CompanionLumi = $CompanionLumi

# UI nodes
@onready var ui_manager: UIManager = $CanvasLayer/UIManager
@onready var tutorial_overlay: TutorialOverlay = $CanvasLayer/TutorialOverlay
@onready var debug_overlay: DebugOverlay = $CanvasLayer/DebugOverlay

var current_level_data: LevelData = null
var current_level_id: int = 1
var score: int = 0
var current_combo: int = 0
var highest_combo: int = 0
var shots_remaining: int = 30
var game_state: int = Enums.GameState.PLAYING

# Objective Tracking
var cleared_color_counts: Dictionary = {}
var cleared_specials_count: int = 0

var color_generator: ColorGenerator = ColorGenerator.new()

## Active in-flight projectile
var active_projectile: Bubble = null
var projectile_direction: Vector2 = Vector2.UP
var projectile_speed: float = Constants.SHOT_SPEED

## Touch / Drag input tracking
var is_touch_active: bool = false
var last_touch_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	if bubble_scene == null:
		bubble_scene = load("res://scenes/bubble/Bubble.tscn")
		
	_connect_signals()
	load_level(current_level_id)

func _connect_signals() -> void:
	if shooter:
		shooter.bubble_fired.connect(_on_shooter_bubble_fired)
		shooter.aim_changed.connect(_on_shooter_aim_changed)
		shooter.aim_ended.connect(_on_shooter_aim_ended)
		shooter.bubbles_swapped.connect(_on_shooter_bubbles_swapped)
		
	if ui_manager:
		ui_manager.restart_requested.connect(restart_level)
		ui_manager.next_level_requested.connect(load_next_level)
		ui_manager.pause_toggled.connect(_on_pause_toggled)
		
	if tutorial_overlay:
		tutorial_overlay.tutorial_dismissed.connect(func():
			if game_state == Enums.GameState.PAUSED:
				game_state = Enums.GameState.PLAYING
		)
		
	if debug_overlay:
		debug_overlay.debug_restart_level.connect(restart_level)
		debug_overlay.debug_next_level.connect(load_next_level)
		debug_overlay.debug_win_game.connect(func(): _trigger_win())
		debug_overlay.debug_lose_game.connect(func(): _trigger_lose("Debug Lose Triggered"))

## Loads and initializes level layout, specials, objectives, and state
func load_level(level_id: int) -> void:
	current_level_id = level_id
	current_level_data = LevelManager.load_level(level_id)
	
	score = 0
	current_combo = 0
	highest_combo = 0
	shots_remaining = current_level_data.max_shots
	game_state = Enums.GameState.PLAYING
	
	cleared_color_counts.clear()
	cleared_specials_count = 0
	
	if active_projectile != null and is_instance_valid(active_projectile):
		active_projectile.queue_free()
		active_projectile = null
		
	if particle_manager:
		particle_manager.clear_all_effects()
		
	if companion_lumi:
		companion_lumi.set_state(CompanionLumi.LumiState.IDLE)
		
	_build_board_from_layout()
	
	# Determine initial colors
	var active_colors: Array[int] = bubble_grid.get_active_colors()
	var cur_col: int = color_generator.get_next_color(current_level_data.allowed_colors, active_colors)
	var nxt_col: int = color_generator.get_next_color(current_level_data.allowed_colors, active_colors)
	
	shooter.setup_initial_bubbles(cur_col, nxt_col)
	shooter.can_shoot = true
	
	ui_manager.hide_overlays()
	ui_manager.update_level_info(current_level_data.level_name, current_level_id, current_level_data.target_score)
	ui_manager.update_score(score, SaveManager.get_high_score(current_level_id))
	ui_manager.update_shots(shots_remaining)
	ui_manager.update_combo(0)
	
	# Check tutorial overlay
	if tutorial_overlay and tutorial_overlay.show_tutorial_for_level(level_id):
		game_state = Enums.GameState.PAUSED
		
	_update_debug_stats()

## Constructs the initial grid bubbles from LevelData layout strings and special mappings
func _build_board_from_layout() -> void:
	bubble_grid.clear_grid()
	bubble_grid.danger_row = current_level_data.danger_row
	
	var rows: Array[String] = current_level_data.layout_rows
	var spec_map: Dictionary = current_level_data.special_layout
	
	for r in range(rows.size()):
		var row_str: String = rows[r]
		var max_cols: int = bubble_grid.get_cols_for_row(r)
		for c in range(mini(row_str.length(), max_cols)):
			var ch: String = row_str[c]
			var color_type: int = LevelData.char_to_bubble_color(ch)
			var key: String = "%d,%d" % [r, c]
			var spec_type: int = int(spec_map.get(key, Enums.SpecialType.NONE))
			
			if color_type != Enums.BubbleColor.NONE or spec_type != Enums.SpecialType.NONE:
				var bubble: Bubble = bubble_scene.instantiate() as Bubble
				bubble.set_bubble_type(color_type, spec_type)
				bubble_grid.add_child(bubble)
				bubble_grid.set_bubble(r, c, bubble)

## Physics loop for deterministic projectile movement & collision
func _physics_process(delta: float) -> void:
	if game_state == Enums.GameState.PAUSED:
		return
		
	if active_projectile != null and is_instance_valid(active_projectile):
		_step_projectile(delta)
		
	_update_debug_stats()

## Deterministic projectile movement step
func _step_projectile(delta: float) -> void:
	var move_dist: float = projectile_speed * delta
	var prev_pos: Vector2 = active_projectile.position
	var next_pos: Vector2 = prev_pos + projectile_direction * move_dist
	
	var left_bound: float = Constants.LEFT_WALL_X + Constants.BUBBLE_RADIUS
	var right_bound: float = Constants.RIGHT_WALL_X - Constants.BUBBLE_RADIUS
	var ceiling_bound: float = Constants.GRID_START_Y + Constants.BUBBLE_RADIUS
	
	# Wall bounce left
	if next_pos.x <= left_bound:
		next_pos.x = left_bound + (left_bound - next_pos.x)
		projectile_direction.x = abs(projectile_direction.x)
		AudioManager.play_bounce()
		if particle_manager:
			particle_manager.emit_bounce_sparks(Vector2(left_bound, next_pos.y))
		
	# Wall bounce right
	if next_pos.x >= right_bound:
		next_pos.x = right_bound - (next_pos.x - right_bound)
		projectile_direction.x = -abs(projectile_direction.x)
		AudioManager.play_bounce()
		if particle_manager:
			particle_manager.emit_bounce_sparks(Vector2(right_bound, next_pos.y))
		
	active_projectile.position = next_pos
	
	# Check ceiling collision
	if next_pos.y <= ceiling_bound:
		_attach_projectile_to_grid(next_pos)
		return
		
	# Check collision with occupied bubbles
	var collision_thresh_sq: float = pow(Constants.BUBBLE_DIAMETER * Constants.COLLISION_RADIUS_FACTOR, 2.0)
	var occupied_cells: Array[Vector2i] = bubble_grid.get_all_occupied_cells()
	
	for coord in occupied_cells:
		var b: Bubble = bubble_grid.get_bubble_v(coord)
		if is_instance_valid(b) and b != active_projectile:
			if next_pos.distance_squared_to(b.position) <= collision_thresh_sq:
				_attach_projectile_to_grid(next_pos)
				return

## Attaches the in-flight projectile into the grid authoritative model
func _attach_projectile_to_grid(contact_pos: Vector2) -> void:
	game_state = Enums.GameState.RESOLVING
	var p: Bubble = active_projectile
	active_projectile = null
	
	# Find legal snap cell
	var snap_coord: Vector2i = bubble_grid.find_best_snap_cell(contact_pos)
	var target_world_pos: Vector2 = bubble_grid.grid_to_world_v(snap_coord)
	
	if debug_overlay:
		debug_overlay.debug_last_snap = snap_coord
		
	if particle_manager:
		particle_manager.emit_snap_burst(target_world_pos, p.bubble_color)
		
	# Reparent bubble into grid node
	if p.get_parent():
		p.get_parent().remove_child(p)
	bubble_grid.add_child(p)
	bubble_grid.set_bubble_v(snap_coord, p)
	p.play_snap_animation(target_world_pos, 0.08)
	
	# Run resolution after micro-snap delay
	get_tree().create_timer(0.10).timeout.connect(func(): _resolve_matches_and_floating(snap_coord))

## Match, special bubbles & floating cluster resolution pipeline
func _resolve_matches_and_floating(new_coord: Vector2i) -> void:
	var placed_bubble: Bubble = bubble_grid.get_bubble_v(new_coord)
	var cleared_cells: Array[Vector2i] = []
	var is_special_trigger: bool = false
	
	# 1. Check if newly attached bubble triggers Bomb or Lightning
	if placed_bubble != null and placed_bubble.special_type == Enums.SpecialType.BOMB:
		is_special_trigger = true
		cleared_cells = SpecialBubbleHandler.trigger_bomb(bubble_grid, new_coord)
		score += Constants.POINTS_PER_BOMB
		AudioManager.play_combo(2)
		if screen_feedback:
			screen_feedback.add_trauma(0.5)
	elif placed_bubble != null and placed_bubble.special_type == Enums.SpecialType.LIGHTNING:
		is_special_trigger = true
		cleared_cells = SpecialBubbleHandler.trigger_lightning(bubble_grid, new_coord.x)
		score += Constants.POINTS_PER_LIGHTNING
		AudioManager.play_combo(2)
		if screen_feedback:
			screen_feedback.add_trauma(0.4)
	else:
		# Check standard / Rainbow matches
		cleared_cells = MatchDetector.find_matches(bubble_grid, new_coord)
		
	# 2. Process cleared cells
	if cleared_cells.size() >= MatchDetector.MIN_MATCH_COUNT or is_special_trigger:
		current_combo += 1
		if current_combo > highest_combo:
			highest_combo = current_combo
			
		var match_count: int = cleared_cells.size()
		var is_large_match: bool = match_count >= 5 or current_combo >= 2
		var combo_mult: float = 1.0 + float(current_combo - 1) * Constants.COMBO_BONUS_MULTIPLIER
		var match_score: int = int(float(match_count * Constants.POINTS_PER_MATCH) * combo_mult)
		score += match_score
		
		if is_large_match:
			AudioManager.play_combo(current_combo)
			if screen_feedback:
				screen_feedback.add_trauma(0.35)
			if companion_lumi:
				companion_lumi.set_state(CompanionLumi.LumiState.LARGE_COMBO)
		else:
			AudioManager.play_match(current_combo)
			if companion_lumi:
				companion_lumi.set_state(CompanionLumi.LumiState.MATCH_SUCCESS)
				
		var center_pos: Vector2 = bubble_grid.grid_to_world_v(new_coord)
		if screen_feedback:
			var popup_txt: String = "+%d" % match_score
			if current_combo > 1:
				popup_txt += " (x%d!)" % current_combo
			screen_feedback.spawn_score_popup(center_pos, popup_txt, Color(1.0, 0.88, 0.25), 26)
			
		# Pop / remove cleared bubbles and update color counts
		for coord in cleared_cells:
			var b_pos: Vector2 = bubble_grid.grid_to_world_v(coord)
			var b: Bubble = bubble_grid.remove_bubble_v(coord)
			if is_instance_valid(b):
				if b.bubble_color != Enums.BubbleColor.NONE:
					cleared_color_counts[b.bubble_color] = int(cleared_color_counts.get(b.bubble_color, 0)) + 1
				if b.special_type == Enums.SpecialType.STONE or b.special_type == Enums.SpecialType.LOCKED:
					cleared_specials_count += 1
					
				if particle_manager:
					particle_manager.emit_pop_burst(b_pos, b.bubble_color, is_large_match)
				b.play_pop_animation()
				
		if is_large_match and particle_manager:
			particle_manager.emit_large_combo_explosion(center_pos, current_combo)
			
		# 3. Crack adjacent locked ice bubbles
		var cracked: Array[Vector2i] = SpecialBubbleHandler.process_adjacent_locked(bubble_grid, cleared_cells)
		if not cracked.is_empty():
			score += cracked.size() * Constants.POINTS_PER_LOCK_CRACK
			cleared_specials_count += cracked.size()
			
		# 4. Check for disconnected / floating bubbles
		var floating: Array[Vector2i] = FloatingDetector.find_floating_bubbles(bubble_grid)
		if not floating.is_empty():
			var drop_score: int = int(float(floating.size() * Constants.POINTS_PER_DROP) * combo_mult)
			score += drop_score
			AudioManager.play_drop()
			
			if screen_feedback:
				var drop_center: Vector2 = bubble_grid.grid_to_world_v(floating[0])
				screen_feedback.spawn_score_popup(drop_center + Vector2(0, 30), "DROP +%d" % drop_score, Color(0.3, 0.9, 0.85), 24)
				screen_feedback.add_trauma(0.25)
				
			for f_coord in floating:
				var fb: Bubble = bubble_grid.remove_bubble_v(f_coord)
				if is_instance_valid(fb):
					if fb.bubble_color != Enums.BubbleColor.NONE:
						cleared_color_counts[fb.bubble_color] = int(cleared_color_counts.get(fb.bubble_color, 0)) + 1
					if fb.special_type == Enums.SpecialType.STONE or fb.special_type == Enums.SpecialType.LOCKED:
						cleared_specials_count += 1
					var rand_vx: float = randf_range(-120.0, 120.0)
					fb.play_fall_animation(rand_vx, randf_range(-150.0, -80.0))
	else:
		# No match formed
		current_combo = 0
		
	ui_manager.update_score(score, SaveManager.get_high_score(current_level_id))
	ui_manager.update_combo(current_combo)
	
	# 5. Check Win / Lose / Objective completion
	_check_level_end_conditions()

## Evaluates board win / lose / objective state
func _check_level_end_conditions() -> void:
	var objective_met: bool = ObjectiveManager.is_objective_complete(
		current_level_data,
		bubble_grid,
		score,
		cleared_color_counts,
		cleared_specials_count
	)
	
	if objective_met:
		_trigger_win()
		return
		
	var lowest_row: int = bubble_grid.get_lowest_occupied_row()
	if lowest_row >= current_level_data.danger_row:
		_trigger_lose("Bubbles reached the danger line!")
		return
		
	if shots_remaining <= 0:
		_trigger_lose("Out of shots!")
		return
		
	# Level continues -> reload shooter
	game_state = Enums.GameState.PLAYING
	var active_colors: Array[int] = bubble_grid.get_active_colors()
	var new_next_col: int = color_generator.get_next_color(current_level_data.allowed_colors, active_colors)
	shooter.reload_next(new_next_col)

func _trigger_win() -> void:
	game_state = Enums.GameState.WIN
	shooter.can_shoot = false
	aim_guide.clear_trajectory()
	
	score += Constants.POINTS_OBJECTIVE_COMPLETE
	
	# Calculate stars earned (1-3 stars)
	var stars: int = 1
	if score >= current_level_data.target_score:
		stars = 2
	if score >= int(float(current_level_data.target_score) * 1.5):
		stars = 3
		
	AudioManager.play_win()
	if particle_manager:
		particle_manager.emit_victory_celebration()
	if companion_lumi:
		companion_lumi.set_state(CompanionLumi.LumiState.WIN)
		
	var is_new_high: bool = score > SaveManager.get_high_score(current_level_id)
	SaveManager.set_high_score(current_level_id, score)
	SaveManager.set_stars_earned(current_level_id, stars)
	SaveManager.unlock_level(current_level_id + 1)
	
	ui_manager.show_win(score, SaveManager.get_high_score(current_level_id), is_new_high, stars)
	game_won.emit(current_level_id, score, stars)

func _trigger_lose(reason: String) -> void:
	game_state = Enums.GameState.LOSE
	shooter.can_shoot = false
	aim_guide.clear_trajectory()
	
	AudioManager.play_lose()
	if companion_lumi:
		companion_lumi.set_state(CompanionLumi.LumiState.LOSE)
		
	ui_manager.show_lose(reason, score)
	game_lost.emit(current_level_id, reason)

## Touch / Mouse Input Event handling
func _unhandled_input(event: InputEvent) -> void:
	if game_state != Enums.GameState.PLAYING:
		return
		
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_touch_active = true
				last_touch_pos = mb.position
				_handle_aim_input(mb.position)
			else:
				if is_touch_active:
					is_touch_active = false
					_handle_fire_input()
					
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if is_touch_active:
			last_touch_pos = mm.position
			_handle_aim_input(mm.position)
			
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			is_touch_active = true
			last_touch_pos = st.position
			_handle_aim_input(st.position)
		else:
			if is_touch_active:
				is_touch_active = false
				_handle_fire_input()
				
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if is_touch_active:
			last_touch_pos = sd.position
			_handle_aim_input(sd.position)

func _handle_aim_input(target_pos: Vector2) -> void:
	if shooter.update_aim_target(target_pos):
		_calculate_and_draw_trajectory(shooter.aim_direction)
		if companion_lumi:
			companion_lumi.set_state(CompanionLumi.LumiState.AIMING)
			companion_lumi.update_aim_look(shooter.aim_direction)

func _handle_fire_input() -> void:
	if shooter.is_aiming and shooter.can_shoot:
		shooter.fire_bubble()

## Calculates predictive raycast trajectory with wall reflections
func _calculate_and_draw_trajectory(initial_dir: Vector2) -> void:
	var points: Array[Vector2] = [Constants.SHOOTER_POSITION]
	var ray_origin: Vector2 = Constants.SHOOTER_POSITION
	var ray_dir: Vector2 = initial_dir.normalized()
	
	var left_bound: float = Constants.LEFT_WALL_X + Constants.BUBBLE_RADIUS
	var right_bound: float = Constants.RIGHT_WALL_X - Constants.BUBBLE_RADIUS
	var ceiling_bound: float = Constants.GRID_START_Y + Constants.BUBBLE_RADIUS
	
	var predicted_snap_pos: Vector2 = Vector2.ZERO
	var predicted_snap_coord: Vector2i = Vector2i(-1, -1)
	
	var max_bounces: int = Constants.MAX_TRAJECTORY_BOUNCES
	var occupied_cells: Array[Vector2i] = bubble_grid.get_all_occupied_cells()
	var collision_thresh_sq: float = pow(Constants.BUBBLE_DIAMETER * Constants.COLLISION_RADIUS_FACTOR, 2.0)
	
	for bounce in range(max_bounces + 1):
		var t_min: float = INF
		var hit_type: int = 0
		var next_origin: Vector2 = Vector2.ZERO
		var next_dir: Vector2 = ray_dir
		
		# Wall collision time
		if ray_dir.x < -0.001:
			var t_left: float = (left_bound - ray_origin.x) / ray_dir.x
			if t_left > 0.001 and t_left < t_min:
				t_min = t_left
				hit_type = 1
				next_origin = Vector2(left_bound, ray_origin.y + ray_dir.y * t_left)
				next_dir = Vector2(-ray_dir.x, ray_dir.y)
		elif ray_dir.x > 0.001:
			var t_right: float = (right_bound - ray_origin.x) / ray_dir.x
			if t_right > 0.001 and t_right < t_min:
				t_min = t_right
				hit_type = 1
				next_origin = Vector2(right_bound, ray_origin.y + ray_dir.y * t_right)
				next_dir = Vector2(-ray_dir.x, ray_dir.y)
				
		# Ceiling collision time
		if ray_dir.y < -0.001:
			var t_ceil: float = (ceiling_bound - ray_origin.y) / ray_dir.y
			if t_ceil > 0.001 and t_ceil < t_min:
				t_min = t_ceil
				hit_type = 2
				next_origin = Vector2(ray_origin.x + ray_dir.x * t_ceil, ceiling_bound)
				
		# Occupied bubble raycast collision
		for coord in occupied_cells:
			var b: Bubble = bubble_grid.get_bubble_v(coord)
			if is_instance_valid(b):
				var d_pos: Vector2 = ray_origin - b.position
				var b_val: float = 2.0 * ray_dir.dot(d_pos)
				var c_val: float = d_pos.length_squared() - collision_thresh_sq
				var disc: float = b_val * b_val - 4.0 * c_val
				if disc >= 0.0:
					var t_cand: float = (-b_val - sqrt(disc)) / 2.0
					if t_cand > 0.001 and t_cand < t_min:
						t_min = t_cand
						hit_type = 3
						next_origin = ray_origin + ray_dir * t_cand
						
		if is_inf(t_min) or t_min <= 0.0:
			break
			
		var hit_pos: Vector2 = ray_origin + ray_dir * t_min
		points.append(hit_pos)
		
		if hit_type == 2 or hit_type == 3:
			predicted_snap_coord = bubble_grid.find_best_snap_cell(hit_pos)
			predicted_snap_pos = bubble_grid.grid_to_world_v(predicted_snap_coord)
			break
		elif hit_type == 1:
			ray_origin = next_origin
			ray_dir = next_dir
			
	aim_guide.guide_color = Constants.get_color_for_type(shooter.current_color)
	aim_guide.is_aiming = true
	aim_guide.set_trajectory(points, predicted_snap_pos, predicted_snap_coord)

func _on_shooter_bubble_fired(bubble: Bubble, direction: Vector2) -> void:
	game_state = Enums.GameState.SHOOTING
	aim_guide.clear_trajectory()
	
	active_projectile = bubble
	projectile_direction = direction.normalized()
	add_child(active_projectile)
	
	if particle_manager:
		particle_manager.emit_launch_sparkles(Constants.SHOOTER_POSITION, bubble.bubble_color)
		
	shots_remaining -= 1
	ui_manager.update_shots(shots_remaining)

func _on_shooter_aim_changed(direction: Vector2) -> void:
	if game_state == Enums.GameState.PLAYING:
		_calculate_and_draw_trajectory(direction)

func _on_shooter_aim_ended() -> void:
	aim_guide.clear_trajectory()

func _on_shooter_bubbles_swapped() -> void:
	aim_guide.guide_color = Constants.get_color_for_type(shooter.current_color)
	if shooter.is_aiming:
		_calculate_and_draw_trajectory(shooter.aim_direction)

func _on_pause_toggled(paused: bool) -> void:
	if paused:
		game_state = Enums.GameState.PAUSED
		aim_guide.clear_trajectory()
	else:
		game_state = Enums.GameState.PLAYING

func restart_level() -> void:
	level_restarted.emit()
	load_level(current_level_id)

func load_next_level() -> void:
	next_level_requested.emit()
	var nxt: int = LevelManager.get_next_level_id(current_level_id)
	load_level(nxt)

func return_to_map() -> void:
	return_to_map_requested.emit()

func _update_debug_stats() -> void:
	if debug_overlay:
		debug_overlay.debug_state_text = _get_state_string(game_state)
		debug_overlay.debug_bubble_count = bubble_grid.get_occupied_count()
		debug_overlay.debug_aim_angle = shooter.launcher_rotation if shooter else 0.0
		debug_overlay.debug_shots = shots_remaining
		debug_overlay.debug_combo = current_combo
		debug_overlay.debug_level_id = current_level_id

func _get_state_string(st: int) -> String:
	match st:
		Enums.GameState.MENU: return "MENU"
		Enums.GameState.WORLD_MAP: return "WORLD_MAP"
		Enums.GameState.PLAYING: return "PLAYING"
		Enums.GameState.AIMING: return "AIMING"
		Enums.GameState.SHOOTING: return "SHOOTING"
		Enums.GameState.RESOLVING: return "RESOLVING"
		Enums.GameState.WIN: return "WIN"
		Enums.GameState.LOSE: return "LOSE"
		Enums.GameState.PAUSED: return "PAUSED"
		Enums.GameState.SETTINGS: return "SETTINGS"
		_: return "UNKNOWN"
