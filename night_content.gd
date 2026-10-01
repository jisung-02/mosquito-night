class_name NightContent
extends RefCounted
## Different pressures and optional goals within the same bedroom and 60 seconds.
const COLLECTION: Array[Dictionary] = [
	{"name": "집모기", "detail": "천천히 날다 잠깐 머뭅니다."},
	{"name": "빠른 모기", "detail": "짧게 가속하며 방을 오갑니다."},
	{"name": "황금 모기", "detail": "드물게 나타나는 30점 모기입니다."},
	{"name": "경계형", "detail": "움직이는 손과 도구를 피합니다."},
	{"name": "끈질긴 모기", "detail": "두 번 타격 · 전기채는 한 번입니다."},
	{"name": "작은 모기", "detail": "창가에서 함께 들어오는 작은 표적입니다."},
	{"name": "잠복형", "detail": "벽에 잠시 앉아 쉬고, 손이 다가오면 다시 날아갑니다."},
]

static func pattern(night: int) -> int:
	return -1 if night < 3 else (night - 3) % 4

static func name_for(night: int) -> String:
	match pattern(night):
		0: return "창가의 떼"
		1: return "예민한 날갯짓"
		2: return "끈질긴 밤"
		3: return "짧은 틈"
	return "조용한 밤"

static func goal(night: int) -> Dictionary:
	if night == 1:
		return {"stat": "manual", "target": 8, "reward": 40, "text": "직접 8마리 잡기"}
	if night == 2:
		return {"stat": "combo", "target": 4, "reward": 50, "text": "4연속 포획"}
	match pattern(night):
		0:
			var count: int = mini(32, 20 + int((night - 3) / 4.0) * 2)
			return {"stat": "kills", "target": count, "reward": 80, "text": "%d마리 잡기" % count}
		1: return {"stat": "cautious", "target": 3, "reward": 90, "text": "경계형 3마리 잡기"}
		2: return {"stat": "stubborn", "target": 3, "reward": 100, "text": "끈질긴 모기 3마리 잡기"}
	return {"stat": "manual", "target": 12, "reward": 110, "text": "직접 12마리 잡기"}

static func spawn_interval(base: float, night: int, screen: int) -> float:
	var pressure: float = 0.90 if pattern(night) == 3 else 1.0
	return maxf(0.34, base * pressure * (1.0 + clampi(screen, 0, 3) * 0.10))

static func bite_delay(base: float, night: int) -> float:
	return maxf(5.5, base * (0.84 if pattern(night) == 3 else 1.0))

static func cautious_chance(base: float, night: int) -> float:
	return minf(0.22, base + (0.10 if pattern(night) == 1 else 0.0))

static func stubborn_chance(base: float, night: int) -> float:
	return minf(0.21, base + (0.13 if pattern(night) == 2 else 0.0))

static func small_chance(night: int) -> float:
	return 0.08 if pattern(night) == 0 else (0.04 if night >= 7 else 0.0)

static func wave_size(night: int, screen: int) -> int:
	return maxi(1, mini(5, 3 + int((night - 3) / 8.0)) - clampi(screen, 0, 3))
