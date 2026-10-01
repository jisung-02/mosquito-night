class_name RoomProps
extends RefCounted
## Furniture contact points are measured in the bedroom's 1280 x 720 canvas.
const POSITIONS: Dictionary = {
	"trap": Vector2(1106, 333),
	"flytrap": Vector2(177, 392),
	"sundew": Vector2(784, 363),
	"fan": Vector2(1146, 248),
}
const WIDTHS: Dictionary = {"trap": 53.0, "flytrap": 66.0, "sundew": 58.0}
const FOOT_WIDTHS: Dictionary = {"trap": 22.0, "flytrap": 18.0, "sundew": 17.0}

static func sprite_rect(id: String, size: Vector2, visible: Rect2i) -> Rect2:
	var scale_factor: float = float(WIDTHS[id]) / maxf(1, visible.size.x)
	# Anchor opaque pixels to the furniture, not the transparent canvas edge.
	return Rect2(Vector2(-size.x * 0.5, -float(visible.end.y)) * scale_factor, size * scale_factor)

static func tint(id: String) -> Color:
	return Color(0.80, 0.74, 0.65) if id == "flytrap" else Color(0.67, 0.73, 0.83)

static func wind_strength(pos: Vector2, level: int) -> float:
	if level <= 0:
		return 0.0
	var direction: Vector2 = Vector2(-1.0, 0.22).normalized()
	var offset: Vector2 = pos - Vector2(POSITIONS.fan)
	var distance: float = offset.dot(direction)
	if distance < 0 or distance > 550:
		return 0.0
	var across: float = absf(offset.cross(direction))
	var width: float = 75.0 + distance * 0.25
	var strength: float = (0.16 + clampi(level, 1, 3) * 0.08) * (1.0 - smoothstep(320, 550, distance))
	return strength * (1.0 - smoothstep(width * 0.45, width, across))
