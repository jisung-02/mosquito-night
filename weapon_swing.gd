class_name WeaponSwing
extends RefCounted
## The wrist stays fixed while the exposed striking face passes through the aim.
const WINDUP_END: float = 0.14
const ACTIVE_START: float = 0.25
const CONTACT: float = 0.32
const ACTIVE_END: float = 0.40
const FOLLOW_END: float = 0.50

static func active(progress: float) -> bool:
	return progress >= ACTIVE_START and progress <= ACTIVE_END

static func offset_angle(tool: String, progress: float) -> float:
	var u: float = clampf(progress, 0, 1)
	var back: float = -0.42 if tool == "swatter" else -0.30
	var follow: float = 0.27 if tool == "swatter" else 0.20
	if u < WINDUP_END:
		return back * smoothstep(0, WINDUP_END, u)
	if u < CONTACT:
		var t: float = (u - WINDUP_END) / (CONTACT - WINDUP_END)
		return lerpf(back, 0, t * t)
	if u < FOLLOW_END:
		var t: float = (u - CONTACT) / (FOLLOW_END - CONTACT)
		return follow * (1 - pow(1 - t, 2))
	return follow * (1 - smoothstep(FOLLOW_END, 1, u))

static func grip(layout: Dictionary, tool: String) -> Vector2:
	var uv: Vector2 = Vector2(0.64, 0.86) if tool == "swatter" else Vector2(0.5, 0.86)
	return layout.rect.position + layout.rect.size * uv

static func pose(center: Vector2, tool: String, layout: Dictionary, progress: float, roll: float) -> Transform2D:
	var base: Transform2D = MosquitoHitGeometry.tool_pose(center, tool, 0, roll)
	var pivot: Vector2 = grip(layout, tool)
	var wrist: Vector2 = base * pivot
	var result: Transform2D = Transform2D(base.get_rotation() + offset_angle(tool, progress), Vector2.ZERO)
	result.origin = wrist - result.basis_xform(pivot)
	return result

static func paper_flex(progress: float) -> float:
	if progress < 0.20:
		return sin(clampf(progress / 0.20, 0, 1) * PI) * 0.45
	if progress > 0.42:
		return sin(clampf((progress - 0.42) / 0.58, 0, 1) * PI) * 0.9
	return 0.0
