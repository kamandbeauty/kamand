extends Node3D
@export var spacing := 1.25
@export var row_spacing := 1.15
@export var soldier_max_health := 1
var soldiers: Array[FormationSoldier] = []
var pool: Array[FormationSoldier] = []
var material: StandardMaterial3D
var dirty := true
func _ready() -> void:
 material = StandardMaterial3D.new(); material.albedo_color = Color(0.15, 0.8, 1.0)
 PlayerManager.soldiers_changed.connect(_on_count_changed); _on_count_changed(PlayerManager.get_soldier_count())
func _on_count_changed(count: int) -> void:
 while soldiers.size() < count: soldiers.append(_acquire())
 while soldiers.size() > count: _release(soldiers.back())
 dirty = true
func _acquire() -> FormationSoldier:
 var s: FormationSoldier = pool.pop_back() if not pool.is_empty() else FormationSoldier.new()
 if s.mesh == null:
  var visual := load("res://assets/toon_shooter_game_kit/Characters/Character_Soldier.gltf").instantiate()
  visual.name = "Visual"; visual.scale = Vector3.ONE * 0.9; s.add_child(visual)
  var anchor := Node3D.new(); anchor.name = "WeaponAnchor"; anchor.position = Vector3(0.4, 0.7, -0.2); visual.add_child(anchor)
  var weapon := load("res://assets/toon_shooter_game_kit/Weapons/SMG.gltf").instantiate(); weapon.scale = Vector3.ONE * 0.35; anchor.add_child(weapon)
  var muzzle := Marker3D.new(); muzzle.name = "MuzzlePoint"; muzzle.position = Vector3(0, 0, -0.8); weapon.add_child(muzzle)
  s.max_health = soldier_max_health
 if not s.is_inside_tree(): add_child(s)
 s.reset(); return s
func _release(s: FormationSoldier) -> void:
 soldiers.erase(s); s.visible = false; pool.append(s)
func get_active_target() -> FormationSoldier:
 var best: FormationSoldier
 var best_distance := INF
 for s in soldiers:
  if s.is_alive() and s.global_position.distance_squared_to(global_position) < best_distance: best = s; best_distance = s.global_position.distance_squared_to(global_position)
 return best
func damage_one_soldier(amount: int) -> void:
 var target := get_active_target()
 if target: target.take_damage(amount); PlayerManager.remove_soldiers(1)
func _process(delta: float) -> void:
 if dirty:
  for i in soldiers.size(): soldiers[i].position = formation_position(i, soldiers.size())
  dirty = false
 for s in soldiers: s.position = s.position.lerp(formation_position(soldiers.find(s), soldiers.size()), delta * 8.0)
func formation_position(index: int, count: int) -> Vector3:
 var columns := mini(6, maxi(1, ceili(sqrt(float(count)))))
 var row := index / columns; var col := index % columns
 return Vector3((col - (mini(columns, count) - 1) * 0.5) * spacing, 0.55, 1.6 + row * row_spacing)
