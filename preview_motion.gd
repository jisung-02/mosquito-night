extends SceneTree
## Isolated, deterministic animation capture. Never touches the player's save.
var _game: Node2D
var _frame: int = 0

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	assert("--verify-game" in OS.get_cmdline_user_args(), "isolated save required")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	seed(409)
	_game = load("res://main.tscn").instantiate()
	root.add_child(_game)
	_game._start_game()
	_game.set_process(false)
	for id: String in _game._progress.levels:
		_game._progress.levels[id] = 1
	_game._progress.equipped_tool = "hand"
	_game._progress.wallet = 900
	_game._health = 5
	_game._remaining = 60
	_game._spawn_timer = 0.2
	_game._dragon_pos = Vector2(820, 230)
	_game._bugs[0].pos = Vector2(500, 260)
	_game._bugs[1].pos = Vector2(900, 350)
	_game._bugs[2].pos = Vector2(660, 240)
	_game._bugs[3].pos = Vector2(420, 340)
	process_frame.connect(_step)

func _step() -> void:
	_game._paused = false
	_game._health = 5
	var time: float = _frame / 60.0
	var aim: Vector2 = Vector2(530 + sin(time * 1.4) * 90, 380 + cos(time * 1.1) * 45)
	Input.warp_mouse(_game.get_viewport_transform() * aim)
	if _frame in [30, 230]:
		_game._spawn_bug()
		_game._bugs[-1].pos = _game._helper_origin("flytrap", 0 if _frame == 30 else 1)
		_game._auto_timers.flytrap = 0
	if _frame == 90:
		for leaf: int in [0, 2]:
			_game._spawn_bug()
			_game._bugs[-1].pos = _game._helper_origin("sundew", leaf)
		_game._auto_timers.sundew = 0
	if _frame == 160:
		_game._progress.equipped_tool = "swatter"
	if _frame == 300:
		_game._progress.equipped_tool = "electric"
	if _frame in [50, 120, 180, 260, 320, 385, 435]:
		_game._spawn_bug()
		_game._bugs[-1].pos = aim
		_game._cooldown = 0
		_game._strike(aim)
	_game._process(1.0 / 60)
	_frame += 1
	if _frame >= 480:
		process_frame.disconnect(_step)
		_game._sound.silence()
		_game.queue_free()
		await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
		print("PASS: 8 seconds of all rigs, pursuit, suction, plant captures and hand/newspaper/electric strikes rendered")
		quit()
