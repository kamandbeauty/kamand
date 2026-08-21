extends CharacterBody3D
## Lightweight player controller, ready for a future touch input provider.
@export var forward_speed := 5.0
@export var lateral_speed := 7.0
@export var lane_limit := 4.0
var touch_axis := 0.0
func _physics_process(_delta: float) -> void:
 var direction := Input.get_axis("move_left", "move_right")
 direction = touch_axis if absf(touch_axis) > 0.01 else direction
 velocity.x = direction * lateral_speed
 velocity.z = -forward_speed
 global_position.x = clampf(global_position.x, -lane_limit, lane_limit)
 move_and_slide()
