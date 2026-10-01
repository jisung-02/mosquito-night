extends SceneTree
const Difficulty = preload("res://night_difficulty.gd")
const Flight = preload("res://mosquito_flight.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _count_spawns(game: Node2D, night: int) -> int:
	game._progress.night = night
	game._over = false
	game._restart()
	var count: int = 0
	for tick: int in range(600):
		game._bugs.clear()
		game._process(0.1)
		count += game._bugs.size()
	return count

func _verify() -> void:
	_check("--verify-game" in OS.get_cmdline_user_args(), "isolated test saves required")
	for night: int in range(1, 12):
		for elapsed: float in [0.0, 30.0, 60.0]:
			_check(Difficulty.spawn_interval(night + 1, elapsed) <= Difficulty.spawn_interval(night, elapsed), "later nights increase spawn pressure")
			_check(Difficulty.speed_scale(night + 1, elapsed) > Difficulty.speed_scale(night, elapsed), "later nights increase flight speed")
			_check(Difficulty.bite_delay(night + 1, elapsed, 0) < Difficulty.bite_delay(night, elapsed, 0), "later nights shorten capture window")
	_check(Difficulty.pressure(0) == Difficulty.pressure(12), "twelve second warm-up")
	_check(Difficulty.spawn_interval(1, 60) < Difficulty.spawn_interval(1, 0), "pressure rises within a night")
	_check(Difficulty.speed_scale(999999, 60) < 1.6 and Difficulty.spawn_interval(999999, 60) >= 0.38, "old high-night saves remain bounded")
	_check(Difficulty.speed_scale(999999, 60) == Difficulty.speed_scale(12, 60), "difficulty plateaus at stage twelve")
	_check(Difficulty.bite_delay(999999, 60, 1) >= 7.2 and Difficulty.active_limit(999999) <= 12, "late game keeps response time and crowd limit")
	seed(4132)
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for id: String in game._progress.levels:
		game._progress.levels[id] = 0
	game._progress.night = 1
	game._over = false
	game._restart()
	_check(game._bugs.size() == 2 and game._bugs[0].life >= 11.7, "beginner opening gives time to aim")
	game._intro = false
	var first: int = _count_spawns(game, 1)
	var middle: int = _count_spawns(game, 6)
	var late: int = _count_spawns(game, 12)
	_check(first < middle and middle < late, "actual sixty-second spawn count increases")
	game._progress.night = 1
	game._over = false
	game._restart()
	for tick: int in range(200):
		for bug: Dictionary in game._bugs:
			bug.life = 100.0
		game._process(0.1)
		_check(game._bugs.size() <= 5, "first night never exceeds five active mosquitoes")
	game._progress.wallet = 321
	game._progress.levels.swatter = 1
	game._health = 0
	game._finish()
	game._restart()
	_check(game._progress.night == 1 and game._progress.wallet == 321 and game._progress.levels.swatter == 1, "defeat preserves night, purchases and coins")
	game._remaining = 0
	game._finish()
	game._restart()
	_check(game._progress.night == 2 and game._progress.wallet == 321, "survival advances exactly one night")
	var slow: Dictionary = Flight.create(1, 0, Vector2(640, 350), 93)
	var fast: Dictionary = Flight.create(2, 0, Vector2(640, 350), 93)
	fast.speed_scale = 1.5
	Flight.advance(slow, 0.7)
	Flight.advance(fast, 0.7)
	_check(Vector2(fast.pos).distance_to(Vector2(640, 350)) > Vector2(slow.pos).distance_to(Vector2(640, 350)), "difficulty reaches actual flight movement")
	print("PASS: difficulty curve; spawn counts first=%d middle=%d late=%d; caps; smooth flight; retry/survival; saved purchases" % [first, middle, late])
	game._sound.silence()
	for player: AudioStreamPlayer2D in game._sound._loops.values():
		player.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	call_deferred("quit")
