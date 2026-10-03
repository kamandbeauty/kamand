class_name ParticleManager
extends Node2D

## ==============================================================================
## LUMI PARTICLE & SHATTER MANAGER (Studio Javid Engine)
## High-Impact Glass Fractures, Expanding Shockwaves & Elemental Bursts
## ==============================================================================

var active_effects: Array[Node2D] = []

func _ready() -> void:
	pass

## Spawns launch sparkles at shooter muzzle
func emit_launch_sparkles(pos: Vector2, color_type: int) -> void:
	if SaveManager.reduced_effects:
		return
	var c: Color = Constants.get_color_for_type(color_type)
	var p: CPUParticles2D = _create_burst_particles(pos, c, 14, 200.0, 0.25, 3.2)
	add_child(p)

## Spawns glass spark burst upon wall bounce
func emit_bounce_sparks(pos: Vector2) -> void:
	if SaveManager.reduced_effects:
		return
	var p: CPUParticles2D = _create_burst_particles(pos, GlassDesignSystem.COLOR_AQUA, 12, 240.0, 0.22, 2.8)
	add_child(p)

## Spawns color-matched pop burst with 3D faceted glass crystal shards & specular glints
func emit_pop_burst(pos: Vector2, color_type: int, is_large: bool = false) -> void:
	if SaveManager.reduced_effects:
		return
	var count: int = 30 if is_large else 18
	var speed: float = 380.0 if is_large else 260.0
	var c: Color = Constants.get_color_for_type(color_type)
	
	# Primary colored glass shards
	var p1: CPUParticles2D = _create_burst_particles(pos, c, count, speed, 0.45, 4.5)
	add_child(p1)
	
	# Specular bright white glints
	var p2: CPUParticles2D = _create_burst_particles(pos, Color.WHITE, count / 2, speed * 0.75, 0.30, 3.0)
	add_child(p2)

## Spawns explosive radial burst for Bomb bubble detonations
func emit_bomb_burst(pos: Vector2) -> void:
	if SaveManager.reduced_effects:
		return
	# Fiery orange and crimson embers
	var p1: CPUParticles2D = _create_burst_particles(pos, Color(1.0, 0.35, 0.1), 36, 450.0, 0.6, 6.0)
	var p2: CPUParticles2D = _create_burst_particles(pos, Color(1.0, 0.85, 0.2), 24, 380.0, 0.45, 4.5)
	var p3: CPUParticles2D = _create_burst_particles(pos, Color(0.15, 0.15, 0.2), 16, 280.0, 0.5, 5.0)
	add_child(p1)
	add_child(p2)
	add_child(p3)

## Spawns energetic electric plasma burst for Lightning clears
func emit_lightning_burst(pos: Vector2) -> void:
	if SaveManager.reduced_effects:
		return
	var p1: CPUParticles2D = _create_burst_particles(pos, GlassDesignSystem.COLOR_AQUA, 24, 420.0, 0.35, 4.0)
	var p2: CPUParticles2D = _create_burst_particles(pos, Color.WHITE, 16, 500.0, 0.25, 3.0)
	add_child(p1)
	add_child(p2)

## Spawns radiant explosion on large combo clears (5+ bubbles)
func emit_large_combo_explosion(pos: Vector2, combo: int) -> void:
	if SaveManager.reduced_effects:
		return
	var colors: Array[Color] = [
		GlassDesignSystem.COLOR_SUNSHINE,
		GlassDesignSystem.COLOR_AQUA,
		GlassDesignSystem.COLOR_PINK
	]
	for c in colors:
		var p: CPUParticles2D = _create_burst_particles(pos, c, 22, 420.0, 0.50, 5.0)
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
		var p: CPUParticles2D = _create_burst_particles(orig, GlassDesignSystem.COLOR_SUNSHINE, 40, 480.0, 0.75, 6.5)
		add_child(p)

## Cleans up all active temporary particle nodes
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
	p.gravity = Vector2(0, 520.0)
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.color = color
	p.scale_amount_min = scale_size * 0.7
	p.scale_amount_max = scale_size * 1.3
	
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
	return p
