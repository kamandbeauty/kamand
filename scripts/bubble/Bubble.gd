class_name Bubble
extends Node2D

## ==============================================================================
## LUMI / BUBBLEWOOD - PREMIUM 3D GLOSS BUBBLE (Section 12-17, 22-24, 51)
## 8-Layer Composite Glass Shader & Procedural Specular Lighting
## ==============================================================================

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

## Animation & Visual FX
var _idle_time: float = 0.0
var _idle_phase: float = randf_range(0.0, TAU)
var _pop_flash: float = 0.0
var _is_falling: bool = false
var _fall_velocity: Vector2 = Vector2.ZERO
var _fall_gravity: float = 2400.0
var _fall_angular_velocity: float = 0.0
var _is_popping: bool = false

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
		
		# Squash and stretch subtle deformation during fall
		var speed_factor: float = clampf(abs(_fall_velocity.y) / 1200.0, 0.0, 0.25)
		scale = Vector2(1.0 - speed_factor * 0.4, 1.0 + speed_factor * 0.6)
		
		if position.y > Constants.SCREEN_HEIGHT + radius * 2.0:
			_is_falling = false
			state = Enums.BubbleState.REMOVED
			fall_completed.emit(self)
			queue_free()
	elif state == Enums.BubbleState.ATTACHED and not SaveManager.reduced_effects:
		_idle_time += delta
		if special_type != Enums.SpecialType.NONE:
			queue_redraw()

## Triggers the premium 180ms pop animation sequence (Section 22, 23)
func play_pop_animation(delay: float = 0.0) -> void:
	if _is_popping: return
	_is_popping = true
	state = Enums.BubbleState.POPPING
	
	var tween: Tween = create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		
	# 1. Bubble brightens + scale 1.0 -> 1.08
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pop_flash = 1.0
	queue_redraw()
	
	# 2. White flash & burst fade out
	tween.tween_property(self, "scale", Vector2(0.3, 0.3), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.10)
	
	tween.finished.connect(func():
		state = Enums.BubbleState.REMOVED
		pop_completed.emit(self)
		queue_free()
	)

func start_falling(initial_velocity: Vector2 = Vector2.ZERO) -> void:
	_is_falling = true
	state = Enums.BubbleState.FALLING
	_fall_velocity = initial_velocity if initial_velocity != Vector2.ZERO else Vector2(randf_range(-100, 100), randf_range(-250, -80))
	_fall_angular_velocity = randf_range(-4.0, 4.0)

## ------------------------------------------------------------------------------
## 8-LAYER COMPOSITE RENDERING PIPELINE (Section 12-17)
## ------------------------------------------------------------------------------
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
			_draw_standard_glass_bubble()

func _draw_standard_glass_bubble() -> void:
	var palette: Dictionary = GlassDesignSystem.BUBBLE_PALETTES.get(
		bubble_color,
		GlassDesignSystem.BUBBLE_PALETTES[Enums.BubbleColor.RED]
	)
	var base_col: Color = palette["base"]
	var light_col: Color = palette["light"]
	var deep_col: Color = palette["deep"]
	var glow_col: Color = palette["glow"]
	var rim_col: Color = palette["rim"]
	
	# Layer 1: Soft Colored Ambient Outer Glow (Section 12.1)
	draw_arc(Vector2.ZERO, radius + 2.5, 0.0, TAU, 32, glow_col, 3.5, true)
	
	# Layer 2: Offset Soft Drop Shadow (Section 17)
	var shadow_col: Color = Color(0.04, 0.04, 0.12, 0.35)
	draw_circle(GlassDesignSystem.SHADOW_OFFSET, radius * 0.94, shadow_col)
	
	# Layer 3: Outer Rim & Spherical Foundation (Section 13, 16)
	draw_circle(Vector2.ZERO, radius, deep_col)
	
	# Layer 4: Spherical Gradient Body (Upper-Left to Lower-Right 3D Light)
	var body_offset: Vector2 = GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.22)
	draw_circle(body_offset, radius * 0.90, base_col)
	
	# Layer 5: Inner Refraction Core & Soft Lower Ambient Bounce
	var bounce_offset: Vector2 = -GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.35)
	draw_circle(bounce_offset, radius * 0.65, Color(light_col.r, light_col.g, light_col.b, 0.30))
	
	# Layer 6: Upper-Left Soft Illumination Dome
	var dome_offset: Vector2 = GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.42)
	draw_circle(dome_offset, radius * 0.55, Color(light_col.r, light_col.g, light_col.b, 0.65))
	
	# Layer 7: Primary Specular Highlight (Curved Glass Glint - Section 14)
	var spec_primary: Vector2 = GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.52)
	draw_circle(spec_primary, radius * 0.22, Color(1.0, 1.0, 1.0, 0.88))
	
	# Layer 8: Secondary Specular Reflection & Crisp Rim Light
	var spec_sec: Vector2 = GlassDesignSystem.LIGHT_OFFSET_SECONDARY * (radius * 0.58)
	draw_circle(spec_sec, radius * 0.10, Color(1.0, 1.0, 1.0, 0.75))
	
	# Translucent Glass Rim Stroke
	draw_arc(Vector2.ZERO, radius - 0.75, 0.0, TAU, 32, rim_col, 1.5, true)
	
	# Accessibility Rune / Symbol (if enabled)
	if SaveManager.show_accessibility_symbols:
		_draw_accessibility_glyph()
		
	# White pop flash overlay
	if _pop_flash > 0.0:
		draw_circle(Vector2.ZERO, radius * 1.05, Color(1.0, 1.0, 1.0, 0.7 * _pop_flash))

func _draw_bomb_bubble() -> void:
	var obsidian_base: Color = Color(0.12, 0.14, 0.20, 1.0)
	var obsidian_deep: Color = Color(0.04, 0.05, 0.08, 1.0)
	var glow_pulse: float = sin(_idle_time * 6.0) * 0.25 + 0.75
	var orange_glow: Color = Color(1.0, 0.45, 0.15, 0.45 * glow_pulse)
	
	# 1. Pulsating Fiery Outer Glow
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 32, orange_glow, 4.0, true)
	# 2. Shadow
	draw_circle(GlassDesignSystem.SHADOW_OFFSET, radius * 0.94, Color(0, 0, 0, 0.45))
	# 3. Metallic obsidian core
	draw_circle(Vector2.ZERO, radius, obsidian_deep)
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * 6.0, radius * 0.88, obsidian_base)
	# 4. Glass highlight
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.48), radius * 0.20, Color(1.0, 1.0, 1.0, 0.80))
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_SECONDARY * (radius * 0.55), radius * 0.09, Color(1.0, 1.0, 1.0, 0.65))
	# 5. Glowing Bomb Core Rune
	draw_circle(Vector2.ZERO, radius * 0.42, Color(1.0, 0.35, 0.1, 0.35 * glow_pulse))
	draw_arc(Vector2.ZERO, radius * 0.42, 0.0, TAU, 24, Color(1.0, 0.6, 0.2, 0.9), 2.0, true)
	draw_circle(Vector2.ZERO, radius * 0.18, Color(1.0, 0.85, 0.4, 0.95))

func _draw_rainbow_bubble() -> void:
	# Prismatic iridescent glass crystal
	var cycle: float = _idle_time * 2.5
	var r: float = sin(cycle) * 0.4 + 0.6
	var g: float = sin(cycle + 2.09) * 0.4 + 0.6
	var b: float = sin(cycle + 4.18) * 0.4 + 0.6
	var prism_col: Color = Color(r, g, b, 1.0)
	
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 32, Color(prism_col.r, prism_col.g, prism_col.b, 0.4), 3.5, true)
	draw_circle(GlassDesignSystem.SHADOW_OFFSET, radius * 0.94, Color(0.05, 0.05, 0.15, 0.3))
	draw_circle(Vector2.ZERO, radius, Color(0.15, 0.15, 0.3, 1.0))
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * 5.0, radius * 0.88, prism_col.darkened(0.2))
	draw_circle(Vector2.ZERO, radius * 0.70, Color(1.0, 1.0, 1.0, 0.45))
	# Prismatic concentric glass rings
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 28, Color(1.0, 0.9, 0.4, 0.8), 2.5, true)
	draw_arc(Vector2.ZERO, radius * 0.35, 0.0, TAU, 24, Color(0.4, 0.9, 1.0, 0.85), 2.0, true)
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.5), radius * 0.22, Color(1.0, 1.0, 1.0, 0.92))
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_SECONDARY * (radius * 0.58), radius * 0.10, Color(1.0, 1.0, 1.0, 0.80))

func _draw_lightning_bubble() -> void:
	var zap_col: Color = Color(0.3, 0.85, 1.0)
	var glow_pulse: float = sin(_idle_time * 8.0) * 0.25 + 0.75
	
	draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 32, Color(zap_col.r, zap_col.g, zap_col.b, 0.45 * glow_pulse), 3.5, true)
	draw_circle(GlassDesignSystem.SHADOW_OFFSET, radius * 0.94, Color(0.02, 0.08, 0.18, 0.35))
	draw_circle(Vector2.ZERO, radius, Color(0.08, 0.25, 0.45))
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * 5.0, radius * 0.88, zap_col.darkened(0.25))
	# Specular highlights
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.5), radius * 0.20, Color(1.0, 1.0, 1.0, 0.9))
	# Sharp glowing lightning bolt
	var bolt: PackedVector2Array = PackedVector2Array([
		Vector2(2, -18), Vector2(-10, 2), Vector2(0, 2),
		Vector2(-2, 18), Vector2(10, -2), Vector2(0, -2)
	])
	draw_colored_polygon(bolt, Color(1.0, 1.0, 1.0, 0.95))
	draw_polyline(bolt, Color(0.4, 0.95, 1.0, 0.85), 2.0, true)

func _draw_stone_bubble() -> void:
	# Crystalline quartz stone
	var stone_base: Color = Color(0.55, 0.58, 0.68)
	var stone_deep: Color = Color(0.28, 0.30, 0.38)
	
	draw_circle(GlassDesignSystem.SHADOW_OFFSET, radius * 0.94, Color(0.05, 0.05, 0.1, 0.4))
	draw_circle(Vector2.ZERO, radius, stone_deep)
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * 5.0, radius * 0.88, stone_base)
	
	# Geometric crystal facet lines (Section 48)
	var f1: PackedVector2Array = PackedVector2Array([Vector2(-12, -16), Vector2(14, -14), Vector2(18, 12), Vector2(-8, 16)])
	draw_colored_polygon(f1, Color(0.68, 0.72, 0.82, 0.65))
	draw_polyline(f1, Color(0.85, 0.88, 0.95, 0.8), 1.5, true)
	
	# Crisp corner specular
	draw_circle(GlassDesignSystem.LIGHT_OFFSET_PRIMARY * (radius * 0.48), radius * 0.16, Color(1.0, 1.0, 1.0, 0.75))

func _draw_locked_bubble() -> void:
	# Base bubble underneath ice
	_draw_standard_glass_bubble()
	
	# Frost Ice Crystal Shield (Section 48)
	var ice_col: Color = Color(0.80, 0.94, 1.0, 0.55)
	var frost_rim: Color = Color(1.0, 1.0, 1.0, 0.85)
	draw_circle(Vector2.ZERO, radius * 0.96, ice_col)
	draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 32, frost_rim, 2.5, true)
	
	# Ice fracture / snowflake lock glyph
	var lines: Array = [
		[Vector2(-14, 0), Vector2(14, 0)],
		[Vector2(0, -14), Vector2(0, 14)],
		[Vector2(-10, -10), Vector2(10, 10)],
		[Vector2(-10, 10), Vector2(10, -10)]
	]
	for seg in lines:
		draw_line(seg[0], seg[1], Color(1.0, 1.0, 1.0, 0.9), 2.0, true)

func _draw_accessibility_glyph() -> void:
	var sym: String = Constants.get_symbol_for_type(bubble_color)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 16
	var text_size: Vector2 = font.get_string_size(sym, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = Vector2(-text_size.x / 2.0, text_size.y / 3.5)
	
	# Shadow + Crisp White Glyph
	draw_string(font, text_pos + Vector2(1, 1), sym, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.6))
	draw_string(font, text_pos, sym, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1.0, 1.0, 1.0, 0.95))
