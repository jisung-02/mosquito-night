class_name ClapMotion
extends RefCounted
## One contact event between closing and separating palms.
const DURATION: float = 0.32
const CONTACT_TIME: float = 0.075
const HAND_RECT: Rect2 = Rect2(-118 * 0.62, -177 * 0.44, 118, 177)

static func openness(age: float) -> float:
	if age < 0:
		return 1.0
	if age <= CONTACT_TIME:
		return 1.0 - smoothstep(0, CONTACT_TIME, age)
	return smoothstep(0.105, 0.30, age)

static func palm_pose(center: Vector2, side: int, age: float, roll: float) -> Transform2D:
	var open: float = openness(age)
	var distance: float = 12 + 45 * open
	var common: Transform2D = Transform2D(roll, center)
	var pose: Transform2D = Transform2D(-side * open * 0.08, Vector2(side * distance, open * 3))
	pose.x *= -side * (0.65 + open * 0.20)
	return common * pose
