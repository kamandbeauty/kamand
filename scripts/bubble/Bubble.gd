class_name Bubble
extends Node2D

signal pop_completed(bubble: Bubble)
signal fall_completed(bubble: Bubble)
signal exploded(bubble: Bubble)

@export var bubble_color: int = Enums.BubbleColor.RED:
	set(value):
		bubble_color = value
		queue_redraw()

@export var special_type: int = Enums.SpecialType.NONE:
	set(value):
		special_type = value
		queue_redraw()

var lock_hits_remaining: int = 1
var grid_coord: Vector2i = Vector2i(-1, -1)
var state: int = Enums.BubbleState.READY
var radius: float = Constants.BUBBLE_RADIUS

## Idle shimmer animation variables
var _idle_time: float = 0.0
var _idle_phase: float = randf_range(0.0, TAU)

## Falling animation state variables
var _is_falling: bool = false
var _fall_velocity: Vector2 = Vector2.ZERO
var _fall_gravity: float = 2600.0
var _fall_angular_velocity: float = 0.0

func _ready() -> void:
	queue_redraw()

func set_bubble_type(color_type: int, spec_type: int = Enums.SpecialType.NONE) -> void:
	bubble_color = color_type
	special_type = spec_type
	queue_redraw()

func set_grid_coordinate(coord: Vector2i) -> void:
	grid_coord = coord
	state = Enums.BubbleState.ATTACHED

func _process(delta: float) -> void:
	if _is_falling:
		_fall_velocity.y += _fall_gravity * delta
		position += _fall_velocity * delta
		rotation += _fall_angular_velocity * delta
		
		# Clean up once fallen off the bottom of the screen
		if position.y > Constants.SCREEN_HEIGHT + radius * 2.0:
			_is_falling = false
			state = Enums.BubbleState.REMOVED
			fall_completed.emit(self)
			queue_free()
	elif state == Enums.BubbleState.ATTACHED and not SaveManager.reduced_effects:
		_idle_time += delta
		# Subtle idle shimmer pulse
		var shimmer: float = sin(_idle_time * 2.0 + _idle_phase) * 0.015
		scale = Vector2(1.0 + shimmer, 1.0 - shimmer)
		if special_type != Enums.SpecialType.NONE:
			queue_redraw()

func _draw() -> void:
	match special_type:
		Enums.SpecialType.BOMB:
			_draw_bomb_bubble()
		Enums.SpecialType.RAINBOW:
			_draw_rainbow_bubble()
		Enums.SpecialType.LIGHTNING:
			_draw_lightning_bubble()
		Enums.SpecialType.STONE:
			_draw_stone_bubble()
		Enums.SpecialType.LOCKED:
			_draw_locked_bubble()
		_:
			_draw_standard_bubble()

func _draw_standard_bubble() -> void:
	var base_color: Color = Constants.get_color_for_type(bubble_color)
	var shadow_color: Color = base_color.darkened(0.45)
	var highlight_color: Color = base_color.lightened(0.55)
	var specular_color: Color = Color(1.0, 1.0, 1.0, 0.85)
	
	# 1. Outer ambient glow ring
	draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, 32, Color(base_color.r, base_color.g, base_color.b, 0.25), 2.5, true)
	# 2. Base dark sphere foundation
	draw_circle(Vector2.ZERO, radius, shadow_color)
	# 3. Main vibrant sphere
	draw_circle(Vector2(0, -radius * 0.05), radius * 0.92, base_color)
	# 4. Soft curved bottom shadow
	draw_circle(Vector2(0, radius * 0.22), radius * 0.78, Color(shadow_color.r, shadow_color.g, shadow_color.b, 0.6))
	# 5. Inner body core
	draw_circle(Vector2(0, 0), radius * 0.82, base_color)
	# 6. Top-left soft highlight dome
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.52, Color(highlight_color.r, highlight_color.g, highlight_color.b, 0.55))
	# 7. Sharp crystal specular glint
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.18, specular_color)
	draw_circle(Vector2(-radius * 0.20, -radius * 0.45), radius * 0.08, specular_color)
	# 8. Subtle outer rim stroke
	draw_arc(Vector2.ZERO, radius - 0.5, 0.0, TAU, 32, base_color.darkened(0.6), 1.5, true)
	
	# 9. Accessibility Rune / Pattern Glyph
	if SaveManager.show_accessibility_symbols:
		_draw_accessibility_glyph()

func _draw_bomb_bubble() -> void:
	var dark_obsidian: Color = Color(0.12, 0.12, 0.16)
	var rim_color: Color = Color(0.3, 0.3, 0.38)
	var orange_fuse: Color = Color(1.0, 0.55, 0.1)
	
	# Pulsating warning aura
	var pulse: float = sin(_idle_time * 6.0) * 0.2 + 0.8
	draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.1, 0.35 * pulse), 3.0, true)
	
	draw_circle(Vector2.ZERO, radius, dark_obsidian)
	draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.45, Color(0.35, 0.35, 0.45, 0.5))
	draw_arc(Vector2.ZERO, radius - 0.5, 0.0, TAU, 32, rim_color, 2.0, true)
	
	# Fuse top cap & spark
	draw_rect(Rect2(-4.0, -radius - 3.0, 8.0, 5.0), Color(0.4, 0.3, 0.2))
	draw_circle(Vector2(0, -radius - 5.0), 3.5 * pulse, orange_fuse)
	
	# Bomb Skull/Cross Icon
	var r: float = radius * 0.4
	draw_line(Vector2(-r, -r), Vector2(r, r), Color(1.0, 0.4, 0.2), 3.0)
	draw_line(Vector2(-r, r), Vector2(r, -r), Color(1.0, 0.4, 0.2), 3.0)

func _draw_rainbow_bubble() -> void:
	var t: float = _idle_time * 2.0
	var col1: Color = Color.from_hsv(fmod(t, 1.0), 0.85, 0.95)
	var col2: Color = Color.from_hsv(fmod(t + 0.33, 1.0), 0.85, 0.95)
	
	draw_circle(Vector2.ZERO, radius, col1)
	draw_circle(Vector2(0, 0), radius * 0.82, col2)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.5, Color(1, 1, 1, 0.6))
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.18, Color.WHITE)
	
	# Rainbow Spiral Ring
	draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.8), 2.5, true)
	draw_circle(Vector2.ZERO, radius * 0.25, Color.WHITE)

func _draw_lightning_bubble() -> void:
	var base: Color = Color(0.18, 0.4, 0.95)
	draw_circle(Vector2.ZERO, radius, base)
	draw_circle(Vector2(-radius * 0.2, -radius * 0.2), radius * 0.5, Color(0.5, 0.8, 1.0, 0.7))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.8, 0.95, 1.0), 2.0, true)
	
	# Lightning Bolt Glyph
	var bolt_pts: PackedVector2Array = [
		Vector2(2, -radius * 0.65),
		Vector2(-radius * 0.45, 0),
		Vector2(0, 0),
		Vector2(-2, radius * 0.65),
		Vector2(radius * 0.45, -2),
		Vector2(0, -2)
	]
	draw_colored_polygon(bolt_pts, Color(1.0, 0.95, 0.2))

func _draw_stone_bubble() -> void:
	var stone_gray: Color = Color(0.42, 0.45, 0.50)
	var stone_dark: Color = Color(0.24, 0.26, 0.30)
	draw_circle(Vector2.ZERO, radius, stone_gray)
	draw_circle(Vector2(0, radius * 0.25), radius * 0.75, stone_dark)
	draw_circle(Vector2(0, 0), radius * 0.8, stone_gray)
	
	# Craggy cracks
	draw_line(Vector2(-radius * 0.4, -radius * 0.3), Vector2(0, 0), stone_dark, 2.5)
	draw_line(Vector2(0, 0), Vector2(radius * 0.3, -radius * 0.4), stone_dark, 2.0)
	draw_line(Vector2(0, 0), Vector2(-radius * 0.2, radius * 0.5), stone_dark, 2.5)

func _draw_locked_bubble() -> void:
	_draw_standard_bubble()
	# Frost / Ice Crystal Outer Shell
	var ice_color: Color = Color(0.7, 0.92, 1.0, 0.75)
	draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 24, ice_color, 3.0, true)
	draw_line(Vector2(-radius * 0.6, 0), Vector2(radius * 0.6, 0), ice_color, 2.0)
	draw_line(Vector2(0, -radius * 0.6), Vector2(0, radius * 0.6), ice_color, 2.0)
	draw_circle(Vector2.ZERO, 5.0, Color.WHITE)

func _draw_accessibility_glyph() -> void:
	var glyph_color: Color = Color(1.0, 1.0, 1.0, 0.65)
	var r: float = radius * 0.38
	
	match bubble_color:
		Enums.BubbleColor.RED: # Flame Rune
			var pts: PackedVector2Array = [
				Vector2(0, -r * 0.9),
				Vector2(r * 0.7, r * 0.6),
				Vector2(-r * 0.7, r * 0.6)
			]
			draw_polyline(pts, glyph_color, 2.0, true)
			draw_line(pts[2], pts[0], glyph_color, 2.0, true)
			
		Enums.BubbleColor.BLUE: # Water Droplet Rune
			draw_circle(Vector2(0, r * 0.2), r * 0.5, glyph_color)
			draw_line(Vector2(0, -r * 0.8), Vector2(0, r * 0.2), glyph_color, 2.0)
			
		Enums.BubbleColor.GREEN: # Leaf Rune
			var pts_leaf: PackedVector2Array = [
				Vector2(0, -r * 0.8),
				Vector2(r * 0.6, 0),
				Vector2(0, r * 0.8),
				Vector2(-r * 0.6, 0)
			]
			draw_polyline(pts_leaf, glyph_color, 2.0, true)
			draw_line(pts_leaf[3], pts_leaf[0], glyph_color, 2.0, true)
			draw_line(Vector2(0, -r * 0.8), Vector2(0, r * 0.8), glyph_color, 1.5)
			
		Enums.BubbleColor.YELLOW: # Sun Rune
			draw_arc(Vector2.ZERO, r * 0.45, 0.0, TAU, 16, glyph_color, 2.0, true)
			for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
				var p1: Vector2 = Vector2.from_angle(ang) * (r * 0.55)
				var p2: Vector2 = Vector2.from_angle(ang) * (r * 0.9)
				draw_line(p1, p2, glyph_color, 2.0)
				
		Enums.BubbleColor.PURPLE: # Star / Moon Crescent Rune
			draw_arc(Vector2(r * 0.15, 0), r * 0.6, -PI * 0.45, PI * 0.45, 16, glyph_color, 2.2, true)
			draw_arc(Vector2(r * 0.35, 0), r * 0.5, -PI * 0.45, PI * 0.45, 16, glyph_color, 1.8, true)
			
		Enums.BubbleColor.CYAN: # Crystal Diamond Rune
			var pts_diamond: PackedVector2Array = [
				Vector2(0, -r * 0.85),
				Vector2(r * 0.75, 0),
				Vector2(0, r * 0.85),
				Vector2(-r * 0.75, 0)
			]
			draw_polyline(pts_diamond, glyph_color, 2.0, true)
			draw_line(pts_diamond[3], pts_diamond[0], glyph_color, 2.0, true)
			draw_line(Vector2(-r * 0.75, 0), Vector2(r * 0.75, 0), glyph_color, 1.5)

## Impact squash-and-stretch tween when docking into the grid
func play_snap_animation(target_pos: Vector2, duration: float = 0.10) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(1.18, 0.84), duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.92, 1.08), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Pop animation for 3+ matched bubbles
func play_pop_animation() -> void:
	state = Enums.BubbleState.MATCHING
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.0, 0.0), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.10)
	tween.tween_callback(func():
		state = Enums.BubbleState.REMOVED
		pop_completed.emit(self)
		queue_free()
	)

## Explosion animation for Bomb / Lightning
func play_explode_animation() -> void:
	state = Enums.BubbleState.EXPLODING
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.10)
	tween.tween_callback(func():
		state = Enums.BubbleState.REMOVED
		exploded.emit(self)
		queue_free()
	)

## Cracks locked shell converting to standard bubble
func crack_locked_shell() -> void:
	lock_hits_remaining -= 1
	if lock_hits_remaining <= 0:
		special_type = Enums.SpecialType.NONE
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.06)
		tween.tween_property(self, "scale", Vector2.ONE, 0.06)
	queue_redraw()

## Drop / Fall animation for disconnected bubbles
func play_fall_animation(initial_vx: float = 0.0, initial_vy: float = -120.0) -> void:
	state = Enums.BubbleState.FALLING
	_is_falling = true
	_fall_velocity = Vector2(initial_vx, initial_vy)
	_fall_angular_velocity = randf_range(-3.5, 3.5)
