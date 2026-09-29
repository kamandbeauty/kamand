class_name AimGuide
extends Node2D

@export var is_aiming: bool = false:
	set(value):
		is_aiming = value
		queue_redraw()

var trajectory_points: Array[Vector2] = []
var predicted_snap_pos: Vector2 = Vector2.ZERO
var predicted_snap_coord: Vector2i = Vector2i(-1, -1)
var has_predicted_snap: bool = false
var guide_color: Color = Color(1.0, 1.0, 1.0, 0.7)

var _pulse_time: float = 0.0

func _process(delta: float) -> void:
	if is_aiming:
		_pulse_time += delta
		queue_redraw()

func set_trajectory(points: Array[Vector2], snap_pos: Vector2, snap_coord: Vector2i) -> void:
	trajectory_points = points
	predicted_snap_pos = snap_pos
	predicted_snap_coord = snap_coord
	has_predicted_snap = snap_coord.x >= 0
	queue_redraw()

func clear_trajectory() -> void:
	trajectory_points.clear()
	has_predicted_snap = false
	is_aiming = false
	queue_redraw()

func _draw() -> void:
	if not is_aiming or trajectory_points.size() < 2:
		return
		
	var dot_spacing: float = 20.0
	var dot_radius: float = 4.5
	var pulse_glow: float = sin(_pulse_time * 6.0) * 0.15 + 0.85
	
	for i in range(trajectory_points.size() - 1):
		var p1: Vector2 = trajectory_points[i]
		var p2: Vector2 = trajectory_points[i + 1]
		var seg_vec: Vector2 = p2 - p1
		var seg_len: float = seg_vec.length()
		if seg_len <= 0.001:
			continue
		var seg_dir: Vector2 = seg_vec / seg_len
		
		var dist: float = 0.0
		while dist < seg_len:
			var dot_pos: Vector2 = p1 + seg_dir * dist
			var alpha_factor: float = clampf(1.0 - (dot_pos.y / Constants.SCREEN_HEIGHT) * 0.25, 0.45, 0.95) * pulse_glow
			
			# Outer soft glow halo
			draw_circle(dot_pos, dot_radius * 1.8, Color(guide_color.r, guide_color.g, guide_color.b, alpha_factor * 0.35))
			# Sharp inner core
			draw_circle(dot_pos, dot_radius, Color(1.0, 1.0, 1.0, alpha_factor * 0.9))
			dist += dot_spacing
			
		# Draw bright bounce rings at reflection vertices
		if i > 0:
			draw_circle(p1, 7.0, Color(1.0, 1.0, 1.0, 0.9))
			draw_arc(p1, 10.0, 0.0, TAU, 16, Color(guide_color.r, guide_color.g, guide_color.b, 0.8), 2.0, true)
			
	# Draw pulsating predicted snap ghost indicator
	if has_predicted_snap:
		var ghost_pulse: float = sin(_pulse_time * 8.0) * 0.15 + 0.85
		var ghost_radius: float = Constants.BUBBLE_RADIUS * ghost_pulse
		
		# Outer target ring
		draw_arc(predicted_snap_pos, ghost_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 2.5, true)
		draw_arc(predicted_snap_pos, ghost_radius + 4.0, 0.0, TAU, 32, Color(guide_color.r, guide_color.g, guide_color.b, 0.4), 1.5, true)
		# Inner soft center
		draw_circle(predicted_snap_pos, Constants.BUBBLE_RADIUS * 0.35, Color(guide_color.r, guide_color.g, guide_color.b, 0.4))
