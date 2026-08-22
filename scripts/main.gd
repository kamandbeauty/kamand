extends Node3D
var player: CharacterBody3D
var formation: Node3D
var projectile_pool: Array[PooledProjectile] = []
var finished := false
var debug_mode := true
var active_projectiles := 0
var level_data = preload("res://resources/levels/Level1.tres")
var gate_groups: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var active_wave := 0
var wave_spawned: Array[bool] = [false, false, false]
func _ready() -> void:
 player = $Player; formation = $Formation
 var enemy_scene := preload("res://scenes/enemy/Enemy.tscn"); EnemyManager.setup(enemy_scene, formation)
 player.global_position = level_data.start_position
 gate_groups = level_data.gate_groups; waves = level_data.enemy_waves
 for i in 30: projectile_pool.append(_new_projectile())
 for group in gate_groups: _make_gate_choice(group)
 PlayerManager.soldiers_changed.connect(_on_soldiers_changed)
 _on_soldiers_changed(PlayerManager.get_soldier_count())
 $HUD/Restart.pressed.connect(func(): get_tree().reload_current_scene())
func _make_gate_choice(data: Dictionary) -> void:
 var used := [false]
 for side in [-1, 1]:
  var gate := Area3D.new(); gate.position = Vector3(side * 3.0, 2, data.z); gate.collision_layer = 2; gate.collision_mask = 1
  var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(5.5, 4, 1.0); shape.shape = box; gate.add_child(shape)
  var label := Label3D.new(); var prefix := "left_" if side < 0 else "right_"; label.text = data[prefix + "text"]; label.font_size = 64; label.position.y = 2.5; gate.add_child(label)
  gate.body_entered.connect(func(body: Node3D):
   if body == player and not used[0] and not finished:
    used[0] = true; var before := PlayerManager.get_soldier_count(); GateManager.apply_gate(StringName(data[prefix + "op"]), data[prefix + "value"]); _gate_feedback(before, PlayerManager.get_soldier_count()); gate.queue_free())
  add_child(gate)
func _gate_feedback(before: int, after: int) -> void:
 $HUD/Feedback.text = "%d → %d Soldiers" % [before, after]; $HUD/Feedback.visible = true
func _make_gate(data: Dictionary) -> void:
 var gate := Area3D.new(); gate.position = Vector3(0, 2, data.z); gate.collision_layer = 2; gate.collision_mask = 1
 var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(12, 4, 0.5); shape.shape = box; gate.add_child(shape)
 var label := Label3D.new(); label.text = data.text; label.font_size = 64; label.modulate = Color(0.2, 1, 0.4); label.position.y = 2.5; gate.add_child(label)
 gate.body_entered.connect(func(body: Node3D):
  if body == player: GateManager.apply_gate(StringName(data.op), data.value); gate.queue_free())
 add_child(gate)
func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("shoot") and not finished: shoot()
 if event is InputEventScreenDrag and not finished: player.touch_axis = clampf(event.relative.x / 80.0, -1.0, 1.0)
 if event is InputEventScreenTouch and not event.pressed: player.touch_axis = 0.0
func shoot() -> void:
 if projectile_pool.is_empty(): return
 var p: PooledProjectile = projectile_pool.pop_back()
 p.fire(player.global_position + Vector3(0, 0.4, -1)); active_projectiles += 1; p.released.connect(_return_projectile.bind(p), CONNECT_ONE_SHOT)
func _new_projectile() -> PooledProjectile:
 var p := PooledProjectile.new(); p.collision_layer = 4; p.collision_mask = 2
 var mesh := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = .12; sphere.height = .24; mesh.mesh = sphere
 var material := StandardMaterial3D.new(); material.albedo_color = Color(1.0, 0.85, 0.2); material.emission_enabled = true; material.emission = Color(1.0, 0.45, 0.05); material.emission_energy_multiplier = 3.0; mesh.material_override = material; p.add_child(mesh)
 var trail := MeshInstance3D.new(); trail.name = "Trail"; var trail_mesh := BoxMesh.new(); trail_mesh.size = Vector3(0.04, 0.04, 0.35); trail.mesh = trail_mesh; trail.material_override = material; trail.position.z = 0.18; p.add_child(trail)
 var shape := CollisionShape3D.new(); var s := SphereShape3D.new(); s.radius = .12; shape.shape = s; p.add_child(shape); p.area_entered.connect(p.hit); add_child(p); return p
func _return_projectile(p: PooledProjectile) -> void:
 if not projectile_pool.has(p): projectile_pool.append(p); active_projectiles = maxi(0, active_projectiles - 1)
func _on_soldiers_changed(value: int) -> void:
 if value <= 0: _end(false)
 $HUD/Soldiers.text = "Soldiers: %d" % value
func _process(_delta: float) -> void:
 formation.global_position = player.global_position
 if not finished:
  for i in waves.size():
   if not wave_spawned[i] and player.global_position.z <= float(waves[i]["z"]):
    wave_spawned[i] = true; active_wave = i + 1
    for x in range(int(waves[i]["count"])): EnemyManager.spawn_enemy(Vector3((x % 5 - 2) * 1.5, 0.8, player.global_position.z - 8.0 - (x / 5) * 2.0), player, formation)
  if player.global_position.z <= -100: _end(PlayerManager.get_soldier_count() > 0)
func _end(won: bool) -> void:
 finished = true; player.set_physics_process(false)
 for enemy in EnemyManager.active: enemy.set_physics_process(false)
 for projectile in projectile_pool: projectile.release()
 $HUD/Result.text = "YOU WIN" if won else "YOU LOSE"; $HUD/Result.visible = true; $HUD/Restart.visible = true
