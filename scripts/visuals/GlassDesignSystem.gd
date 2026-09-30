class_name GlassDesignSystem
extends Node

## ==============================================================================
## LUMI / BUBBLEWOOD - VISUAL DESIGN SYSTEM & GLASSMORPHISM LIBRARY
## Premium Glassmorphism + Glossy Bubble Art Direction (64-Rule Compliance)
## ==============================================================================

## --- COLOR PHILOSOPHY (Section 3) ---
const COLOR_GLASS_WHITE: Color   = Color(1.0, 1.0, 1.0, 1.0)       # #FFFFFF - Highlights & UI
const COLOR_CRYSTAL_BLUE: Color  = Color(0.41, 0.85, 1.0, 1.0)     # #69D9FF - World 1 / Primary
const COLOR_SKY_BLUE: Color      = Color(0.33, 0.75, 1.0, 1.0)     # #55BFFF - Sky Accent
const COLOR_AQUA: Color          = Color(0.28, 0.90, 0.83, 1.0)    # #48E5D4 - Buttons / Primary Glow
const COLOR_MINT: Color          = Color(0.46, 0.91, 0.78, 1.0)    # #76E8C7 - Green Bubble / Garden
const COLOR_LAVENDER: Color      = Color(0.66, 0.55, 1.0, 1.0)     # #A98BFF - Purple / World 2
const COLOR_PINK: Color          = Color(1.0, 0.48, 0.78, 1.0)     # #FF7BC8 - Pink / Cavern
const COLOR_CORAL: Color         = Color(1.0, 0.49, 0.55, 1.0)     # #FF7E8B - Red Bubble
const COLOR_SUNSHINE: Color      = Color(1.0, 0.84, 0.35, 1.0)     # #FFD75A - Yellow Bubble / Stars / Gold
const COLOR_DEEP_PURPLE: Color   = Color(0.22, 0.17, 0.40, 1.0)    # #392C66 - BG Top World 2
const COLOR_DEEP_NAVY: Color     = Color(0.09, 0.10, 0.23, 1.0)    # #171A3A - BG Base
const COLOR_BACKGROUND_BLUE: Color = Color(0.13, 0.15, 0.36, 1.0)  # #20265C - BG Mid

## --- BUBBLE 3D GLASS PALETTES (Section 13, 14, 15) ---
## Each color has: [Base, Light Tint, Deep Shade, Glow Tint, Specular Tint]
const BUBBLE_PALETTES: Dictionary = {
	Enums.BubbleColor.RED: {
		"base": Color(1.0, 0.32, 0.38, 1.0),        # Vibrant Coral Red
		"light": Color(1.0, 0.72, 0.76, 0.9),       # Light Coral Dome
		"deep": Color(0.55, 0.08, 0.15, 1.0),       # Deep Crimson Shadow
		"glow": Color(1.0, 0.40, 0.45, 0.35),      # Soft Red Halo
		"rim": Color(1.0, 0.85, 0.88, 0.6)          # Rim Glint
	},
	Enums.BubbleColor.BLUE: {
		"base": Color(0.25, 0.62, 1.0, 1.0),        # Crystal Blue
		"light": Color(0.70, 0.88, 1.0, 0.9),       # Sky Blue Tint Dome
		"deep": Color(0.08, 0.22, 0.65, 1.0),       # Deep Navy Shadow
		"glow": Color(0.35, 0.75, 1.0, 0.35),      # Soft Blue Halo
		"rim": Color(0.80, 0.94, 1.0, 0.6)          # Rim Glint
	},
	Enums.BubbleColor.GREEN: {
		"base": Color(0.28, 0.88, 0.55, 1.0),       # Mint Emerald
		"light": Color(0.72, 0.98, 0.85, 0.9),      # Pale Mint Dome
		"deep": Color(0.05, 0.42, 0.22, 1.0),       # Deep Forest Shadow
		"glow": Color(0.35, 0.92, 0.65, 0.35),      # Soft Emerald Halo
		"rim": Color(0.85, 1.0, 0.92, 0.6)          # Rim Glint
	},
	Enums.BubbleColor.YELLOW: {
		"base": Color(1.0, 0.84, 0.25, 1.0),        # Bright Sunshine Gold
		"light": Color(1.0, 0.96, 0.72, 0.9),       # Cream Golden Dome
		"deep": Color(0.68, 0.45, 0.05, 1.0),       # Warm Amber Shadow
		"glow": Color(1.0, 0.88, 0.35, 0.35),      # Soft Amber Halo
		"rim": Color(1.0, 0.98, 0.85, 0.6)          # Rim Glint
	},
	Enums.BubbleColor.PURPLE: {
		"base": Color(0.72, 0.42, 1.0, 1.0),        # Radiant Lavender
		"light": Color(0.88, 0.76, 1.0, 0.9),       # Pale Violet Dome
		"deep": Color(0.35, 0.12, 0.62, 1.0),       # Deep Obsidian Violet
		"glow": Color(0.78, 0.52, 1.0, 0.35),      # Soft Violet Halo
		"rim": Color(0.92, 0.86, 1.0, 0.6)          # Rim Glint
	},
	Enums.BubbleColor.CYAN: {
		"base": Color(0.22, 0.88, 0.92, 1.0),       # Radiant Turquoise Aqua
		"light": Color(0.72, 0.98, 1.0, 0.9),       # Pale Cyan Dome
		"deep": Color(0.05, 0.42, 0.52, 1.0),       # Deep Teal Shadow
		"glow": Color(0.30, 0.92, 0.95, 0.35),      # Soft Turquoise Halo
		"rim": Color(0.85, 0.98, 1.0, 0.6)          # Rim Glint
	}
}

## --- LIGHTING VECTOR (Section 13, 41) ---
## Fixed Upper-Left Lighting Angle for absolute consistency across 100% of visuals
const LIGHT_DIRECTION: Vector2 = Vector2(-0.7071, -0.7071) # Upper-left (-45 deg)
const LIGHT_OFFSET_PRIMARY: Vector2 = Vector2(-0.35, -0.35)
const LIGHT_OFFSET_SECONDARY: Vector2 = Vector2(-0.18, -0.48)
const SHADOW_OFFSET: Vector2 = Vector2(3.0, 4.5)

## --- ANIMATION TIMINGS (Section 52) ---
const TIME_BUTTON_TWEEN: float    = 0.12  # 120ms responsive button press
const TIME_PANEL_OPEN: float      = 0.22  # 220ms smooth glass popup
const TIME_BUBBLE_POP: float      = 0.18  # 180ms crisp pop + scale 1.08
const TIME_REWARD_SHOW: float     = 0.55  # 550ms star reward cascade
const TIME_WORLD_TRANSITION: float = 0.35 # 350ms world transition

## --- WORLD THEME PALETTES (Section 5, 49) ---
const WORLD_THEMES: Dictionary = {
	1: {
		"name": "Whispering Woods",
		"bg_top": Color(0.10, 0.12, 0.28, 1.0),    # Deep Indigo
		"bg_mid": Color(0.12, 0.28, 0.38, 1.0),    # Forest Aqua Night
		"bg_bottom": Color(0.08, 0.10, 0.20, 1.0), # Deep Navy
		"accent": COLOR_AQUA,
		"glow_color": Color(0.28, 0.90, 0.83, 0.25),
		"particle_tint": Color(0.5, 1.0, 0.85, 0.6)
	},
	2: {
		"name": "Crystal Caverns",
		"bg_top": Color(0.22, 0.14, 0.38, 1.0),    # Deep Amethyst
		"bg_mid": Color(0.28, 0.18, 0.48, 1.0),    # Radiant Violet
		"bg_bottom": Color(0.10, 0.08, 0.22, 1.0), # Obsidian Violet
		"accent": COLOR_LAVENDER,
		"glow_color": Color(0.72, 0.45, 1.0, 0.25),
		"particle_tint": Color(0.85, 0.65, 1.0, 0.6)
	},
	3: {
		"name": "Sunken Grove",
		"bg_top": Color(0.06, 0.18, 0.28, 1.0),    # Abyssal Teal
		"bg_mid": Color(0.08, 0.32, 0.42, 1.0),    # Ocean Glass Aqua
		"bg_bottom": Color(0.04, 0.08, 0.18, 1.0), # Deep Trench
		"accent": COLOR_CRYSTAL_BLUE,
		"glow_color": Color(0.40, 0.85, 1.0, 0.25),
		"particle_tint": Color(0.6, 0.95, 1.0, 0.6)
	}
}

## ==============================================================================
## GLASS UI STYLEBOX FACTORIES (Section 6, 7, 8, 50)
## ==============================================================================

static func create_glass_panel_style(
	corner_radius: int = 22,
	bg_alpha: float = 0.32,
	tint: Color = Color(0.12, 0.16, 0.35),
	border_color: Color = Color(1.0, 1.0, 1.0, 0.45),
	border_width: int = 2
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, bg_alpha)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.border_width_top = border_width + 1 # Subtle top edge light glint
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.0, 0.0, 0.05, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.5
	return style

static func create_glass_button_style(
	state: String = "normal", # "normal", "hover", "pressed", "disabled"
	primary: bool = false,
	corner_radius: int = 24
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_corner_radius_all(corner_radius)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.5
	style.set_border_width_all(2)
	
	if primary:
		# Large Primary Aqua->Blue Capsule (Section 9)
		match state:
			"normal":
				style.bg_color = Color(0.20, 0.65, 0.92, 0.75)
				style.border_color = Color(0.85, 1.0, 1.0, 0.80)
				style.border_width_top = 3
				style.shadow_color = Color(0.15, 0.55, 0.85, 0.45)
				style.shadow_size = 10
				style.shadow_offset = Vector2(0, 5)
			"hover":
				style.bg_color = Color(0.28, 0.75, 1.0, 0.85)
				style.border_color = Color(1.0, 1.0, 1.0, 0.95)
				style.border_width_top = 3
				style.shadow_color = Color(0.30, 0.80, 1.0, 0.60)
				style.shadow_size = 14
				style.shadow_offset = Vector2(0, 6)
			"pressed":
				style.bg_color = Color(0.14, 0.48, 0.75, 0.85)
				style.border_color = Color(0.70, 0.90, 1.0, 0.70)
				style.shadow_size = 4
				style.shadow_offset = Vector2(0, 2)
			"disabled":
				style.bg_color = Color(0.2, 0.25, 0.35, 0.30)
				style.border_color = Color(1.0, 1.0, 1.0, 0.15)
				style.shadow_size = 0
	else:
		# Secondary Glass Button (Section 10)
		match state:
			"normal":
				style.bg_color = Color(1.0, 1.0, 1.0, 0.18)
				style.border_color = Color(1.0, 1.0, 1.0, 0.45)
				style.border_width_top = 2
				style.shadow_color = Color(0.0, 0.0, 0.1, 0.25)
				style.shadow_size = 6
				style.shadow_offset = Vector2(0, 4)
			"hover":
				style.bg_color = Color(1.0, 1.0, 1.0, 0.28)
				style.border_color = Color(1.0, 1.0, 1.0, 0.75)
				style.border_width_top = 2
				style.shadow_color = Color(0.4, 0.8, 1.0, 0.35)
				style.shadow_size = 8
				style.shadow_offset = Vector2(0, 4)
			"pressed":
				style.bg_color = Color(1.0, 1.0, 1.0, 0.10)
				style.border_color = Color(1.0, 1.0, 1.0, 0.30)
				style.shadow_size = 2
				style.shadow_offset = Vector2(0, 1)
			"disabled":
				style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
				style.border_color = Color(1.0, 1.0, 1.0, 0.12)
				style.shadow_size = 0
				
	return style

static func create_glass_card_style(corner_radius: int = 20) -> StyleBoxFlat:
	return create_glass_panel_style(
		corner_radius,
		0.28,
		Color(0.10, 0.14, 0.32),
		Color(1.0, 1.0, 1.0, 0.40),
		2
	)

static func create_glass_capsule_style(tint: Color = COLOR_AQUA) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(tint.r * 0.3, tint.g * 0.3, tint.b * 0.3, 0.45)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(tint.r, tint.g, tint.b, 0.30)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = true
	return style

static func create_glass_progress_bg_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.22, 0.55)
	style.border_color = Color(1.0, 1.0, 1.0, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.anti_aliasing = true
	return style

static func create_glass_progress_fill_style(gradient_color: Color = COLOR_AQUA) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(gradient_color.r, gradient_color.g, gradient_color.b, 0.85)
	style.border_color = Color(1.0, 1.0, 1.0, 0.70)
	style.border_width_top = 1
	style.border_width_bottom = 0
	style.border_width_left = 0
	style.border_width_right = 0
	style.set_corner_radius_all(10)
	style.shadow_color = Color(gradient_color.r, gradient_color.g, gradient_color.b, 0.5)
	style.shadow_size = 6
	style.anti_aliasing = true
	return style
