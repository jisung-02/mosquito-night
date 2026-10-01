extends SceneTree
const Motion = preload("res://scene_motion.gd")

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		assert(ok, message)

func _initialize() -> void:
	for id: String in ["flytrap", "sundew"]:
		for time: float in [0.0, 0.6, 2.0, 5.0]:
			for leaf: int in range(4):
				for uv: Vector2 in [Vector2(0.2, 0.8), Vector2(0.5, 1), Vector2(0.8, 0.7)]:
					_check(Motion.deform(id, uv, time, time, leaf).is_equal_approx(uv), "rigid plant pots stay fixed")
		_check(Motion.closing(0.6, "flytrap") > 0.99, "trap lobes close quickly")
	_check(Motion.closing(0.6, "sundew") < Motion.closing(2, "sundew"), "sundew curls more slowly")
	_check(Motion.closing(-1, "flytrap") == 0 and Motion.closing(6, "flytrap") == 0, "trap resting and reopening")
	var edge: Vector2 = Motion.FLYTRAP_MOUTHS[0] + Vector2(0, 0.07)
	_check(Motion.deform("flytrap", edge, 1, 0.7).distance_to(Motion.deform("flytrap", edge, 1, -1)) > 0.035, "jaw geometry folds")
	_check(Motion.deform("hand", Vector2(0.53, 0.56), 0, 1).is_equal_approx(Vector2(0.53, 0.56)), "palm collision anchor stays fixed")
	_check(Motion.deform("newspaper", Vector2(0.54, 0.3), 0, 0).is_equal_approx(Vector2(0.54, 0.3)), "paper contact shape stays aligned with its hitbox")
	_check(Motion.deform("newspaper", Vector2(0.54, 0.2), 0, 1).x > 0.55, "paper bends on recoil")
	_check(Motion.deform("newspaper", Vector2(0.6, 0.8), 0, 1).is_equal_approx(Vector2(0.6, 0.8)), "paper grip and arm remain rigid")
	_check(Motion.deform("hand", Vector2(0.5, 0.1), 0, 1).y > 0.11, "fingers flex on impact")
	_check(Motion.deform("mosquito", Vector2(0.5, 0.4), 3, -1).is_equal_approx(Vector2(0.5, 0.4)), "mosquito central body stays aligned with hitbox")
	_check(Motion.deform("mosquito", Vector2(0.9, 0.5), 1, -1).distance_to(Motion.deform("mosquito", Vector2(0.9, 0.5), 2, -1)) > 0.001, "legs move independently")
	_check(Motion.deform("dragonfly_body", Vector2(0.5, 0.9), 1, -1).distance_to(Motion.deform("dragonfly_body", Vector2(0.5, 0.9), 2, -1)) > 0.001, "dragonfly tail moves independently")
	for index: int in range(5):
		var first: PackedVector2Array = Motion.larva_path(index, 0, 100, 100)
		_check(first.size() == 13, "segmented larva spine")
		_check(first[-1].distance_to(Motion.larva_path(index, 1, 100, 100)[-1]) > 0.1, "larvae wriggle")
		for frame: int in range(60):
			for point: Vector2 in Motion.larva_path(index, frame / 3.0, 100, 100):
				var uv: Vector2 = Vector2(point.x / 100 + 0.5, point.y / 100 + 1)
				_check(uv.x > 0.2 and uv.x < 0.85 and uv.y >= 0.5 and uv.y < 0.92, "larvae remain inside jar water")
	var paths: Array[Dictionary] = []
	for fps: int in [30, 60, 120]:
		var state: Dictionary = {"pos": Vector2(600, 200), "velocity": Vector2.ZERO, "angle": 0.0, "bank": 0.0}
		for frame: int in range(fps * 3):
			var old_velocity: Vector2 = state.velocity
			var old_angle: float = state.angle
			Motion.advance_dragon(state, Vector2(820, 320), 1.0 / fps, true, 1)
			_check(Vector2(state.velocity).length() <= 325.01, "pursuit speed bounded")
			_check(old_velocity.distance_to(state.velocity) <= 1200.0 / fps + 0.01, "acceleration bounded")
			_check(absf(angle_difference(old_angle, float(state.angle))) <= 4.5 / fps + 0.001, "turn speed bounded")
			_check(absf(float(state.bank)) <= 0.221, "bank bounded")
		paths.append(state)
		_check(Vector2(state.pos).distance_to(Vector2(820, 320)) < 1, "slows down on arrival")
	_check(Vector2(paths[0].pos).distance_to(paths[2].pos) < 0.05 and Vector2(paths[1].pos).distance_to(paths[2].pos) < 0.05, "30/60/120 FPS agreement")
	print("PASS: rigid plant supports; independent jaws/fingers/legs/tail; larva bounds and movement; dragonfly acceleration/turn/bank limits, arrival and frame-rate consistency")
	quit()
