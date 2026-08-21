extends Area3D
@export_enum("multiply", "add", "subtract", "divide") var operation: String = "add"
@export var value: float = 5.0
var _used := false
func _on_body_entered(body: Node3D) -> void:
 if _used or not body.is_in_group("player"): return
 _used = true
 GateManager.apply_gate(StringName(operation), value)
