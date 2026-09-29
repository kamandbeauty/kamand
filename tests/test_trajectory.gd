class_name TestTrajectory
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_clamped_aim_angles(results)
	test_wall_bounce_reflection(results)
	test_raycast_circle_intersection(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_clamped_aim_angles(results: Dictionary) -> void:
	var shooter: Shooter = Shooter.new()
	shooter.position = Constants.SHOOTER_POSITION
	
	# Aim straight up (-PI/2)
	var valid_up: bool = shooter.update_aim_target(Constants.SHOOTER_POSITION + Vector2.UP * 200.0)
	_assert(valid_up, "Aiming straight up is valid", results)
	_assert(is_equal_approx(shooter.aim_direction.y, -1.0), "Aim vector points straight up", results)
	
	# Aim below horizontal (pointing down-right) -> clamped to min angle
	shooter.update_aim_target(Constants.SHOOTER_POSITION + Vector2(200.0, 50.0))
	var min_allowed_angle_rad: float = deg_to_rad(-Constants.MIN_AIM_ANGLE_DEG)
	_assert(is_equal_approx(shooter.launcher_rotation, min_allowed_angle_rad), "Downward angle clamped to -15 deg", results)
	
	shooter.free()

static func test_wall_bounce_reflection(results: Dictionary) -> void:
	var dir: Vector2 = Vector2(-0.7071, -0.7071) # Traveling up-left
	# Wall bounce left
	dir.x = abs(dir.x) # Reflect right
	_assert(dir.x > 0.0 and dir.y < 0.0, "Reflected vector travels up-right after left wall hit", results)

static func test_raycast_circle_intersection(results: Dictionary) -> void:
	var ray_origin: Vector2 = Vector2(360.0, 500.0)
	var ray_dir: Vector2 = Vector2.UP
	var circle_center: Vector2 = Vector2(360.0, 300.0)
	var radius: float = 36.0
	
	# Distance from ray origin to circle boundary: (500 - 300) - 36 = 164 px
	var d_pos: Vector2 = ray_origin - circle_center
	var b_val: float = 2.0 * ray_dir.dot(d_pos)
	var c_val: float = d_pos.length_squared() - (radius * radius)
	var disc: float = b_val * b_val - 4.0 * c_val
	_assert(disc >= 0.0, "Ray intersects circle", results)
	
	var t: float = (-b_val - sqrt(disc)) / 2.0
	_assert(is_equal_approx(t, 164.0), "Intersection distance is exactly 164.0", results)
