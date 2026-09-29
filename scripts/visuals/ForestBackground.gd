class_name ForestBackground
extends Node2D

## Floating firefly particles data
var _fireflies: Array[Dictionary] = []
const FIREFLY_COUNT: int = 18

var _time: float = 0.0

func _ready() -> void:
	_init_fireflies()

func _init_fireflies() -> void:
	_fireflies.clear()
	for i in range(FIREFLY_COUNT):
		_fireflies.append({
			"base_pos": Vector2(randf_range(20.0, 700.0), randf_range(120.0, 1200.0)),
			"speed": randf_range(15.0, 35.0),
			"radius": randf_range(2.0, 4.5),
			"phase": randf_range(0.0, TAU),
			"pulse_speed": randf_range(1.5, 3.5),
			"color": Color(0.95, 0.85, 0.3) if (i % 2 == 0) else Color(0.3, 0.9, 0.85) # Gold or Teal
		})

func _process(delta: float) -> void:
	_time += delta
	if not SaveManager.reduced_effects:
		# Animate fireflies
		for f in _fireflies:
			f["phase"] += delta * f["pulse_speed"]
			f["base_pos"].y -= delta * f["speed"] * 0.4
			if f["base_pos"].y < 100.0:
				f["base_pos"].y = 1250.0
				f["base_pos"].x = randf_range(20.0, 700.0)
		queue_redraw()

func _draw() -> void:
	# 1. Deep mystical forest background gradient
	draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), Color(0.04, 0.06, 0.11, 1.0))
	
	# Top moonlight ambient glow
	draw_circle(Vector2(360.0, -80.0), 380.0, Color(0.12, 0.22, 0.38, 0.4))
	draw_circle(Vector2(360.0, -40.0), 220.0, Color(0.2, 0.35, 0.55, 0.3))
	
	# 2. Distant tree silhouette silhouettes (Layer 1)
	_draw_distant_forest_canopy()
	
	# 3. Playfield backdrop (centered 576px wide board)
	var left: float = Constants.LEFT_WALL_X
	var right: float = Constants.RIGHT_WALL_X
	var top: float = Constants.GRID_START_Y
	var bottom: float = Constants.SCREEN_HEIGHT
	
	# Translucent board backing with soft vignette
	draw_rect(Rect2(left, top, right - left, bottom - top), Color(0.07, 0.10, 0.18, 0.88))
	
	# 4. Floating fireflies (Layer 2)
	if not SaveManager.reduced_effects:
		for f in _fireflies:
			var sway_x: float = sin(f["phase"]) * 14.0
			var sway_y: float = cos(f["phase"] * 0.7) * 8.0
			var p: Vector2 = f["base_pos"] + Vector2(sway_x, sway_y)
			var alpha: float = (sin(f["phase"]) * 0.5 + 0.5) * 0.85 + 0.15
			var c: Color = f["color"]
			# Glow halo
			draw_circle(p, f["radius"] * 3.5, Color(c.r, c.g, c.b, alpha * 0.25))
			# Bright center
			draw_circle(p, f["radius"], Color(c.r, c.g, c.b, alpha))
			
	# 5. Playfield Carved Wood Frame & Side Pillars
	_draw_carved_pillars(left, right, top, bottom)
	
	# 6. Ancient ceiling beam
	draw_rect(Rect2(left - 8.0, top - 12.0, (right - left) + 16.0, 16.0), Color(0.18, 0.12, 0.08, 0.95))
	draw_rect(Rect2(left - 4.0, top - 10.0, (right - left) + 8.0, 4.0), Color(0.35, 0.25, 0.15, 0.9))
	# Glowing ceiling line
	draw_line(Vector2(left, top), Vector2(right, top), Color(0.3, 0.85, 0.75, 0.9), 3.0)
	
	# 7. Danger line with warning pulse
	var danger_y: float = top + Constants.BUBBLE_RADIUS + float(Constants.DEFAULT_DANGER_ROW) * Constants.ROW_SPACING
	var danger_alpha: float = (sin(_time * 4.0) * 0.25 + 0.55) if not SaveManager.reduced_effects else 0.5
	draw_line(Vector2(left + 8.0, danger_y), Vector2(right - 8.0, danger_y), Color(0.95, 0.25, 0.25, danger_alpha), 2.5)

func _draw_distant_forest_canopy() -> void:
	# Subtle foliage arch curves at top sides
	var branch_color: Color = Color(0.08, 0.14, 0.22, 0.7)
	draw_circle(Vector2(30.0, 180.0), 160.0, branch_color)
	draw_circle(Vector2(690.0, 180.0), 160.0, branch_color)
	draw_circle(Vector2(10.0, 400.0), 120.0, branch_color)
	draw_circle(Vector2(710.0, 400.0), 120.0, branch_color)

func _draw_carved_pillars(left: float, right: float, top: float, bottom: float) -> void:
	var wood_dark: Color = Color(0.14, 0.09, 0.06, 0.95)
	var wood_trim: Color = Color(0.28, 0.19, 0.12, 0.9)
	var crystal_rune: Color = Color(0.25, 0.85, 0.80, 0.8)
	
	# Left Pillar
	draw_rect(Rect2(left - 14.0, top, 14.0, bottom - top), wood_dark)
	draw_line(Vector2(left, top), Vector2(left, bottom), wood_trim, 3.0)
	
	# Right Pillar
	draw_rect(Rect2(right, top, 14.0, bottom - top), wood_dark)
	draw_line(Vector2(right, top), Vector2(right, bottom), wood_trim, 3.0)
	
	# Decorative glowing crystal runes down the side pillars
	for y_step in range(int(top) + 80, int(bottom) - 100, 140):
		var rune_pulse: float = (sin(_time * 2.0 + float(y_step) * 0.01) * 0.3 + 0.7)
		var rune_col: Color = Color(crystal_rune.r, crystal_rune.g, crystal_rune.b, rune_pulse * 0.8)
		# Left rune dot
		draw_circle(Vector2(left - 7.0, float(y_step)), 4.0, rune_col)
		# Right rune dot
		draw_circle(Vector2(right + 7.0, float(y_step)), 4.0, rune_col)
