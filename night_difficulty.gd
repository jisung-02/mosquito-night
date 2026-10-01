class_name NightDifficulty
extends RefCounted
## Capped night progression with a short warm-up before each night's pressure rises.
const MAX_STAGE: int = 12

static func stage(night: int) -> float:
	return float(clampi(night, 1, MAX_STAGE) - 1)

static func pressure(elapsed: float) -> float:
	return clampf((elapsed - 12.0) / 48.0, 0.0, 1.0)

static func spawn_interval(night: int, elapsed: float) -> float:
	return maxf(0.38, 1.7 / (1.0 + stage(night) * 0.16) / (1.0 + pressure(elapsed) * 0.52))

static func active_limit(night: int) -> int:
	return 5 + int(stage(night) * 0.65)

static func initial_count(night: int) -> int:
	return mini(4, 2 + int(stage(night) / 3.0))

static func speed_scale(night: int, elapsed: float) -> float:
	return 1.0 + stage(night) * 0.045 + pressure(elapsed) * 0.1

static func bite_delay(night: int, elapsed: float, kind: int) -> float:
	var delay: float = 14.0 - stage(night) * 0.4 - pressure(elapsed) * 1.8
	return maxf(7.2, delay * (1.0 if kind in [0, 4] else 0.84))

static func fast_chance(night: int, elapsed: float) -> float:
	return 0.08 + stage(night) * 0.023 + pressure(elapsed) * 0.04

static func golden_chance(night: int) -> float:
	return 0.08 + stage(night) * 0.004

static func cautious_chance(night: int) -> float:
	return 0.0 if night < 3 else minf(0.12, 0.04 + stage(night) * 0.008)

static func stubborn_chance(night: int) -> float:
	return 0.0 if night < 5 else minf(0.08, 0.02 + stage(night) * 0.005)
