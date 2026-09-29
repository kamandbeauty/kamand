class_name ParticleManager
extends Node2D

## Visual particle burst effect container for Phase 2
var active_effects: Array[Node2D] = []

func _ready() -> void:
	pass

## Spawns launch sparkles at shooter muzzle
func emit_launch_sparkles(pos: Vector2, color_type: int) -> void:
	if SaveManager.reduced_effects:
		return
	var c: Color = Constants.get_color_for_type(color_type)
	var p: CPUParticles2D = _create_burst_particles(pos, c, 12, 180.0, 0.25, 3.0)
	add_child(p)

## Spawns spark burst upon wall bounce
func emit_bounce_sparks(pos: Vector2) -> void:
	if SaveManager.reduced_effects:
		return
	var p: CPUParticles2D = _create_burst_particles(pos, Color(1.0, 0.95, 0.7), 10, 220.0, 0.2, 2.5)
	add_child(p)

## Spawns subtle snap ring when bubble locks into grid
func emit_snap_burst(pos: Vector2, color_type: int) -> void:
	if SaveManager.reduced_effects:
		return
	var c: Color = Constants.get_color_for_type(color_type).lightened(0.3)
	var p: CPUParticles2D = _create_burst_particles(pos, c, 8, 120.0, 0.18, 2.0)
	add_child(p)

## Spawns color-matched pop burst with crystal shards
func emit_pop_burst(pos: Vector2, color_type: int, is_large: bool = false) -> void:
	if SaveManager.reduced_effects:
		return
	var count: int = 24 if is_large else 14
	var speed: float = 340.0 if is_large else 240.0
	var c: Color = Constants.get_color_for_type(color_type)
	
	# Primary color shards
	var p1: CPUParticles2D = _create_burst_particles(pos, c, count, speed, 0.35, 4.0)
	add_child(p1)
	
	# Specular bright glints
	var p2: CPUParticles2D = _create_burst_particles(pos, Color.WHITE, count / 2, speed * 0.7, 0.25, 2.5)
	add_child(p2)

## Spawns radiant explosion on large combo clears (5+ bubbles)
func emit_large_combo_explosion(pos: Vector2, combo: int) -> void:
	if SaveManager.reduced_effects:
		return
	var colors: Array[Color] = [
		Color(1.0, 0.85, 0.2), # Gold
		Color(0.3, 0.85, 1.0), # Cyan
		Color(1.0, 0.3, 0.8)  # Magenta
	]
	for c in colors:
		var p: CPUParticles2D = _create_burst_particles(pos, c, 18, 400.0, 0.45, 5.0)
		add_child(p)

## Spawns celebratory golden fireworks for 3-star victory
func emit_victory_celebration() -> void:
	if SaveManager.reduced_effects:
		return
	var origins: Array[Vector2] = [
		Vector2(200.0, 350.0),
		Vector2(520.0, 350.0),
		Vector2(360.0, 250.0)
	]
	for orig in origins:
		var p: CPUParticles2D = _create_burst_particles(orig, Color(1.0, 0.88, 0.25), 35, 450.0, 0.7, 6.0)
		add_child(p)

## Cleans up all active temporary particle nodes (e.g. on restart)
func clear_all_effects() -> void:
	for child in get_children():
		if child is CPUParticles2D:
			child.queue_free()

## Helper to create configured CPUParticles2D node
func _create_burst_particles(pos: Vector2, color: Color, amount: int, speed: float, lifetime: float, scale_size: float) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2(0, 500.0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.color = color
	p.scale_amount_min = scale_size * 0.7
	p.scale_amount_max = scale_size * 1.3
	
	# Auto clean-up after lifetime
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
	return p
