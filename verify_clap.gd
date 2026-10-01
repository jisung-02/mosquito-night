extends SceneTree
const Clap = preload("res://clap_motion.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _bug(game: Node2D, pos: Vector2) -> void:
	game._spawn_bug()
	game._bugs[-1].pos = pos
	game._bugs[-1].kind = 0
	game._bugs[-1].velocity = Vector2.ZERO

func _snapshot(game: Node2D, name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://" + name + ".png"))

func _verify() -> void:
	assert("--verify-game" in OS.get_cmdline_user_args())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._start_game()
	game.set_process(false)
	game._paused = false
	game._bugs.clear()
	game._spawn_timer = 20
	var aim: Vector2 = Vector2(640, 350)
	Input.warp_mouse(game.get_viewport_transform() * aim)
	_bug(game, aim)
	await _snapshot(game, "clap-open")
	game._paused = false
	game._strike(aim)
	assert(game._clap_pending and game._score == 0 and game._sound.event_counts.get("hand_hit", 0) == 0, "no kill or sound before palms meet")
	game._process(0.03)
	assert(game._clap_pending and game._score == 0, "approach phase cannot capture")
	var delay: float = game._clap_delay
	var animation: float = game._swat
	game._paused = true
	game._process(1)
	assert(game._clap_pending and game._clap_delay == delay and game._swat == animation, "pause freezes pending clap")
	game._paused = false
	game._toggle_shop()
	game._process(1)
	assert(game._clap_pending and game._clap_delay == delay, "shop freezes pending clap")
	game._toggle_shop()
	game._progress.levels.swatter = 1
	game._equip_tool("swatter")
	assert(game._progress.equipped_tool == "hand", "equipment cannot change mid-clap")
	Input.warp_mouse(game.get_viewport_transform() * Vector2(900, 500))
	game._process(delay + 0.001)
	assert(not game._clap_pending and game._score == 10 and game._bugs.is_empty(), "single contact event captures at frozen aim")
	assert(game._sound.event_counts.hand_hit == 1, "contact produces one clap recording")
	await _snapshot(game, "clap-contact")
	game._paused = false
	game._process(0.01)
	assert(game._score == 10 and game._sound.event_counts.hand_hit == 1, "contact cannot score twice")
	game._process(0.3)
	game._cooldown = 0
	_bug(game, aim)
	game._strike(aim)
	game._bugs[-1].pos = aim + Vector2(100, 0)
	game._process(Clap.CONTACT_TIME + 0.001)
	assert(game._bugs.size() == 1 and game._score == 10, "mosquito which escapes before contact is not captured")
	assert(game._sound.event_counts.hand_hit == 2, "empty clap still makes one clap sound")
	game._process(0.3)
	game._bugs.clear()
	game._cooldown = 0
	_bug(game, aim + Vector2(0, 100))
	game._strike(aim)
	game._process(Clap.CONTACT_TIME + 0.001)
	assert(game._bugs.size() == 1, "forearms cannot capture")
	game._restart()
	assert(not game._clap_pending, "restart clears pending contact")
	assert(is_zero_approx(Clap.openness(Clap.CONTACT_TIME)) and Clap.openness(0.3) > 0.99, "close then separate")
	var left: Transform2D = Clap.palm_pose(aim, -1, Clap.CONTACT_TIME, 0)
	var right: Transform2D = Clap.palm_pose(aim, 1, Clap.CONTACT_TIME, 0)
	assert((left.origin + right.origin).is_equal_approx(aim * 2) and left.x.x == -right.x.x, "palms are symmetric and face each other")
	game._sound.silence()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	print("PASS: delayed palm contact; frozen click location; hitbox escape/wrist exclusion; single scoring/sound; empty clap; pause/shop/tool guards; restart; mirrored close/reopen rendering")
	quit()
