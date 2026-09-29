class_name Shooter
extends Node2D

signal bubble_fired(bubble: Bubble, direction: Vector2)
signal aim_changed(direction: Vector2)
signal aim_ended()
signal bubbles_swapped()

@export var bubble_scene: PackedScene

var current_bubble: Bubble = null
var next_bubble: Bubble = null

var current_color: int = Enums.BubbleColor.RED
var next_color: int = Enums.BubbleColor.BLUE

var aim_direction: Vector2 = Vector2.UP
var is_aiming: bool = false
var can_shoot: bool = true

## Pointer visual rotation
var launcher_rotation: float = -PI / 2.0
var _recoil_offset: Vector2 = Vector2.ZERO
var _crystal_pulse: float = 0.0

func _ready() -> void:
	if bubble_scene == null:
		bubble_scene = load("res://scenes/bubble/Bubble.tscn")
	position = Constants.SHOOTER_POSITION

func _process(delta: float) -> void:
	_crystal_pulse += delta * 3.0
	queue_redraw()

## Initialize loaded bubbles
func setup_initial_bubbles(cur_col: int, nxt_col: int) -> void:
	current_color = cur_col
	next_color = nxt_col
	_spawn_current_bubble()
	_spawn_next_bubble()

func _spawn_current_bubble() -> void:
	if is_instance_valid(current_bubble):
		current_bubble.queue_free()
	current_bubble = bubble_scene.instantiate() as Bubble
	current_bubble.set_bubble_type(current_color)
	current_bubble.position = Vector2.ZERO
	current_bubble.state = Enums.BubbleState.READY
	add_child(current_bubble)

func _spawn_next_bubble() -> void:
	if is_instance_valid(next_bubble):
		next_bubble.queue_free()
	next_bubble = bubble_scene.instantiate() as Bubble
	next_bubble.set_bubble_type(next_color)
	# Next bubble position relative to shooter
	next_bubble.position = Constants.NEXT_BUBBLE_POSITION - Constants.SHOOTER_POSITION
	next_bubble.scale = Vector2(0.8, 0.8)
	next_bubble.state = Enums.BubbleState.READY
	add_child(next_bubble)

## Smoothly swaps current and next bubbles with animated tweens
func swap_bubbles() -> void:
	if not can_shoot or not is_instance_valid(current_bubble) or not is_instance_valid(next_bubble):
		return
		
	var temp: int = current_color
	current_color = next_color
	next_color = temp
	
	AudioManager.play_ui_click()
	
	var next_rel_pos: Vector2 = Constants.NEXT_BUBBLE_POSITION - Constants.SHOOTER_POSITION
	
	# Animate swap crossover
	var tween: Tween = create_tween()
	tween.tween_property(current_bubble, "position", next_rel_pos, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(current_bubble, "scale", Vector2(0.8, 0.8), 0.14)
	
	tween.parallel().tween_property(next_bubble, "position", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(next_bubble, "scale", Vector2.ONE, 0.14)
	
	tween.tween_callback(func():
		var temp_b: Bubble = current_bubble
		current_bubble = next_bubble
		next_bubble = temp_b
		bubbles_swapped.emit()
	)

## Set aim angle from touch/pointer world position
func update_aim_target(target_world_pos: Vector2) -> bool:
	if not can_shoot:
		return false
		
	var diff: Vector2 = target_world_pos - global_position
	if diff.length_squared() < 400.0:
		return false
		
	var angle_rad: float = diff.angle()
	
	var min_rad: float = deg_to_rad(-180.0 + Constants.MIN_AIM_ANGLE_DEG) # -165 deg
	var max_rad: float = deg_to_rad(-Constants.MIN_AIM_ANGLE_DEG)        # -15 deg
	
	if angle_rad > 0.0:
		if diff.x < 0:
			angle_rad = min_rad
		else:
			angle_rad = max_rad
	else:
		angle_rad = clampf(angle_rad, min_rad, max_rad)
		
	launcher_rotation = angle_rad
	aim_direction = Vector2.from_angle(angle_rad)
	is_aiming = true
	queue_redraw()
	aim_changed.emit(aim_direction)
	return true

func cancel_aim() -> void:
	is_aiming = false
	queue_redraw()
	aim_ended.emit()

## Fire current bubble with recoil animation
func fire_bubble() -> Bubble:
	if not can_shoot or current_bubble == null:
		return null
		
	can_shoot = false
	is_aiming = false
	
	# Recoil kickback tween
	if not SaveManager.reduced_effects:
		var recoil_dir: Vector2 = -aim_direction * 12.0
		var tween: Tween = create_tween()
		tween.tween_property(self, "_recoil_offset", recoil_dir, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "_recoil_offset", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	AudioManager.play_shoot()
	
	var fired: Bubble = current_bubble
	remove_child(fired)
	fired.global_position = global_position
	fired.state = Enums.BubbleState.IN_FLIGHT
	current_bubble = null
	
	bubble_fired.emit(fired, aim_direction)
	return fired

## Reload with next bubble and newly generated bubble
func reload_next(new_next_color: int) -> void:
	current_color = next_color
	next_color = new_next_color
	
	_spawn_current_bubble()
	_spawn_next_bubble()
	
	# Smooth entrance scale bounce
	if is_instance_valid(current_bubble):
		current_bubble.scale = Vector2(0.5, 0.5)
		var tween: Tween = create_tween()
		tween.tween_property(current_bubble, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	can_shoot = true

func _draw() -> void:
	var wood_base: Color = Color(0.18, 0.12, 0.08, 0.95)
	var wood_rim: Color = Color(0.38, 0.26, 0.16, 0.95)
	var gold_trim: Color = Color(0.92, 0.76, 0.25, 0.9)
	var crystal_cyan: Color = Color(0.2, 0.88, 0.85, 0.9)
	
	# 1. Launcher Carved Wood Pedestal
	draw_circle(_recoil_offset, Constants.BUBBLE_RADIUS + 12.0, wood_base)
	draw_arc(_recoil_offset, Constants.BUBBLE_RADIUS + 12.0, 0.0, TAU, 32, wood_rim, 3.0, true)
	draw_arc(_recoil_offset, Constants.BUBBLE_RADIUS + 8.0, 0.0, TAU, 32, gold_trim, 1.5, true)
	
	# 2. Side Floating Power Crystals
	var c_glow: float = (sin(_crystal_pulse) * 0.25 + 0.75)
	var left_crystal_pos: Vector2 = _recoil_offset + Vector2(-Constants.BUBBLE_RADIUS - 16.0, 0)
	var right_crystal_pos: Vector2 = _recoil_offset + Vector2(Constants.BUBBLE_RADIUS + 16.0, 0)
	
	# Left Crystal
	draw_circle(left_crystal_pos, 7.0 * c_glow, Color(crystal_cyan.r, crystal_cyan.g, crystal_cyan.b, 0.4))
	draw_circle(left_crystal_pos, 4.5, crystal_cyan)
	# Right Crystal
	draw_circle(right_crystal_pos, 7.0 * c_glow, Color(crystal_cyan.r, crystal_cyan.g, crystal_cyan.b, 0.4))
	draw_circle(right_crystal_pos, 4.5, crystal_cyan)
	
	# 3. Rotating Aim Pointer Barrel / Direction Arrow
	if is_aiming:
		var pointer_len: float = 62.0
		var pointer_end: Vector2 = _recoil_offset + Vector2.from_angle(launcher_rotation) * pointer_len
		draw_line(_recoil_offset, pointer_end, Color(1.0, 1.0, 1.0, 0.85), 4.5, true)
		draw_circle(pointer_end, 5.5, gold_trim)
		
	# 4. Next Bubble Carved Stone Holder
	var next_rel_pos: Vector2 = Constants.NEXT_BUBBLE_POSITION - Constants.SHOOTER_POSITION
	draw_circle(next_rel_pos, Constants.BUBBLE_RADIUS * 0.95, Color(0.12, 0.09, 0.06, 0.8))
	draw_arc(next_rel_pos, Constants.BUBBLE_RADIUS * 0.95, 0.0, TAU, 24, wood_rim, 2.0, true)
	draw_arc(next_rel_pos, Constants.BUBBLE_RADIUS * 0.85, 0.0, TAU, 24, gold_trim, 1.2, true)
