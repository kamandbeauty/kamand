class_name Enums
extends RefCounted

## Stable bubble color IDs
enum BubbleColor {
	NONE = -1,
	RED = 0,
	BLUE = 1,
	GREEN = 2,
	YELLOW = 3,
	PURPLE = 4,
	CYAN = 5
}

## Special bubble & obstacle types
enum SpecialType {
	NONE = 0,        ## Normal standard color bubble
	BOMB = 1,        ## Explodes all adjacent bubbles in radius 1
	RAINBOW = 2,     ## Wild bubble matching any color
	LIGHTNING = 3,   ## Clears an entire horizontal line/row
	STONE = 4,       ## Unbreakable blocker (falls or destroyed by Bomb)
	LOCKED = 5       ## Shell/Ice obstacle (cracks on adjacent match)
}

## Level objective types
enum ObjectiveType {
	CLEAR_ALL = 0,      ## Clear all bubbles from the board
	CLEAR_COLOR = 1,    ## Pop required amount of a specific color
	REACH_SCORE = 2,    ## Reach target score before running out of shots
	CLEAR_SPECIAL = 3   ## Destroy all special obstacles (Stone/Locked)
}

## Lifecycle states of an individual bubble
enum BubbleState {
	READY,        ## Waiting in launcher / preview
	IN_FLIGHT,    ## Fired and traveling toward grid
	ATTACHED,     ## Fixed at a grid coordinate
	MATCHING,     ## Playing pop / removal animation
	FALLING,      ## Disconnected from ceiling, falling down
	EXPLODING,    ## Bomb/Lightning special activation
	REMOVED       ## Cleaned up and inactive
}

## Top-level game lifecycle states
enum GameState {
	MENU,
	WORLD_MAP,
	PLAYING,
	AIMING,
	SHOOTING,
	RESOLVING,
	WIN,
	LOSE,
	PAUSED,
	SETTINGS
}

## World IDs
enum WorldID {
	WHISPERING_WOODS = 1,
	CRYSTAL_CAVERNS = 2,
	SUNKEN_GROVE = 3
}
