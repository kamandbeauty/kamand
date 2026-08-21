extends Node3D
@export var spacing := 1.25
@export var row_spacing := 1.15
var soldiers: Array[MeshInstance3D] = []
var pool: Array[MeshInstance3D] = []
var material: StandardMaterial3D
func _ready() -> void:
 material = StandardMaterial3D.new(); material.albedo_color = Color(0.15, 0.8, 1.0)
 PlayerManager.soldiers_changed.connect(set_soldier_count); set_soldier_count(PlayerManager.get_soldier_count())
func set_soldier_count(count: int) -> void:
 while soldiers.size() < count: soldiers.append(_acquire())
 while soldiers.size() > count: pool.append(soldiers.pop_back())
 for i in soldiers.size(): soldiers[i].position = formation_position(i, count)
func _acquire() -> MeshInstance3D:
 var s: MeshInstance3D = pool.pop_back() if not pool.is_empty() else MeshInstance3D.new()
 if s.mesh == null:
  var mesh := CapsuleMesh.new(); mesh.height = 1.0; mesh.radius = 0.28; s.mesh = mesh; s.material_override = material
 if not s.is_inside_tree(): add_child(s)
 s.visible = true; return s
func formation_position(index: int, count: int) -> Vector3:
 var columns := mini(6, maxi(1, ceili(sqrt(float(count))))); var row := index / columns; var col := index % columns
 return Vector3((col - (mini(columns, count) - 1) * 0.5) * spacing, 0.55, 1.6 + row * row_spacing)
func _process(delta: float) -> void:
 for i in soldiers.size(): soldiers[i].position = soldiers[i].position.lerp(formation_position(i, soldiers.size()), delta * 8.0)
