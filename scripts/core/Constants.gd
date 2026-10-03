class_name Constants
extends Node

## Screen and Playfield Dimensions (Portrait 720x1280 base)
const SCREEN_WIDTH: float = 720.0
const SCREEN_HEIGHT: float = 1280.0

## Bubble Geometry
const BUBBLE_RADIUS: float = 36.0
const BUBBLE_DIAMETER: float = 72.0
const COLLISION_RADIUS_FACTOR: float = 0.95

## Grid Layout
const GRID_COLUMNS_EVEN: int = 8
const GRID_COLUMNS_ODD: int = 7
const PLAY_AREA_WIDTH: float = 576.0 ## 8 * 72.0
const LEFT_WALL_X: float = 72.0      ## (720 - 576) / 2
const RIGHT_WALL_X: float = 648.0    ## 720 - 72
const GRID_START_Y: float = 160.0    ## Ceiling line Y position
const ROW_SPACING: float = 62.3538   ## 72.0 * sqrt(3)/2
const MAX_GRID_ROWS: int = 14
const DEFAULT_DANGER_ROW: int = 12

## Shooter & Physics
const SHOOTER_POSITION: Vector2 = Vector2(360.0, 1150.0)
const NEXT_BUBBLE_POSITION: Vector2 = Vector2(250.0, 1150.0)
const LUMI_POSITION: Vector2 = Vector2(580.0, 1160.0)
const SHOT_SPEED: float = 1400.0
const MIN_AIM_ANGLE_DEG: float = 15.0
const MAX_AIM_ANGLE_DEG: float = 165.0
const MAX_TRAJECTORY_BOUNCES: int = 3
const MAX_TRAJECTORY_LENGTH: float = 2400.0

## Scoring & Combos
const POINTS_PER_MATCH: int = 10
const POINTS_PER_DROP: int = 20
const POINTS_PER_BOMB: int = 50
const POINTS_PER_LIGHTNING: int = 40
const POINTS_PER_STONE: int = 30
const POINTS_PER_LOCK_CRACK: int = 25
const POINTS_OBJECTIVE_COMPLETE: int = 200
const COMBO_BONUS_MULTIPLIER: float = 0.25

## Total Game Content
const TOTAL_WORLDS: int = 3
const TOTAL_LEVELS: int = 30
const LEVELS_PER_WORLD: int = 10

## Visual Palettes for Bubble Colors
const COLOR_MAP: Dictionary = {
	Enums.BubbleColor.RED: Color(0.92, 0.25, 0.25, 1.0),      ## #EB4040
	Enums.BubbleColor.BLUE: Color(0.20, 0.45, 0.95, 1.0),     ## #3373F2
	Enums.BubbleColor.GREEN: Color(0.22, 0.82, 0.35, 1.0),    ## #38D159
	Enums.BubbleColor.YELLOW: Color(0.98, 0.82, 0.15, 1.0),   ## #FAD126
	Enums.BubbleColor.PURPLE: Color(0.68, 0.28, 0.90, 1.0),   ## #AE47E6
	Enums.BubbleColor.CYAN: Color(0.18, 0.80, 0.88, 1.0),     ## #2ECCDE
}

const COLOR_NAMES: Dictionary = {
	Enums.BubbleColor.RED: "RED",
	Enums.BubbleColor.BLUE: "BLUE",
	Enums.BubbleColor.GREEN: "GREEN",
	Enums.BubbleColor.YELLOW: "YELLOW",
	Enums.BubbleColor.PURPLE: "PURPLE",
	Enums.BubbleColor.CYAN: "CYAN",
}

const COLOR_SYMBOLS: Dictionary = {
	Enums.BubbleColor.RED: "R",
	Enums.BubbleColor.BLUE: "B",
	Enums.BubbleColor.GREEN: "G",
	Enums.BubbleColor.YELLOW: "Y",
	Enums.BubbleColor.PURPLE: "P",
	Enums.BubbleColor.CYAN: "C",
}

const SPECIAL_SYMBOLS: Dictionary = {
	Enums.SpecialType.BOMB: "💣",
	Enums.SpecialType.RAINBOW: "🌈",
	Enums.SpecialType.LIGHTNING: "⚡",
	Enums.SpecialType.STONE: "🪨",
	Enums.SpecialType.LOCKED: "❄",
}

static func get_color_for_type(type: int) -> Color:
	if COLOR_MAP.has(type):
		return COLOR_MAP[type]
	return Color.WHITE

static func get_symbol_for_type(type: int) -> String:
	if COLOR_SYMBOLS.has(type):
		return COLOR_SYMBOLS[type]
	return "?"
