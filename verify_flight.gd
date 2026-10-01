extends SceneTree
const Flight = preload("res://mosquito_flight.gd")

func _initialize() -> void:
	var trajectories: Array[Dictionary] = []
	for fps: int in [30, 60, 120]:
		var bug: Dictionary = Flight.create(1, 0, Vector2(650, 360), 49287)
		var hover_seen: bool = false
		var dart_seen: bool = false
		for frame: int in range(fps * 30):
			var before_velocity: Vector2 = bug.velocity
			var before_angle: float = bug.rotation
			var before_size: float = bug.body_size
			Flight.advance(bug, 1.0 / fps)
			assert((bug.velocity - before_velocity).length() <= Flight.MAX_ACCELERATION / fps + 0.001, "bounded acceleration")
			assert(absf(angle_difference(before_angle, bug.rotation)) <= Flight.MAX_YAW_RATE / fps + 0.001, "bounded body rotation")
			assert(absf(bug.rotation) < 0.55, "no continuous body spinning")
			assert(absf(bug.body_size - before_size) < 0.4, "perspective scale stays smooth")
			assert(bug.body_size >= 42 and bug.body_size <= 70, "readable mosquito size bounds")
			assert(Flight.BOUNDS.has_point(bug.pos), "soft avoidance keeps insect in room")
			hover_seen = hover_seen or bug.mode == "hover"
			dart_seen = dart_seen or bug.mode == "dart"
		assert(hover_seen and dart_seen, "hover and short dart behaviors")
		trajectories.append(bug)
	assert(trajectories[0].pos.distance_to(trajectories[1].pos) < 0.2, "30 and 60 fps equivalent paths")
	assert(trajectories[1].pos.distance_to(trajectories[2].pos) < 0.2, "60 and 120 fps equivalent paths")
	var edge: Dictionary = Flight.create(2, 1, Vector2(1180, 580), 93)
	edge.velocity = Vector2(90, 35)
	edge.heading = 0.2
	for frame: int in range(1200):
		Flight.advance(edge, 1.0 / 60)
		assert(Flight.BOUNDS.has_point(edge.pos), "outward edge approach turns smoothly")
	print("PASS: 30/60/120 fps equivalent flight; acceleration limits; bank limits; hover/dart; smooth depth scale; room boundaries; edge steering")
	quit()
