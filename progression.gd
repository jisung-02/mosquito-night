class_name NightProgression
extends RefCounted
## Persistent earned coins and purchase levels; test saves use a separate path.
const CATALOG: Array[Dictionary] = [
	{"id": "swatter", "name": "말아 쥔 신문지", "detail": "손뼉 다음 단계 · 길고 좁은 타격 면 · 빠른 휘두르기", "price": 40, "max": 1, "asset": "newspaper"},
	{"id": "electric", "name": "전기모기채", "detail": "신문지 다음 단계 · 접촉 방전 · 넓은 그물", "price": 80, "max": 3, "asset": "electric", "requires": "swatter"},
	{"id": "reach", "name": "도구 강화", "detail": "타격 면 +8 · 신문지 / 전기모기채 모두 적용", "price": 60, "max": 4, "asset": "newspaper", "requires": "swatter"},
	{"id": "trap", "name": "흡입식 포충기", "detail": "책상에 설치 · 5초마다 근처 모기 자동 포획", "price": 130, "max": 3, "asset": "trap"},
	{"id": "flytrap", "name": "파리지옥", "detail": "협탁에 배치 · 잎에 닿으면 덫을 닫아 포획", "price": 100, "max": 3, "asset": "flytrap"},
	{"id": "sundew", "name": "끈끈이주걱", "detail": "창틀에 배치 · 붙은 모기를 잎을 말아 포획", "price": 170, "max": 3, "asset": "sundew"},
	{"id": "dragonfly", "name": "잠자리 동료", "detail": "방을 날아다니며 모기 추격 · 3.5초 간격", "price": 220, "max": 3, "asset": "dragonfly"},
	{"id": "fan", "name": "선풍기", "detail": "책상의 선풍기 가동 · 바람 안의 모기 감속 · 물리기까지 시간 증가", "price": 150, "max": 3, "asset": "fan", "requires": "swatter"},
]
var wallet: int = 0
var best: int = 0
var night: int = 1
var total_earned: int = 0
var equipped_tool: String = "hand"
var levels: Dictionary[String, int] = {}
var save_path: String = "user://progression.json"

func _init(path: String = "user://progression.json") -> void:
	save_path = path
	for item: Dictionary in CATALOG:
		levels[item.id] = 0

func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	wallet = maxi(0, int(data.get("wallet", 0)))
	best = maxi(0, int(data.get("best", 0)))
	night = maxi(1, int(data.get("night", 1)))
	total_earned = maxi(0, int(data.get("total_earned", wallet)))
	var saved_levels: Variant = data.get("levels", {})
	if saved_levels is Dictionary:
		for item: Dictionary in CATALOG:
			levels[item.id] = clampi(int(saved_levels.get(item.id, 0)), 0, int(item.max))
	# The newspaper retains the swatter save key so existing purchases survive.
	if not data.has("version"):
		for level: int in levels.values():
			if level > 0:
				levels["swatter"] = 1
		for id: String in ["trap", "flytrap", "sundew", "dragonfly"]:
			if levels[id] > 0:
				levels["electric"] = maxi(1, levels["electric"])
	equipped_tool = String(data.get("equipped_tool", "electric" if levels["electric"] > 0 else ("swatter" if levels["swatter"] > 0 else "hand")))
	if not owns_tool(equipped_tool):
		equipped_tool = "hand"
	if int(data.get("version", 0)) < 3 and saved_levels is Dictionary and saved_levels.has("nursery"):
		var removed_level: int = clampi(int(saved_levels.nursery), 0, 3)
		# Refund each purchased tier once and persist the migration immediately.
		wallet += int(150 * removed_level * (removed_level + 1) / 2.0)
		save()

func save() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 3, "wallet": wallet, "best": best, "night": night, "total_earned": total_earned, "levels": levels, "equipped_tool": equipped_tool}))

func earn(amount: int) -> void:
	if amount <= 0:
		return
	wallet += amount
	total_earned += amount

func cost(id: String) -> int:
	for item: Dictionary in CATALOG:
		if item.id == id:
			return int(item.price) * (levels[id] + 1)
	return -1

func purchase(id: String) -> bool:
	if not requirement(id).is_empty():
		return false
	for item: Dictionary in CATALOG:
		if item.id != id:
			continue
		var price: int = cost(id)
		if levels[id] >= int(item.max) or wallet < price:
			return false
		wallet -= price
		levels[id] += 1
		if id in ["swatter", "electric"]:
			equipped_tool = id
		save()
		return true
	return false

func requirement(id: String) -> String:
	var required: String = ""
	for item: Dictionary in CATALOG:
		if item.id == id:
			required = String(item.get("requires", ""))
	if id in ["trap", "flytrap", "sundew", "dragonfly"]:
		required = "electric"
	if not required.is_empty() and levels.get(required, 0) <= 0:
		return "신문지 먼저 구매" if required == "swatter" else "전기모기채 먼저 구매"
	return ""

func owns_tool(id: String) -> bool:
	return id == "hand" or (id in ["swatter", "electric"] and levels.get(id, 0) > 0)

func equip(id: String) -> bool:
	if not owns_tool(id):
		return false
	equipped_tool = id
	save()
	return true

func tool_name() -> String:
	match equipped_tool:
		"swatter": return "말아 쥔 신문지"
		"electric": return "전기모기채"
	return "맨손"

func reach() -> float:
	if equipped_tool == "hand":
		return 29.0
	return 47.0 + levels["reach"] * 8.0 + (levels["electric"] * 12.0 if equipped_tool == "electric" else 0.0)

func cooldown() -> float:
	if equipped_tool == "hand":
		return 0.32
	if equipped_tool == "swatter":
		return 0.22
	return maxf(0.08, 0.18 - levels["electric"] * 0.03)

func interval(id: String) -> float:
	var base: float = 6.0
	match id:
		"trap": base = 5.0
		"flytrap": base = 6.0
		"sundew": base = 8.0
		"dragonfly": base = 3.5
	return base / (1.0 + maxf(0, levels[id] - 1) * 0.3)
