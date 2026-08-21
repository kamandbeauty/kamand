extends Node
## Central gate operation service; gates never modify Player directly.
func apply_gate(operation: StringName, value: float = 0.0) -> void:
 match operation:
  &"multiply": PlayerManager.apply_multiplier(value)
  &"add": PlayerManager.apply_delta(int(value))
  &"subtract": PlayerManager.apply_delta(-int(value))
  &"divide":
   if value != 0.0: PlayerManager.apply_multiplier(1.0 / value)
