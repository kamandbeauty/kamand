extends Camera3D
@export var target_path: NodePath
@export var smooth_speed := 5.0
var target: Node3D
func _ready() -> void: target = get_node_or_null(target_path)
func _process(delta: float) -> void:
 if target:
  var desired := target.global_position + Vector3(0.0, 5.0, 8.0)
  global_position = global_position.lerp(desired, clampf(smooth_speed * delta, 0.0, 1.0))
  look_at(target.global_position + Vector3(0, 0.5, -3), Vector3.UP)
