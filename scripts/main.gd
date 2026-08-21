extends Node3D
var player: CharacterBody3D
var formation: Node3D
var projectile_pool: Array[PooledProjectile] = []
var finished := false
var debug_mode := true
var active_projectiles := 0
var gates := [{"z":-12.0,"op":"multiply","value":2.0,"text":"×2"},{"z":-22.0,"op":"multiply","value":3.0,"text":"×3"},{"z":-32.0,"op":"add","value":5.0,"text":"+5"},{"z":-42.0,"op":"add","value":10.0,"text":"+10"},{"z":-52.0,"op":"subtract","value":3.0,"text":"-3"},{"z":-62.0,"op":"subtract","value":5.0,"text":"-5"},{"z":-72.0,"op":"divide","value":2.0,"text":"÷2"}]
func _ready() -> void:
 player = $Player; formation = $Formation
 var enemy_scene := preload("res://scenes/enemy/Enemy.tscn"); EnemyManager.setup(enemy_scene, formation)
 for z in [-30.0, -55.0]:
  for x in [-2.0, 0.0, 2.0]: EnemyManager.spawn_enemy(Vector3(x, 0.8, z), player, formation)
 for i in 30: projectile_pool.append(_new_projectile())
 for g in gates: _make_gate(g)
 PlayerManager.soldiers_changed.connect(_on_soldiers_changed)
 _on_soldiers_changed(PlayerManager.get_soldier_count())
 $HUD/Restart.pressed.connect(func(): get_tree().reload_current_scene())
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
 var mesh := MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = .12; sphere.height = .24; mesh.mesh = sphere; p.add_child(mesh); var shape := CollisionShape3D.new(); var s := SphereShape3D.new(); s.radius = .12; shape.shape = s; p.add_child(shape); p.area_entered.connect(p.hit); add_child(p); return p
func _return_projectile(p: PooledProjectile) -> void:
 if not projectile_pool.has(p): projectile_pool.append(p); active_projectiles = maxi(0, active_projectiles - 1)
func _on_soldiers_changed(value: int) -> void:
 if value <= 0: _end(false)
 $HUD/Soldiers.text = "Soldiers: %d" % value
func _process(_delta: float) -> void:
 formation.global_position = player.global_position
 if not finished and player.global_position.z <= -82: _end(PlayerManager.get_soldier_count() > 0)
func _end(won: bool) -> void:
 finished = true; player.set_physics_process(false)
 for enemy in EnemyManager.active: enemy.set_physics_process(false)
 for projectile in projectile_pool: projectile.release()
 $HUD/Result.text = "YOU WIN" if won else "YOU LOSE"; $HUD/Result.visible = true; $HUD/Restart.visible = true
