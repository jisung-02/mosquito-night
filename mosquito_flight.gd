class_name MosquitoFlight
extends RefCounted
## Correlated wander, limited acceleration and soft wall avoidance.
## Integration uses small steps so flight does not depend on display refresh rate.
const BOUNDS: Rect2 = Rect2(55, 105, 1170, 535)
const MAX_ACCELERATION: float = 210.0
const MAX_YAW_RATE: float = 2.0

static func create(id: int, kind: int, pos: Vector2, seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var heading: float = rng.randf_range(-PI, PI)
	var depth: float = rng.randf_range(0.05, 0.95)
	var body_angle: float = rng.randf_range(-0.2, 0.2)
	return {"id": id, "kind": kind, "pos": pos, "rotation": body_angle, "body_angle": body_angle,
		"velocity": Vector2.from_angle(heading) * 40, "heading": heading,
		"rng": rng, "phase": rng.randf_range(0, 20), "seed": rng.randf() * TAU,
		"life": 10.0 if kind == 0 else 7.0,
		"speed_scale": 1.0,
		"hp": 2 if kind == 4 else 1, "hurt_timer": 0.0,
		"rest_target": Vector2.INF, "mode": "cruise", "mode_timer": rng.randf_range(0.7, 2.0),
		"turn": 0.0, "turn_target": 0.0, "noise_timer": 0.0,
		"depth": depth, "depth_target": depth, "depth_timer": rng.randf_range(2, 4),
		"wing_energy": 0.8, "body_size": lerpf(42, 70, depth) * (1.15 if kind == 4 else (0.82 if kind == 5 else 1.0))}

static func advance(bug: Dictionary, delta: float, attractor: Vector2 = Vector2.INF, threat: Vector2 = Vector2.INF) -> void:
	var left: float = maxf(0, delta)
	while left > 0.000001:
		var step: float = minf(left, 1.0 / 120.0)
		_step(bug, step, attractor, threat)
		left -= step

static func _step(bug: Dictionary, delta: float, attractor: Vector2, threat: Vector2) -> void:
	var rng: RandomNumberGenerator = bug.rng
	bug.hurt_timer = maxf(0, float(bug.get("hurt_timer", 0.0)) - delta)
	bug.phase += delta * (0.08 if bug.mode == "rest" else 1.0)
	bug.mode_timer -= delta
	if float(bug.mode_timer) <= 0:
		var choice: float = rng.randf()
		bug.mode = "hover" if choice < 0.24 else ("dart" if choice > (0.83 if int(bug.kind) == 3 else 0.88) else "cruise")
		bug.mode_timer = rng.randf_range(0.8, 1.5) if bug.mode == "hover" else rng.randf_range(1.4, 3.2)
		if int(bug.kind) == 6 and choice < 0.55:
			bug.mode = "land"
			var left_wall: Vector2 = Vector2(clampf(Vector2(bug.pos).x, 270, 355), clampf(Vector2(bug.pos).y, 150, 305))
			var right_wall: Vector2 = Vector2(clampf(Vector2(bug.pos).x, 1040, 1100), clampf(Vector2(bug.pos).y, 140, 185))
			bug.rest_target = left_wall if Vector2(bug.pos).distance_to(left_wall) < Vector2(bug.pos).distance_to(right_wall) else right_wall
			bug.mode_timer = 5.0
		if bug.mode == "dart":
			bug.mode_timer = rng.randf_range(0.35, 0.65)
	bug.noise_timer -= delta
	if float(bug.noise_timer) <= 0:
		bug.turn_target = rng.randf_range(-1.1, 1.1)
		bug.noise_timer = rng.randf_range(0.45, 1.1)
	bug.turn = lerpf(float(bug.turn), float(bug.turn_target), 1 - exp(-delta * 2.8))
	bug.heading += float(bug.turn) * delta
	var speed: float = 58.0 if int(bug.kind) in [0, 4] else 78.0
	if bug.mode == "hover":
		speed = 8.0
	elif bug.mode == "dart":
		speed *= 1.65
	var desired: Vector2 = Vector2.from_angle(float(bug.heading)) * speed
	# Drift is a few pixels, not a repeated room-wide sine-wave path.
	desired += Vector2(sin(float(bug.phase) * 3.1 + float(bug.seed)), cos(float(bug.phase) * 2.7)) * 3.5
	var pos: Vector2 = bug.pos
	var wall: Vector2 = Vector2.ZERO
	var margin: float = 115.0
	wall.x += maxf(0, (BOUNDS.position.x + margin - pos.x) / margin)
	wall.x -= maxf(0, (pos.x - (BOUNDS.end.x - margin)) / margin)
	wall.y += maxf(0, (BOUNDS.position.y + margin - pos.y) / margin)
	wall.y -= maxf(0, (pos.y - (BOUNDS.end.y - margin)) / margin)
	desired += wall * 165.0
	if attractor.is_finite() and pos.distance_to(attractor) < 350:
		desired += pos.direction_to(attractor) * 26
		if pos.distance_to(attractor) < 85:
			# Slow down onto a landing surface instead of circling through it.
			desired = pos.direction_to(attractor) * minf(42, pos.distance_to(attractor) * 2.2)
	if bug.mode == "land":
		desired = pos.direction_to(bug.rest_target) * minf(60, pos.distance_to(bug.rest_target) * 2.5)
		if pos.distance_to(bug.rest_target) < 4 and Vector2(bug.velocity).length() < 10:
			bug.mode = "rest"
			bug.mode_timer = rng.randf_range(1.8, 3.2)
	if bug.mode == "rest":
		desired = Vector2.ZERO
	if threat.is_finite() and pos.distance_to(threat) < 100:
		if bug.mode in ["land", "rest"]:
			bug.mode = "dart"
			bug.mode_timer = 0.5
		desired += threat.direction_to(pos) * 100
	var speed_scale: float = clampf(float(bug.get("speed_scale", 1.0)), 0.45, 1.6)
	desired *= speed_scale
	var velocity: Vector2 = bug.velocity
	velocity = velocity.move_toward(desired.limit_length(145 * speed_scale), MAX_ACCELERATION * speed_scale * delta)
	bug.velocity = velocity
	bug.pos += velocity * delta
	if wall.length_squared() > 0.04 and velocity.length() > 18:
		bug.heading = lerp_angle(float(bug.heading), velocity.angle(), 1 - exp(-delta * 1.8))
	# A screen-space insect can drift sideways. Bank slightly rather than spin
	# the flat body image to every velocity direction like a top-down vehicle.
	var bank: float = clampf(-velocity.x * 0.0024, -0.28, 0.28)
	var target_angle: float = float(bug.body_angle) + bank
	var difference: float = angle_difference(float(bug.rotation), target_angle)
	bug.rotation += clampf(difference * (1 - exp(-delta * 4)), -MAX_YAW_RATE * delta, MAX_YAW_RATE * delta)
	bug.depth_timer -= delta
	if float(bug.depth_timer) <= 0:
		bug.depth_target = clampf(float(bug.depth) + rng.randf_range(-0.28, 0.28), 0.0, 1.0)
		bug.depth_timer = rng.randf_range(3, 5)
	bug.depth = lerpf(float(bug.depth), float(bug.depth_target), 1 - exp(-delta * 0.55))
	bug.body_size = lerpf(42, 70, float(bug.depth)) * (1.15 if int(bug.kind) == 4 else (0.82 if int(bug.kind) == 5 else 1.0))
	bug.wing_energy = lerpf(float(bug.wing_energy), 0.0 if bug.mode == "rest" else (0.72 if bug.mode == "hover" else 1.0), 1 - exp(-delta * 4))
