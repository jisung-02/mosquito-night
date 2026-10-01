extends SceneTree
const Progression = preload("res://progression.gd")
const Flight = preload("res://mosquito_flight.gd")
const Props = preload("res://room_props.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _verify() -> void:
	_check("--verify-game" in OS.get_cmdline_user_args(), "isolated test saves required")
	var path: String = "user://verification_removed_nursery.json"
	for level: int in range(1, 4):
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"version": 2, "wallet": 250, "night": 6, "equipped_tool": "electric", "total_earned": 1000, "levels": {"nursery": level, "swatter": 1, "electric": 1, "reach": 2, "trap": 1}}))
		file.close()
		var loaded: NightProgression = Progression.new(path)
		loaded.load_save()
		var expected: int = 250 + int(150 * level * (level + 1) / 2.0)
		_check(loaded.wallet == expected and loaded.night == 6 and loaded.levels.reach == 2 and loaded.equipped_tool == "electric", "refund retains other progression")
		_check(not loaded.levels.has("nursery") and not loaded.purchase("nursery"), "removed item cannot be bought or restored")
		loaded.load_save()
		_check(loaded.wallet == expected and loaded.total_earned == 1000, "refund cannot replay on reload")
		_check(loaded.purchase("fan") and loaded.levels.fan == 1 and loaded.wallet == expected - 150, "fan purchases from refunded coins")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._intro = false
	for id: String in game._progress.levels:
		game._progress.levels[id] = 0
	for id: String in ["trap", "flytrap", "sundew"]:
		var rect: Rect2 = game._prop_rect(id)
		var visible: Rect2i = game._prop_visible[id]
		var scale_factor: float = rect.size.y / game._assets[id].get_height()
		_check(absf(rect.position.y + visible.end.y * scale_factor) < 0.001, "opaque foot reaches furniture contact point: " + id)
	_check(game._assets.fan != null and game._assets.mosquito_cautious != null, "new models loaded")
	_check(Props.wind_strength(Vector2(950, 280), 3) > 0.35 and Props.wind_strength(Vector2(250, 400), 3) == 0, "wind only affects the visible fan's cone")
	var flying: Dictionary = Flight.create(1, 0, Vector2(950, 280), 93)
	flying.life = 100
	game._bugs.clear()
	game._bugs.append(flying)
	game._spawn_timer = 10
	game._progress.levels.fan = 3
	game._process(0.5)
	_check(float(flying.speed_scale) < 0.9 and float(flying.life) > 99.6, "wind slows flight and biting without creating coins")
	_check(game._progress.wallet == 0, "fan has no passive income")
	game._progress.levels.fan = 0
	game._bugs.clear()
	var aim: Vector2 = Vector2(600, 350)
	var heavy: Dictionary = Flight.create(2, 4, aim, 11)
	game._bugs.append(heavy)
	game._progress.equipped_tool = "hand"
	var pose: Transform2D = game.HitGeometry.tool_pose(aim, "hand")
	game._contacts(pose, Vector2(23, 29), aim)
	_check(game._bugs.size() == 1 and int(heavy.hp) == 1 and game._kills == 0, "stubborn mosquito survives one clap")
	game._contacts(pose, Vector2(23, 29), aim)
	_check(game._bugs.size() == 1, "same strike cannot deal damage twice")
	Flight.advance(heavy, 0.19)
	heavy.pos = aim
	game._contacts(pose, Vector2(23, 29), aim)
	_check(game._bugs.is_empty() and game._kills == 1 and game._progress.wallet == 25, "second distinct hit captures and rewards stubborn mosquito")
	game._progress.equipped_tool = "electric"
	game._bugs.append(Flight.create(3, 4, aim, 14))
	game._contacts(pose, Vector2(23, 29), aim)
	_check(game._bugs.is_empty() and game._kills == 2, "electric mesh defeats stubborn mosquito in one contact")
	var calm: Dictionary = Flight.create(4, 3, aim, 93)
	var fleeing: Dictionary = Flight.create(5, 3, aim, 93)
	calm.heading = 0.0
	fleeing.heading = 0.0
	calm.velocity = Vector2.ZERO
	fleeing.velocity = Vector2.ZERO
	Flight.advance(calm, 0.3)
	Flight.advance(fleeing, 0.3, Vector2.INF, aim - Vector2(30, 0))
	_check(Vector2(fleeing.pos).x > Vector2(calm.pos).x, "cautious mosquito physically escapes moving threat")
	for kind: int in [3, 4]:
		var paths: Array[Dictionary] = []
		for fps: int in [30, 60, 120]:
			var variant: Dictionary = Flight.create(10, kind, Vector2(1180, 580), 49287)
			variant.speed_scale = 1.595
			variant.heading = 0.2
			variant.velocity = Vector2(90, 35)
			for frame: int in range(fps * 20):
				var before: Vector2 = variant.velocity
				Flight.advance(variant, 1.0 / fps)
				_check(game.Flight.BOUNDS.has_point(variant.pos), "rare fast variants remain inside room")
				_check((Vector2(variant.velocity) - before).length() <= Flight.MAX_ACCELERATION * 1.595 / fps + 0.001, "rare variants keep bounded acceleration")
			paths.append(variant)
		_check(Vector2(paths[0].pos).distance_to(paths[1].pos) < 0.3 and Vector2(paths[1].pos).distance_to(paths[2].pos) < 0.3, "rare flight remains independent of refresh rate")
	for night: int in [1, 12]:
		game._progress.night = night
		var rare: int = 0
		for index: int in range(300):
			game._bugs.clear()
			game._spawn_bug()
			if int(game._bugs[0].kind) >= 3:
				rare += 1
		_check(rare == 0 if night == 1 else rare > 20 and rare < 100, "irregular variants are introduced gradually and stay a minority")
	for id: String in game._progress.levels:
		game._progress.levels[id] = 1
	game._progress.night = 6
	game._progress.wallet = 750
	game._bugs.clear()
	game._bugs.append(Flight.create(301, 3, Vector2(700, 275), 3))
	game._bugs.append(Flight.create(302, 4, Vector2(520, 330), 4))
	game._over = false
	game._paused = false
	Input.warp_mouse(Vector2(700, 475))
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://room-utilities-preview.png"))
	game._toggle_shop()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://new-shop-preview.png"))
	print("PASS: furniture anchors; fan cone and purchase; one-time nursery refunds; cautious evasion; stubborn contacts; electric counter; gradual rare variants")
	game._sound.silence()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	quit()
