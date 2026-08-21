extends CanvasLayer
@onready var soldiers_label: Label = $Margin/VBox/Soldiers
func _ready() -> void:
 PlayerManager.soldiers_changed.connect(_on_soldiers_changed)
 _on_soldiers_changed(PlayerManager.soldier_count)
 $Margin/VBox/Pause.pressed.connect(GameManager.toggle_pause)
func _on_soldiers_changed(value: int) -> void: soldiers_label.text = "Soldiers: %d" % value
