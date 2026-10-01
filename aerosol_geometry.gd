class_name AerosolGeometry
extends RefCounted
## Mist and collision share a nozzle, travel distance and widening cone.
const DURATION: float = 0.65
const EXPOSURE: float = 0.16
const NOZZLE_OFFSET: Vector2 = Vector2(70, 145)

static func nozzle(aim: Vector2) -> Vector2:
	return aim + NOZZLE_OFFSET

static func outline(aim: Vector2, level: int, age: float) -> PackedVector2Array:
	var origin: Vector2 = nozzle(aim)
	var axis: Vector2 = origin.direction_to(aim)
	var normal: Vector2 = Vector2(-axis.y, axis.x)
	var reach: float = (235 + level * 25) * clampf(age / 0.12, 0, 1)
	var width: float = (43 + level * 9) * clampf(age / 0.12, 0, 1)
	return PackedVector2Array([origin - normal * 3, origin + normal * 3, origin + axis * reach + normal * width, origin + axis * reach - normal * width])

static func touches(bug: Dictionary, cone: PackedVector2Array) -> bool:
	for part: PackedVector2Array in MosquitoHitGeometry.bug_outlines(bug):
		if not Geometry2D.intersect_polygons(part, cone).is_empty():
			return true
	return false
