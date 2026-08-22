extends Node
## Presentation-only animation bridge. It reads existing gameplay state and never writes it.
var animation_player: AnimationPlayer
var last_animation := ""
var previous_scale := Vector3.ONE
func _ready() -> void:
 animation_player = _find_player(self)
 if animation_player: _play("Idle")
func _process(_delta: float) -> void:
 if not animation_player: return
 var owner_node := get_parent()
 if not is_instance_valid(owner_node): return
 var wanted := "Idle"
 if owner_node.get("state") == "DEAD": wanted = "Death"
 elif owner_node.get("state") == "CHASING": wanted = "Run"
 elif owner_node.get("state") == "ATTACKING": wanted = "Punch" if _has("Punch") else "Idle"
 elif owner_node is FormationSoldier:
  wanted = "Run" if owner_node.get_parent().get_parent().get_parent().get("velocity", Vector3.ZERO).length() > 0.1 else "Idle"
 if owner_node.scale.x < 0.95 and owner_node.get("state") != "DEAD": wanted = "HitReact"
 if _has(wanted): _play(wanted)
func _find_player(node: Node) -> AnimationPlayer:
 for child in node.get_children():
  if child is AnimationPlayer: return child
  var found := _find_player(child)
  if found: return found
 return null
func _has(name: String) -> bool: return animation_player.has_animation(name)
func _play(name: String) -> void:
 if last_animation == name: return
 animation_player.play(name); last_animation = name
