class_name CompanionLumi
extends Node2D

## ==============================================================================
## LUMI COMPANION CHARACTER (Section 36, 37, 38)
## Cute Fantasy Crystal Companion with layered shading, rim lights & eye gloss
## ==============================================================================

enum LumiState {
	IDLE,
	AIMING,
	MATCH_SUCCESS,
	LARGE_COMBO,
	WIN,
	LOSE
}

var current_state: LumiState = LumiState.IDLE

var _anim_time: float = 0.0
var _bounce_offset_y: float = 0.0
var _ear_wiggle: float = 0.0
var _tail_angle: float = 0.0
var _eye_blink: float = 1.0 # 1.0 = open, 0.0 = closed
var _aim_look_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	position = Constants.LUMI_POSITION

func _process(delta: float) -> void:
	_anim_time += delta
	
	match current_state:
		LumiState.IDLE:
			_bounce_offset_y = sin(_anim_time * 2.5) * 3.5
			_tail_angle = sin(_anim_time * 3.0) * 0.25
			_ear_wiggle = sin(_anim_time * 1.5) * 0.08
			_aim_look_offset = Vector2.ZERO
			
			# Periodic blinking
			var blink_cycle: float = fmod(_anim_time, 4.0)
			_eye_blink = 0.1 if (blink_cycle > 3.8 && blink_cycle < 3.95) else 1.0
			
		LumiState.AIMING:
			_bounce_offset_y = sin(_anim_time * 4.0) * 1.5
			_tail_angle = sin(_anim_time * 5.0) * 0.15
			_ear_wiggle = 0.18 # Attentive perked ears
			_eye_blink = 1.0
			
		LumiState.MATCH_SUCCESS:
			_bounce_offset_y = -abs(sin(_anim_time * 8.0)) * 14.0
			_tail_angle = sin(_anim_time * 10.0) * 0.4
			_ear_wiggle = sin(_anim_time * 8.0) * 0.2
			_eye_blink = 1.0
			
		LumiState.LARGE_COMBO:
			_bounce_offset_y = -abs(sin(_anim_time * 10.0)) * 22.0
			_tail_angle = sin(_anim_time * 14.0) * 0.5
			_ear_wiggle = sin(_anim_time * 12.0) * 0.3
			_eye_blink = 1.0
			
		LumiState.WIN:
			_bounce_offset_y = -abs(sin(_anim_time * 6.0)) * 18.0
			_tail_angle = sin(_anim_time * 8.0) * 0.45
			_ear_wiggle = 0.2
			_eye_blink = 1.0
			
		LumiState.LOSE:
			_bounce_offset_y = 5.0
			_ear_wiggle = -0.32 # Comforting droop
			_tail_angle = 0.05
			_eye_blink = 0.6
			
	queue_redraw()

func set_state(state: LumiState) -> void:
	current_state = state
	_anim_time = 0.0
	
	if state == LumiState.MATCH_SUCCESS:
		get_tree().create_timer(1.2).timeout.connect(func():
			if current_state == LumiState.MATCH_SUCCESS:
				current_state = LumiState.IDLE
		)
	elif state == LumiState.LARGE_COMBO:
		get_tree().create_timer(1.8).timeout.connect(func():
			if current_state == LumiState.LARGE_COMBO:
				current_state = LumiState.IDLE
		)

func update_aim_look(aim_dir: Vector2) -> void:
	if current_state == LumiState.AIMING:
		_aim_look_offset = aim_dir.normalized() * 5.0

func _draw() -> void:
	var base_fur: Color = Color(0.98, 0.58, 0.25)    # Warm Sunset Gold
	var shade_fur: Color = Color(0.82, 0.38, 0.12)   # Deep Fur Shade
	var cream_fur: Color = Color(1.0, 0.96, 0.90)    # Soft Cream
	var dark_fur: Color = Color(0.24, 0.14, 0.10)    # Tips & Paws
	var crystal_gem: Color = GlassDesignSystem.COLOR_AQUA
	
	var center: Vector2 = Vector2(0, _bounce_offset_y)
	
	# Ambient ground shadow (Section 17)
	draw_circle(Vector2(0, 36.0), 22.0, Color(0, 0, 0.05, 0.25))
	
	# 1. Bushy Fluffy Tail with White Tip & Specular Rim
	var tail_root: Vector2 = center + Vector2(24.0, 12.0)
	var tail_mid: Vector2 = tail_root + Vector2(28.0, -18.0).rotated(_tail_angle)
	var tail_tip: Vector2 = tail_root + Vector2(40.0, -32.0).rotated(_tail_angle)
	draw_circle(tail_mid + Vector2(2, 2), 18.0, shade_fur)
	draw_circle(tail_mid, 18.0, base_fur)
	draw_circle(tail_tip, 12.0, cream_fur)
	
	# 2. Main Body & Cream Belly
	draw_circle(center + Vector2(2, 12.0), 26.0, shade_fur)
	draw_circle(center + Vector2(0, 10.0), 26.0, base_fur)
	draw_circle(center + Vector2(-4.0, 12.0), 16.0, cream_fur)
	
	# 3. Head & Cheeks
	var head_pos: Vector2 = center + Vector2(0, -16.0)
	draw_circle(head_pos + Vector2(1, 1), 22.0, shade_fur)
	draw_circle(head_pos, 22.0, base_fur)
	draw_circle(head_pos + Vector2(-12.0, 6.0), 11.0, cream_fur)
	draw_circle(head_pos + Vector2(12.0, 6.0), 11.0, cream_fur)
	
	# 4. Large Expressive Ears
	# Left Ear
	var left_ear_base: Vector2 = head_pos + Vector2(-14.0, -14.0)
	var left_ear_pts: PackedVector2Array = [
		left_ear_base,
		left_ear_base + Vector2(-8.0, -26.0).rotated(-_ear_wiggle),
		left_ear_base + Vector2(8.0, -18.0).rotated(-_ear_wiggle)
	]
	draw_colored_polygon(left_ear_pts, base_fur)
	draw_circle(left_ear_base + Vector2(-4.0, -16.0).rotated(-_ear_wiggle), 6.0, Color(1.0, 0.65, 0.70))
	
	# Right Ear
	var right_ear_base: Vector2 = head_pos + Vector2(14.0, -14.0)
	var right_ear_pts: PackedVector2Array = [
		right_ear_base,
		right_ear_base + Vector2(8.0, -26.0).rotated(_ear_wiggle),
		right_ear_base + Vector2(-8.0, -18.0).rotated(_ear_wiggle)
	]
	draw_colored_polygon(right_ear_pts, base_fur)
	draw_circle(right_ear_base + Vector2(4.0, -16.0).rotated(_ear_wiggle), 6.0, Color(1.0, 0.65, 0.70))
	
	# 5. Glossy Eyes with Upper-Left Specular Reflections (Section 36, 41)
	var left_eye_pos: Vector2 = head_pos + Vector2(-8.0, -2.0) + _aim_look_offset
	var right_eye_pos: Vector2 = head_pos + Vector2(8.0, -2.0) + _aim_look_offset
	
	if _eye_blink > 0.3:
		# Large glassy pupils
		draw_circle(left_eye_pos, 5.5 * _eye_blink, dark_fur)
		draw_circle(right_eye_pos, 5.5 * _eye_blink, dark_fur)
		# Upper-Left Primary Specular Highlights
		draw_circle(left_eye_pos + Vector2(-2.0, -2.0), 2.2 * _eye_blink, Color(1.0, 1.0, 1.0, 0.95))
		draw_circle(right_eye_pos + Vector2(-2.0, -2.0), 2.2 * _eye_blink, Color(1.0, 1.0, 1.0, 0.95))
		# Secondary bottom reflection
		draw_circle(left_eye_pos + Vector2(1.5, 1.5), 1.0 * _eye_blink, Color(1.0, 1.0, 1.0, 0.7))
		draw_circle(right_eye_pos + Vector2(1.5, 1.5), 1.0 * _eye_blink, Color(1.0, 1.0, 1.0, 0.7))
	else:
		# Happy curved blinking lines
		draw_arc(left_eye_pos, 4.0, PI, TAU, 16, dark_fur, 2.0, true)
		draw_arc(right_eye_pos, 4.0, PI, TAU, 16, dark_fur, 2.0, true)
		
	# 6. Cute Nose & Mouth
	draw_circle(head_pos + Vector2(0, 4.0), 2.5, dark_fur)
	if current_state == LumiState.WIN or current_state == LumiState.MATCH_SUCCESS or current_state == LumiState.LARGE_COMBO:
		draw_arc(head_pos + Vector2(0, 6.0), 4.5, 0.0, PI, 16, dark_fur, 2.0, true)
	else:
		draw_arc(head_pos + Vector2(-3.0, 7.0), 2.5, 0.0, PI, 12, dark_fur, 1.5, true)
		draw_arc(head_pos + Vector2(3.0, 7.0), 2.5, 0.0, PI, 12, dark_fur, 1.5, true)
		
	# 7. Radiant Crystal Heart Pendant
	var pendant_pos: Vector2 = center + Vector2(0, 14.0)
	var glow_pulse: float = sin(_anim_time * 4.0) * 0.25 + 0.75
	draw_circle(pendant_pos, 7.0, Color(crystal_gem.r, crystal_gem.g, crystal_gem.b, 0.4 * glow_pulse))
	draw_circle(pendant_pos, 4.5, crystal_gem)
	draw_circle(pendant_pos + Vector2(-1.5, -1.5), 1.8, Color(1.0, 1.0, 1.0, 0.9))
