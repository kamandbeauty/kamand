class_name ForestBackground
extends Node2D

## ==============================================================================
## LUMI 6-LAYER CRYSTAL FANTASY BACKGROUND (Section 4, 5, 49)
## Multi-world responsive background with floating glass particles & ambient glows
## ==============================================================================

@export var current_world: int = 1:
	set(v):
		current_world = v
		queue_redraw()

var _fireflies: Array[Dictionary] = []
var _glass_orbs: Array[Dictionary] = []
const FIREFLY_COUNT: int = 24
const GLASS_ORB_COUNT: int = 6

var _time: float = 0.0

func _ready() -> void:
	_init_particles()

func _init_particles() -> void:
	_fireflies.clear()
	for i in range(FIREFLY_COUNT):
		_fireflies.append({
			"base_pos": Vector2(randf_range(30.0, 690.0), randf_range(100.0, 1240.0)),
			"speed": randf_range(18.0, 42.0),
			"radius": randf_range(1.5, 3.5),
			"phase": randf_range(0.0, TAU),
			"pulse_speed": randf_range(1.8, 3.8),
			"color": Color(0.98, 0.90, 0.45) if (i % 2 == 0) else Color(0.35, 0.95, 0.90)
		})
		
	_glass_orbs.clear()
	for i in range(GLASS_ORB_COUNT):
		_glass_orbs.append({
			"pos": Vector2(randf_range(50.0, 670.0), randf_range(150.0, 1100.0)),
			"radius": randf_range(60.0, 140.0),
			"speed": randf_range(6.0, 14.0),
			"phase": randf_range(0.0, TAU)
		})

func _process(delta: float) -> void:
	_time += delta
	if not SaveManager.reduced_effects:
		for f in _fireflies:
			f["phase"] += delta * f["pulse_speed"]
			f["base_pos"].y -= delta * f["speed"] * 0.5
			if f["base_pos"].y < 80.0:
				f["base_pos"].y = 1260.0
				f["base_pos"].x = randf_range(30.0, 690.0)
				
		for orb in _glass_orbs:
			orb["phase"] += delta * 0.4
		queue_redraw()

func _draw() -> void:
	var theme: Dictionary = GlassDesignSystem.WORLD_THEMES.get(current_world, GlassDesignSystem.WORLD_THEMES[1])
	var bg_top: Color = theme["bg_top"]
	var bg_mid: Color = theme["bg_mid"]
	var bg_bottom: Color = theme["bg_bottom"]
	var glow_color: Color = theme["glow_color"]
	
	# Layer 1: Dark Fantasy Base & Gradient (Section 4, 5)
	draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), bg_bottom)
	draw_circle(Vector2(360.0, 180.0), 480.0, Color(bg_mid.r, bg_mid.g, bg_mid.b, 0.55))
	draw_circle(Vector2(360.0, -60.0), 380.0, Color(bg_top.r, bg_top.g, bg_top.b, 0.85))
	
	# Layer 2: Soft Atmospheric Ambient Glow Orbs
	if not SaveManager.reduced_effects:
		for orb in _glass_orbs:
			var sway: Vector2 = Vector2(sin(orb["phase"]) * 18.0, cos(orb["phase"] * 0.8) * 12.0)
			draw_circle(orb["pos"] + sway, orb["radius"], Color(glow_color.r, glow_color.g, glow_color.b, 0.08))
			draw_arc(orb["pos"] + sway, orb["radius"], 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.04), 1.5, true)
	
	# Layer 3: Playfield Glass Backing (576px wide centered board)
	var left: float = Constants.LEFT_WALL_X
	var right: float = Constants.RIGHT_WALL_X
	var top: float = Constants.GRID_START_Y
	var bottom: float = Constants.SCREEN_HEIGHT
	
	# Semi-transparent crystal board backing with soft dark tint
	draw_rect(Rect2(left, top, right - left, bottom - top), Color(0.06, 0.08, 0.18, 0.75))
	
	# Layer 4: Floating Glass & Star Dust Particles
	if not SaveManager.reduced_effects:
		for f in _fireflies:
			var sway_x: float = sin(f["phase"]) * 12.0
			var sway_y: float = cos(f["phase"] * 0.7) * 6.0
			var p: Vector2 = f["base_pos"] + Vector2(sway_x, sway_y)
			var alpha: float = (sin(f["phase"]) * 0.5 + 0.5) * 0.80 + 0.20
			var c: Color = f["color"]
			draw_circle(p, f["radius"] * 3.0, Color(c.r, c.g, c.b, alpha * 0.25))
			draw_circle(p, f["radius"], Color(c.r, c.g, c.b, alpha * 0.9))
			
	# Layer 5: Crystal Glass Border Pillars & Ceiling
	_draw_crystal_pillars(left, right, top, bottom, theme["accent"])
	
	# Ancient Crystal Ceiling Line
	draw_rect(Rect2(left - 8.0, top - 10.0, (right - left) + 16.0, 12.0), Color(0.10, 0.14, 0.28, 0.95))
	draw_line(Vector2(left, top), Vector2(right, top), Color(1.0, 1.0, 1.0, 0.75), 2.0)
	draw_line(Vector2(left, top + 1), Vector2(right, top + 1), theme["accent"], 1.5)
	
	# Layer 6: Danger Row Line with Subtle Warning Pulse
	var danger_y: float = top + Constants.BUBBLE_RADIUS + float(Constants.DEFAULT_DANGER_ROW) * Constants.ROW_SPACING
	var danger_alpha: float = (sin(_time * 4.0) * 0.25 + 0.55) if not SaveManager.reduced_effects else 0.45
	draw_line(Vector2(left + 6.0, danger_y), Vector2(right - 6.0, danger_y), Color(1.0, 0.35, 0.40, danger_alpha), 2.0)

func _draw_crystal_pillars(left: float, right: float, top: float, bottom: float, accent: Color) -> void:
	var pillar_glass: Color = Color(0.08, 0.12, 0.26, 0.85)
	var border_glint: Color = Color(1.0, 1.0, 1.0, 0.40)
	
	# Left Crystal Pillar
	draw_rect(Rect2(left - 12.0, top, 12.0, bottom - top), pillar_glass)
	draw_line(Vector2(left, top), Vector2(left, bottom), border_glint, 2.0)
	draw_line(Vector2(left - 12.0, top), Vector2(left - 12.0, bottom), Color(1.0, 1.0, 1.0, 0.15), 1.0)
	
	# Right Crystal Pillar
	draw_rect(Rect2(right, top, 12.0, bottom - top), pillar_glass)
	draw_line(Vector2(right, top), Vector2(right, bottom), border_glint, 2.0)
	draw_line(Vector2(right + 12.0, top), Vector2(right + 12.0, bottom), Color(1.0, 1.0, 1.0, 0.15), 1.0)
	
	# Glowing Crystal Facet Nodes
	for y_step in range(int(top) + 80, int(bottom) - 100, 160):
		var pulse: float = sin(_time * 2.5 + float(y_step) * 0.015) * 0.3 + 0.7
		var col: Color = Color(accent.r, accent.g, accent.b, pulse * 0.75)
		draw_circle(Vector2(left - 6.0, float(y_step)), 4.0, col)
		draw_circle(Vector2(left - 7.0, float(y_step) - 1.0), 1.5, Color(1.0, 1.0, 1.0, 0.9))
		
		draw_circle(Vector2(right + 6.0, float(y_step)), 4.0, col)
		draw_circle(Vector2(right + 5.0, float(y_step) - 1.0), 1.5, Color(1.0, 1.0, 1.0, 0.9))
