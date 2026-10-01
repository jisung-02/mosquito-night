class_name MosquitoHitGeometry
extends RefCounted
## Rendering and contact use the same sprite pivot, size and transform.
const BUG_RECT: Rect2 = Rect2(-60, -44, 120, 120)
const CONTACT_GRACE: float = 2.0
const OUTLINE_STEPS: int = 24
const BUG_PARTS: Array[Dictionary] = [
	{"center": Vector2(0, 19), "radii": Vector2(8, 30)},
	{"center": Vector2(0, -9), "radii": Vector2(6, 8)},
	{"center": Vector2(-18, 4), "radii": Vector2(19, 10)},
	{"center": Vector2(18, 4), "radii": Vector2(19, 10)},
]

static func tool_layout(tool: String, reach: float, texture_size: Vector2) -> Dictionary:
	# Only exposed newsprint strikes; the gripping hand and forearm are excluded.
	var pivot: Vector2 = Vector2(0.54, 0.31)
	var normalized_radii: Vector2 = Vector2(0.115, 0.255)
	var aspect: float = texture_size.y / texture_size.x
	if tool == "electric":
		pivot = Vector2(0.5, 0.255)
		normalized_radii = Vector2(0.35, 0.232)
	elif tool == "hand":
		pivot = Vector2(0.53, 0.56)
		normalized_radii = Vector2(0.20, 0.19)
		aspect = 151.0 / 112.0
	var width: float = reach / maxf(normalized_radii.x, normalized_radii.y * aspect)
	var size: Vector2 = Vector2(width, width * aspect)
	return {"rect": Rect2(-pivot * size, size), "radii": normalized_radii * size}

static func tool_pose(pos: Vector2, tool: String, _stroke: float = 0.0, idle_roll: float = 0.0) -> Transform2D:
	# Rest and target contact share this pose; WeaponSwing supplies wrist rotation.
	var angle: float = 0.0 if tool == "hand" else -0.24
	return Transform2D(angle + idle_roll, pos)

static func bug_pose(bug: Dictionary) -> Transform2D:
	var transform: Transform2D = Transform2D(float(bug.rotation), bug.pos)
	var scale_factor: float = float(bug.body_size) / 120.0
	transform.x *= scale_factor
	transform.y *= scale_factor
	return transform

static func bug_outlines(bug: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var transform: Transform2D = bug_pose(bug)
	# A two-pixel allowance makes small, antialiased wing edges forgiving.
	# Thin legs and the empty square surrounding the sprite are excluded.
	var padding: float = CONTACT_GRACE / (float(bug.body_size) / 120.0)
	for part: Dictionary in BUG_PARTS:
		result.append(ellipse_outline(part.center, part.radii + Vector2.ONE * padding, transform))
	return result

static func ellipse_outline(center: Vector2, radii: Vector2, transform: Transform2D) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(OUTLINE_STEPS):
		points.append(transform * (center + Vector2.from_angle(index * TAU / OUTLINE_STEPS) * radii))
	return points

static func contact(bug: Dictionary, pose: Transform2D, radii: Vector2) -> Dictionary:
	var target_bound: float = float(bug.body_size) * 0.46 + CONTACT_GRACE
	var tool_bound: float = maxf(radii.x, radii.y) * maxf(pose.x.length(), pose.y.length())
	if bug.pos.distance_squared_to(pose.origin) > pow(target_bound + tool_bound, 2):
		return {"hit": false, "point": Vector2.ZERO}
	var inverse: Transform2D = pose.affine_inverse()
	for outline: PackedVector2Array in bug_outlines(bug):
		var normalized: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in outline:
			normalized.append((inverse * point) / radii)
		if Geometry2D.is_point_in_polygon(Vector2.ZERO, normalized):
			return {"hit": true, "point": pose.origin}
		for index: int in range(normalized.size()):
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, normalized[index], normalized[(index + 1) % normalized.size()])
			if closest.length_squared() <= 1.000001:
				return {"hit": true, "point": pose * (closest * radii)}
	return {"hit": false, "point": Vector2.ZERO}
