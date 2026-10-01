extends SceneTree
const Progression = preload("res://progression.gd")
const Flight = preload("res://mosquito_flight.gd")
const Aerosol = preload("res://aerosol_geometry.gd")
const Content = preload("res://night_content.gd")
const Props = preload("res://room_props.gd")
var _checks: int = 0
var _failed: bool = false

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _snapshot(name: String, game: Node2D) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://" + name + ".png")

func _verify() -> void:
	_check("--verify-game" in OS.get_cmdline_user_args(), "isolated save required")
	var path: String = "user://verification_content.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var progress: NightProgression = Progression.new(path)
	progress.wallet = 5000
	progress.night = 7
	_check(progress.purchase("swatter") and progress.purchase("electric") and progress.purchase("aerosol"), "weapon sequence")
	_check(progress.equip("swatter") and progress.equip("hand") and progress.equip("aerosol"), "owned weapons can be selected again")
	var before: int = progress.wallet
	_check(progress.purchase("window") and progress.purchase("window") and before - progress.wallet == 100, "consumables have flat price")
	_check(progress.consume("window") and progress.levels.window == 1, "consumption spends exactly one")
	_check(not progress.consume("electric") and not progress.consume("missing"), "permanent or unknown items cannot be consumed")
	for id: String in ["trap", "flytrap", "sundew"]:
		_check(progress.purchase(id), "installation purchase " + id)
	progress.place("trap", Vector2(750, 600))
	progress.place("flytrap", progress.position_for("trap"))
	_check(progress.position_for("trap").y == 363 and progress.position_for("flytrap").distance_to(progress.position_for("trap")) > 65, "snap to real furniture without overlaps")
	progress.record_capture(6)
	_check(progress.claim_goal(7, 90) and not progress.claim_goal(7, 90), "one reward per completed night")
	progress.save()
	var loaded: NightProgression = Progression.new(path)
	loaded.load_save()
	_check(loaded.night == 7 and loaded.highest_night == 7 and loaded.equipped_tool == "aerosol" and loaded.levels.window == 1 and loaded.catches["6"] == 1, "new and existing state roundtrip")
	_check(loaded.position_for("trap") == progress.position_for("trap") and not loaded.claim_goal(7, 90), "position and reward persist")
	_check(loaded.consume("window") and not loaded.consume("window") and loaded.levels.window == 0, "stock cannot underflow")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._progress = progress
	game._restart()
	await _snapshot("content-continue-preview", game)
	var wallet: int = progress.wallet
	game._first_night()
	_check(progress.night == 1 and progress.highest_night == 7 and progress.wallet == wallet and progress.levels.aerosol == 1 and not game._intro, "first-night button retains owned gear and coins")
	game._shop = true
	game._shop_page = 0
	game._shop_click(game._shop_rect(0).position + Vector2(100, 60))
	_check(progress.equipped_tool == "swatter", "owned newspaper shop equip")
	game._cooldown = 0
	game._shop_click(game._shop_rect(3).position + Vector2(100, 60))
	_check(progress.equipped_tool == "aerosol", "owned aerosol shop equip")
	await _snapshot("content-tools-preview", game)
	game._shop_page = 1
	await _snapshot("content-installations-preview", game)
	game._shop_page = 2
	await _snapshot("content-consumables-preview", game)
	game._shop_page = 3
	await _snapshot("content-collection-preview", game)
	game._shop = false
	game._begin_placement()
	var elapsed: float = game._elapsed
	game._process(1)
	_check(game._elapsed == elapsed, "placement pauses live night")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = progress.position_for("trap") + Vector2(0, -15)
	game._unhandled_input(press)
	_check(game._drag_prop == "trap", "visible prop is draggable")
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = Vector2(170, 380)
	game._unhandled_input(move)
	press.pressed = false
	press.position = move.position
	game._unhandled_input(press)
	_check(game._drag_prop.is_empty() and progress.position_for("trap").y == 392, "drag lands on bedside and saves")
	_check(game._helper_origin("trap").x < 260, "automatic capture follows relocated device")
	await _snapshot("content-placement-preview", game)
	var escape: InputEventKey = InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	game._unhandled_input(escape)
	_check(not game._placing, "placement finish returns to night")
	game._progress.levels.window = 2
	game._paused = true
	_check(not game._use_window() and progress.levels.window == 2, "paused consumable cannot be spent")
	game._paused = false
	_check(game._use_window() and not game._use_window() and progress.levels.window == 1, "use once without repeat while window is closed")
	game._bugs.clear()
	var resident: Dictionary = Flight.create(80, 0, Vector2(650, 300), 32)
	resident.life = 0.005
	game._bugs.append(resident)
	var old_health: int = game._health
	game._repellent_charges = 0
	game._spawn_timer = 0
	game._process(2)
	_check(game._health == old_health - 1, "closing window does not remove existing biting insects")
	_check(game._bugs.is_empty() and game._window_time < 12, "closed window blocks regular spawns")
	game._progress.night = 3
	game._elapsed = 17.9
	game._process(0.2)
	_check(game._bugs.is_empty() and game._wave_queue == 0, "closed window also blocks scheduled swarm")
	game._window_time = 0
	game._spawn_timer = 0
	game._process(0.02)
	_check(not game._bugs.is_empty(), "entry resumes after temporary closure")
	game._bugs.clear()
	var aim: Vector2 = Vector2(630, 330)
	var cone: PackedVector2Array = Aerosol.outline(aim, 1, 0.2)
	var inside: Dictionary = Flight.create(99, 4, aim, 22)
	var behind: Dictionary = Flight.create(100, 0, Aerosol.nozzle(aim) + Vector2(70, 110), 23)
	_check(Aerosol.touches(inside, cone) and not Aerosol.touches(behind, cone), "mist uses visible cone and rejects behind nozzle")
	var outside: Dictionary = Flight.create(101, 0, aim + Vector2(150, 0), 24)
	_check(not Aerosol.touches(outside, cone), "outside mist is safe")
	inside.velocity = Vector2.ZERO
	game._bugs.append(inside)
	game._bugs.append(behind)
	game._progress.equipped_tool = "aerosol"
	game._cooldown = 0
	game._spawn_timer = 100
	game._strike(aim)
	_check(game._sound.last_event == "spray" and game._kills == 0, "spray starts sound without instant kills")
	game._process(0.08)
	_check(game._kills == 0, "brief exposure does not capture")
	var remaining: float = game._spray_time
	game._shop = true
	game._process(1)
	_check(game._spray_time == remaining and game._kills == 0, "shop freezes active spray and hitbox")
	game._shop = false
	game._process(0.20)
	_check(game._kills == 1 and game._bugs.size() == 1 and int(game._bugs[0].id) == 100, "sustained spray captures stubborn insect and leaves outside insect")
	await _snapshot("content-aerosol-preview", game)
	game._repellent_charges = 1
	game._bugs[0].life = 0.005
	var health: int = game._health
	game._process(0.01)
	_check(game._health == health and game._repellent_charges == 0, "repellent charge prevents exactly one bite")
	var resting: Dictionary = Flight.create(102, 6, Vector2(320, 220), 30)
	resting.mode = "rest"
	resting.mode_timer = 3
	resting.velocity = Vector2.ZERO
	Flight.advance(resting, 1)
	_check(Vector2(resting.pos).distance_to(Vector2(320, 220)) < 0.01 and float(resting.wing_energy) < 0.03, "resting insect stops and folds wing motion")
	Flight.advance(resting, 0.1, Vector2.INF, Vector2(320, 230))
	_check(resting.mode == "dart" and Vector2(resting.velocity).length() > 5, "nearby hand wakes resting insect")
	_check(float(Flight.create(103, 5, aim, 30).body_size) < float(Flight.create(104, 0, aim, 30).body_size), "swarm insect is physically smaller")
	for kind: int in [5, 6]:
		var paths: Array[Dictionary] = []
		for fps: int in [30, 60, 120]:
			var variant: Dictionary = Flight.create(220 + kind, kind, Vector2(355, 230), 30)
			for tick: int in range(fps * 12):
				var velocity: Vector2 = variant.velocity
				Flight.advance(variant, 1.0 / fps, Vector2.INF, Vector2(350, 230) if tick >= fps * 8 else Vector2.INF)
				_check(Flight.BOUNDS.has_point(variant.pos) and (Vector2(variant.velocity) - velocity).length() <= Flight.MAX_ACCELERATION / fps + 0.001, "new variants remain in room with bounded acceleration")
			paths.append(variant)
		print("Variant ", kind, " path differences ", Vector2(paths[0].pos).distance_to(paths[1].pos), " / ", Vector2(paths[1].pos).distance_to(paths[2].pos))
		_check(Vector2(paths[0].pos).distance_to(paths[1].pos) < 0.1 and Vector2(paths[1].pos).distance_to(paths[2].pos) < 0.1, "new variants have stable 30/60/120 fps flight")
	game._progress.night = 1
	game._night_stats.manual = 8
	game._health = 0
	game._finish()
	_check(game._goal_bonus == 0, "defeat does not grant survival goal reward")
	game._over = false
	game._spray_time = 0
	game._progress.night = 2
	game._night_stats.combo = 4
	game._remaining = 0
	game._health = 5
	game._finish()
	_check(game._goal_bonus == 50, "survival grants earned nightly goal")
	if _failed:
		quit(1)
		return
	print("PASS: %d checks; continued save; replay; equipment selection; movable physical placements; flat consumable price/stock; window entry; timed spray cone; repellent; realistic resting; collection; unique goals" % _checks)
	game._sound.silence()
	for player: AudioStreamPlayer2D in game._sound._loops.values():
		player.stop()
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
