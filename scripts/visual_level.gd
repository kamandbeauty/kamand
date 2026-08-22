extends Node3D
## Presentation-only Level 1 dressing. Gameplay triggers remain owned by main.gd.
@export var road_width := 12.0
@export var road_length := 120.0

var animation_controller := preload("res://scripts/character_animation_controller.gd")

func _ready() -> void:
 _make_road_edges()
 _make_gate_arches()
 _make_finish()

func _process(_delta: float) -> void:
 # Dynamic pooled character visuals are discovered without changing gameplay scripts.
 for node in get_tree().current_scene.get_children():
  _attach_animation(node)

func _attach_animation(node: Node) -> void:
 if node.name == "Visual" and node.get_script() == null:
  node.set_script(animation_controller)
  node.call_deferred("_ready")
 for child in node.get_children():
  _attach_animation(child)

func _box(parent: Node, size: Vector3, position: Vector3, color: Color) -> void:
 var mesh := MeshInstance3D.new()
 var box := BoxMesh.new(); box.size = size
 var material := StandardMaterial3D.new(); material.albedo_color = color
 mesh.mesh = box; mesh.material_override = material; mesh.position = position
 parent.add_child(mesh)

func _make_road_edges() -> void:
 _box(self, Vector3(1.0, 0.12, road_length), Vector3(-road_width * 0.5 - 0.7, 0.02, -30), Color(0.35, 0.28, 0.18))
 _box(self, Vector3(1.0, 0.12, road_length), Vector3(road_width * 0.5 + 0.7, 0.02, -30), Color(0.35, 0.28, 0.18))
 for z in range(-5, -101, -10):
  _box(self, Vector3(0.12, 0.03, 3.0), Vector3(0, 0.08, z), Color(0.95, 0.82, 0.3))

func _make_gate_arches() -> void:
 var groups := [{"z": -15.0, "positive": true}, {"z": -38.0, "positive": true}, {"z": -63.0, "positive": true}]
 for group in groups:
  var root := Node3D.new(); root.name = "GatePresentation_%s" % group.z; add_child(root)
  for side in [-1.0, 1.0]:
   var x := side * 3.0
   _box(root, Vector3(0.22, 4.0, 0.22), Vector3(x - side * 2.2, 2.0, group.z), Color(0.1, 0.75, 0.9))
   _box(root, Vector3(4.4, 0.22, 0.22), Vector3(x, 4.0, group.z), Color(0.1, 0.75, 0.9))

func _make_finish() -> void:
 var root := Node3D.new(); root.name = "FinishPresentation"; add_child(root)
 _box(root, Vector3(12.0, 0.08, 0.8), Vector3(0, 0.06, -100), Color(0.95, 0.85, 0.2))
 for side in [-1.0, 1.0]:
  _box(root, Vector3(0.3, 4.0, 0.3), Vector3(side * 5.0, 2.0, -100), Color(0.9, 0.2, 0.15))
  _box(root, Vector3(10.3, 0.35, 0.3), Vector3(0, 4.0, -100), Color(0.9, 0.2, 0.15))
 var label := Label3D.new(); label.text = "FINISH"; label.font_size = 64; label.modulate = Color(1.0, 0.9, 0.2); label.position = Vector3(0, 4.3, -100); root.add_child(label)
