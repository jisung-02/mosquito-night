extends SceneTree
const Swing = preload("res://weapon_swing.gd")
const Geometry = preload("res://hit_geometry.gd")
const Flight = preload("res://mosquito_flight.gd")
const AIM: Vector2 = Vector2(640, 330)

func _initialize() -> void:
	call_deferred("_verify")

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		assert(ok, message)

func _fixture(game: Node2D, tool: String, level: int = 1) -> void:
	for id: String in game._progress.levels:
		game._progress.levels[id] = 0
	game._progress.levels.swatter = 1
	game._progress.levels.electric = level
	game._progress.equipped_tool = tool
	game._restart()
	game._bugs.clear()
	game._spawn_timer = 10
	for event: String in game._sound.event_counts:
		game._sound.event_counts[event] = 0
	game._paused = false
	game._tool_roll = 0
	Input.warp_mouse(game.get_viewport_transform() * AIM)

func _bug(game: Node2D, pos: Vector2) -> void:
	var bug: Dictionary = Flight.create(900 + game._bugs.size(), 0, pos, 31415)
	bug.velocity = Vector2.ZERO
	bug.mode = "hover"
	bug.mode_timer = 10
	game._bugs.append(bug)

func _snapshot(game: Node2D, filename: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + filename + ".png"))

func _verify() -> void:
	_check("--verify-game" in OS.get_cmdline_user_args(), "isolated test save required")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._start_game()
	game.set_process(false)
	for tool: String in ["swatter", "electric"]:
		for reach: float in [47.0, 115.0]:
			var layout: Dictionary = Geometry.tool_layout(tool, reach, game._assets[tool].get_size())
			for roll: float in [-0.16, 0.0, 0.16]:
				var rest: Transform2D = Geometry.tool_pose(AIM, tool, 0, roll)
				var wrist: Vector2 = rest * Swing.grip(layout, tool)
				for step: int in range(101):
					var u: float = step / 100.0
					var pose: Transform2D = Swing.pose(AIM, tool, layout, u, roll)
					_check((pose * Swing.grip(layout, tool)).distance_to(wrist) < 0.001, "wrist remains fixed through swing and upgrades")
					_check(is_equal_approx(pose.x.length(), 1) and is_equal_approx(pose.y.length(), 1), "rigid weapon is never stretched")
				for u: float in [0.0, Swing.CONTACT, 1.0]:
					_check(Swing.pose(AIM, tool, layout, u, roll).origin.distance_to(AIM) < 0.001, "rest/contact/recovery return to target pose")
		_fixture(game, tool)
		_bug(game, AIM)
		game._strike(AIM)
		_check(game._score == 0 and game._sound.event_counts.values().all(func(value: int) -> bool: return value == 0), "click begins windup without instant hit or sound")
		game._process(game._swing_duration * 0.18)
		_check(game._score == 0 and game._bugs.size() == 1, "windup cannot capture")
		var remaining: float = game._swat
		game._paused = true
		game._process(0.4)
		_check(game._swat == remaining and game._score == 0, "pause freezes swing contact")
		game._paused = false
		game._toggle_shop()
		game._process(0.4)
		_check(game._swat == remaining and game._score == 0, "shop freezes swing contact")
		game._toggle_shop()
		game._equip_tool("hand")
		_check(game._progress.equipped_tool == tool, "cannot equip during an unfinished swing")
		Input.warp_mouse(game.get_viewport_transform() * Vector2(950, 500))
		game._process(game._swing_duration * 0.26)
		var impact: String = "paper_hit" if tool == "swatter" else "zap"
		var whoosh: String = "paper_swing" if tool == "swatter" else "swing"
		_check(game._kills == 1 and game._swat_pos == AIM, "moving face captures once at the frozen click")
		_check(game._sound.event_counts.get(impact, 0) == 1 and game._sound.event_counts.get(whoosh, 0) == 1, "one forward whoosh and one contact sound")
		var recovery_pose: Transform2D = game._weapon_pose(AIM, game._swing_layout, game._swat_roll)
		_bug(game, recovery_pose.origin)
		game._process(game._swing_duration)
		_check(game._kills == 1 and game._bugs.size() == 1, "follow-through and recovery cannot catch another mosquito")
		_fixture(game, tool)
		_bug(game, AIM)
		game._strike(AIM)
		game._bugs[0].pos += Vector2(250, 0)
		game._process(0.3)
		_check(game._kills == 0 and game._sound.event_counts.get(impact, 0) == 0 and game._sound.event_counts.get(whoosh, 0) == 1, "escape before contact produces only a whoosh")
		_fixture(game, tool)
		var layout: Dictionary = game._tool_layout()
		_bug(game, Geometry.tool_pose(AIM, tool) * Swing.grip(layout, tool))
		game._strike(AIM)
		game._process(0.3)
		_check(game._kills == 0, "grip and wrist do not capture during any phase")
		for fps: int in [30, 60, 120]:
			_fixture(game, tool, 3)
			_bug(game, AIM)
			game._strike(AIM)
			for frame: int in range(int(ceil(0.3 * fps))):
				game._process(1.0 / fps)
			_check(game._kills == 1 and game._sound.event_counts.get(impact, 0) == 1, "30/60/120 FPS cannot skip the fastest swing contact")
		_fixture(game, tool)
		game._debug_hitboxes = true
		game._strike(AIM)
		game._process(game._swing_duration * 0.14)
		await _snapshot(game, "swing-" + tool + "-windup")
		game._process(game._swing_duration * 0.18)
		await _snapshot(game, "swing-" + tool + "-contact")
		game._process(game._swing_duration * 0.18)
		await _snapshot(game, "swing-" + tool + "-follow")
	game._sound.silence()
	for player: AudioStreamPlayer2D in game._sound._loops.values():
		player.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	print("PASS: fixed wrist and rigid grip; windup/contact/recovery; no instant hits; escape and handle exclusion; single sound/scoring; frozen aim; pause/shop/equip guards; fastest swings at 30/60/120 FPS")
	quit()
