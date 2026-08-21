extends Node
## Touch input seam. A future mobile gesture layer can emit the same actions as keyboard input.
signal horizontal_input(value: float)
func handle_screen_drag(delta_x: float, screen_width: float) -> void:
 if screen_width > 0.0: horizontal_input.emit(clampf(delta_x / screen_width * 2.0, -1.0, 1.0))
