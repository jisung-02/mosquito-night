extends SceneTree
const Progression = preload("res://progression.gd")

func _initialize() -> void:
	call_deferred("_verify")

func _assert_ok(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _clear_levels(game: Node2D) -> void:
	for id: String in game._progress.levels:
		game._progress.levels[id] = 0
	game._progress.equipped_tool = "hand"

func _add_bug(game: Node2D, pos: Vector2) -> void:
	game._spawn_bug()
	game._bugs[-1].pos = pos
	game._bugs[-1].kind = 0

func _strike_and_settle(game: Node2D, pos: Vector2) -> void:
	game._strike(pos)
	if game._clap_pending:
		game._process(game.Clap.CONTACT_TIME + 0.005)
	elif not game._swing_tool.is_empty():
		game._process(game._swing_duration * 0.43 + 0.005)

func _verify() -> void:
	_assert_ok("--verify-game" in OS.get_cmdline_user_args(), "test isolation flag required")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._paused = false
	_assert_ok(game._intro and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "launch shows instructions and a visible cursor")
	game._process(5)
	game._strike(Vector2(500, 350))
	game._toggle_shop()
	_assert_ok(game._remaining == 60 and game._elapsed == 0 and game._health == 5 and game._score == 0 and not game._shop and not game._clap_pending, "intro freezes time, bites, attacks and shop")
	for ambient: AudioStreamPlayer2D in game._sound._loops.values():
		_assert_ok(ambient.volume_db <= -79, "intro has no gameplay ambient audio")
	var intro_click: InputEventMouseButton = InputEventMouseButton.new()
	intro_click.button_index = MOUSE_BUTTON_LEFT
	intro_click.pressed = true
	intro_click.position = Vector2(300, 300)
	game._unhandled_input(intro_click)
	_assert_ok(game._intro, "clicking explanatory text does not start or attack")
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://intro-preview.png"))
	var start_key: InputEventKey = InputEventKey.new()
	start_key.physical_keycode = KEY_SPACE
	start_key.pressed = true
	start_key.echo = true
	game._unhandled_input(start_key)
	_assert_ok(game._intro, "held key repeat does not dismiss instructions")
	start_key.echo = false
	game._unhandled_input(start_key)
	_assert_ok(not game._intro and game._remaining == 60 and not game._clap_pending and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "space starts without striking or spending night time")
	game._intro = true
	intro_click.position = game.START_BUTTON.get_center()
	game._unhandled_input(intro_click)
	_assert_ok(not game._intro and not game._clap_pending and game._cooldown == 0, "start button consumes the click without clapping")
	_assert_ok(game._background != null, "background loaded")
	for texture: Texture2D in game._assets.values():
		_assert_ok(texture != null, "all shop models loaded")
	_assert_ok(game._bugs.size() == 2, "first night starts with two mosquitoes")
	_assert_ok(game._progress.equipped_tool == "hand" and game._progress.reach() == 29, "new game starts with smaller bare-hand reach")
	_assert_ok(not game._progress.equip("swatter") and not game._progress.equip("electric"), "unowned tools cannot be equipped")
	for variants: Array in game._sound._clips.values():
		for clip: AudioStream in variants:
			_assert_ok(clip != null and clip.get_length() > 0.02, "every foley variant loads")
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://hand-preview.png"))
	game._paused = false
	game._bugs.clear()
	_add_bug(game, Vector2(500, 350))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._score == 10 and game._progress.wallet == 10 and game._bugs.is_empty(), "manual kill earns score and currency")
	_assert_ok(game._sound.last_event == "hand_hit", "bare-hand contact uses clap recording")
	_add_bug(game, Vector2(500, 350))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._kills == 1, "strike cooldown")
	game._cooldown = 0
	_strike_and_settle(game, Vector2(100, 100))
	_assert_ok(game._combo == 0 and game._progress.wallet == 10, "miss gives no currency")
	_assert_ok(game._sound.last_event == "hand_hit", "empty clap still makes a palm contact sound")
	var kills_before_guard: int = game._kills
	game._cooldown = 0
	game._paused = true
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._kills == kills_before_guard and game._cooldown == 0, "pause guards direct strikes")
	game._paused = false
	game._shop = true
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._kills == kills_before_guard and game._cooldown == 0, "shop clicks never capture")
	game._shop = false
	_assert_ok(not game._progress.purchase("electric"), "insufficient balance rejected")
	_assert_ok(not game._progress.purchase("invalid"), "unknown purchase rejected")
	game._progress.wallet = 5000
	var locked_balance: int = game._progress.wallet
	_assert_ok(not game._progress.purchase("electric") and not game._progress.purchase("trap") and not game._progress.purchase("reach"), "tool stage locks apply even with enough money")
	_assert_ok(game._progress.wallet == locked_balance, "stage lock does not spend coins")
	_assert_ok(game._progress.purchase("swatter") and game._progress.wallet == locked_balance - 40, "buy newspaper for forty coins")
	_assert_ok(game._progress.equipped_tool == "swatter" and game._progress.reach() == 47, "newspaper equips with its long striking face")
	game._bugs.clear()
	game._cooldown = 0
	_add_bug(game, Vector2(500, 350))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._sound.last_event == "paper_hit", "newsprint has its own dull contact sound")
	_assert_ok(game._progress.tool_name() == "말아 쥔 신문지" and game._assets["swatter"] == game._assets["newspaper"], "shop name, equipped tool and sprite all use newspaper")
	game._debug_hitboxes = true
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://newspaper-preview.png"))
	game._debug_hitboxes = false
	game._bugs.clear()
	game._cooldown = 0
	var handle_pose: Transform2D = game.HitGeometry.tool_pose(Vector2(500, 350), "swatter")
	_add_bug(game, handle_pose * Vector2(0, 100))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._bugs.size() == 1 and game._sound.last_event == "paper_swing", "gripping hand and forearm do not catch mosquitoes")
	var old_reach: float = game._progress.reach()
	var old_cooldown: float = game._progress.cooldown()
	var balance: int = game._progress.wallet
	_assert_ok(game._progress.purchase("electric"), "purchase electric")
	_assert_ok(game._progress.wallet == balance - 80, "exact purchase debit")
	_assert_ok(game._progress.reach() > old_reach and game._progress.cooldown() < old_cooldown, "electric changes gameplay")
	game._bugs.clear()
	game._cooldown = 0
	_add_bug(game, Vector2(500, 350))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._sound.last_event == "zap" and game._zap > 0, "electric contact triggers recorded crack and spark")
	var zaps: int = game._sound.event_counts.zap
	game._cooldown = 0
	_strike_and_settle(game, Vector2(100, 100))
	_assert_ok(game._sound.last_event == "swing" and game._sound.event_counts.zap == zaps and game._zap == 0, "electric miss has no discharge or spark")
	game._sound.set_muted(true)
	game._cooldown = 0
	_add_bug(game, Vector2(500, 350))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._sound.event_counts.zap == zaps, "mute blocks contact sounds")
	for voice: AudioStreamPlayer2D in game._sound._voices:
		_assert_ok(not voice.playing, "mute stops existing one-shot voices")
	game._sound.set_muted(false)
	_assert_ok(game._progress.purchase("electric") and game._progress.purchase("electric"), "upgrade to maximum")
	balance = game._progress.wallet
	_assert_ok(not game._progress.purchase("electric") and game._progress.wallet == balance, "cap does not spend")
	game._progress.save()
	var loaded: NightProgression = Progression.new(game._progress.save_path)
	loaded.load_save()
	_assert_ok(loaded.wallet == balance and loaded.levels.electric == 3 and loaded.equipped_tool == "electric", "purchase and equipped tool persist across load")
	var old_swatter_path: String = "user://verification_old_swatter.json"
	var old_swatter_file: FileAccess = FileAccess.open(old_swatter_path, FileAccess.WRITE)
	old_swatter_file.store_string(JSON.stringify({"version": 2, "wallet": 321, "equipped_tool": "swatter", "levels": {"swatter": 1, "electric": 1, "reach": 2, "trap": 1}}))
	old_swatter_file.close()
	var retained: NightProgression = Progression.new(old_swatter_path)
	retained.load_save()
	_assert_ok(retained.wallet == 321 and retained.equipped_tool == "swatter" and retained.tool_name() == "말아 쥔 신문지" and retained.levels.reach == 2 and retained.levels.trap == 1, "existing swatter save becomes newspaper without losing wallet, upgrades or automation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_swatter_path))
	loaded.equip("hand")
	var selected: NightProgression = Progression.new(game._progress.save_path)
	selected.load_save()
	_assert_ok(selected.equipped_tool == "hand", "choosing bare hands persists even with tools owned")
	var migration_path: String = "user://verification_migration.json"
	var migration_file: FileAccess = FileAccess.open(migration_path, FileAccess.WRITE)
	migration_file.store_string(JSON.stringify({"wallet": 123, "levels": {"trap": 2}}))
	migration_file.close()
	var migrated: NightProgression = Progression.new(migration_path)
	migrated.load_save()
	_assert_ok(migrated.wallet == 123 and migrated.levels.trap == 2 and migrated.levels.swatter == 1 and migrated.levels.electric == 1, "old purchases migrate without currency loss")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	game._bugs.clear()
	game._cooldown = 0
	_add_bug(game, Vector2(500, 350))
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	mouse_event.position = Vector2(500, 350)
	game._unhandled_input(mouse_event)
	_assert_ok(game._bugs.size() == 1 and not game._swing_tool.is_empty(), "mouse click starts windup without an instant hit")
	game._process(game._swing_duration * 0.43 + 0.005)
	_assert_ok(game._bugs.is_empty() and game._swat_pos.distance_to(Vector2(500, 350)) < 0.001, "capture follows input event coordinates rather than a later mouse position")
	var before_ui_kills: int = game._kills
	game._cooldown = 0
	_add_bug(game, Vector2(980, 40))
	mouse_event.position = Vector2(980, 40)
	game._unhandled_input(mouse_event)
	_assert_ok(game._shop and game._kills == before_ui_kills and game._bugs.size() == 1, "shop button consumes click without striking through UI")
	game._toggle_shop()
	_clear_levels(game)
	game._bugs.clear()
	game._combo = 0
	game._cooldown = 0
	_add_bug(game, Vector2(580, 350))
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._bugs.size() == 1, "base range misses distant bug")
	game._progress.levels.reach = 4
	game._progress.levels.electric = 3
	game._progress.equipped_tool = "electric"
	game._cooldown = 0
	_strike_and_settle(game, Vector2(500, 350))
	_assert_ok(game._bugs.is_empty(), "upgraded range catches distant bug")
	for id: String in ["trap", "flytrap", "sundew"]:
		_clear_levels(game)
		game._progress.levels[id] = 1
		game._bugs.clear()
		var origin: Vector2 = game._helper_origin(id)
		_add_bug(game, origin)
		if id == "sundew":
			_add_bug(game, game._helper_origin(id, 2))
		var expected: int = 2 if id == "sundew" else 1
		var kills_before: int = game._auto_kills
		balance = game._progress.wallet
		game._auto_timers[id] = 0
		game._update_auto(0.01)
		_assert_ok(game._bugs.is_empty() and game._auto_kills == kills_before + expected, id + " auto capture")
		_assert_ok(game._progress.wallet == balance + expected * 10, id + " earns currency")
		_assert_ok(game._sound.last_event == id, id + " has distinct positional capture sound")
	_clear_levels(game)
	game._motion_actions.clear()
	game._progress.levels.flytrap = 1
	game._bugs.clear()
	_add_bug(game, game._helper_origin("flytrap") + Vector2(100, 0))
	game._auto_timers.flytrap = 0
	game._update_auto(0.01)
	_assert_ok(game._bugs.size() == 1, "plant cannot capture at a distance")
	game._bugs[0].pos = game._helper_origin("flytrap")
	game._auto_timers.flytrap = 0
	game._update_auto(0.01)
	_assert_ok(not game._leaf_available("flytrap", 0) and not game._plant_actions("flytrap").is_empty(), "capturing mouth begins an independent closing animation")
	_add_bug(game, game._helper_origin("flytrap"))
	game._auto_timers.flytrap = 0
	game._update_auto(0.01)
	_assert_ok(game._bugs.size() == 1, "occupied mouth cannot capture another mosquito immediately")
	_clear_levels(game)
	game._progress.levels.dragonfly = 1
	game._bugs.clear()
	game._dragon_target = -1
	game._dragon_pos = Vector2(600, 200)
	_add_bug(game, Vector2(650, 200))
	game._auto_timers.dragonfly = 0
	game._update_auto(1)
	_assert_ok(game._bugs.is_empty() and game._dragon_target == -1, "dragonfly seeks and captures")
	_assert_ok(game._sound.last_event == "dragonfly", "dragonfly uses quiet wing foley")
	_clear_levels(game)
	game._progress.levels.fan = 3
	balance = game._progress.wallet
	game._update_auto(0.01)
	_assert_ok(game._progress.wallet == balance, "fan never creates passive currency")
	game._elapsed = 0
	game._paused = false
	game._spawn_timer = 0
	game._process(0.01)
	_assert_ok(game._spawn_timer > 1.6, "night opening has a gentle spawn interval")
	game._toggle_shop()
	var remaining: float = game._remaining
	var frozen_time: float = game._elapsed
	var frozen_swat: float = game._swat
	var frozen_dragon: Vector2 = game._dragon_pos
	game._process(1)
	_assert_ok(game._remaining == remaining, "shop pauses night")
	_assert_ok(game._elapsed == frozen_time and game._swat == frozen_swat and game._dragon_pos == frozen_dragon, "shop freezes background, rigs and attack animation")
	game._progress.levels.swatter = 1
	game._shop_click(Vector2(110 + 268 * 2 + 20, 180 + 165))
	_assert_ok(game._progress.levels.reach == 1, "shop button buys upgrade")
	var purchase_voice: AudioStreamPlayer2D = game._sound._voices[(game._sound._next_voice - 1 + game._sound.VOICE_COUNT) % game._sound.VOICE_COUNT]
	game._process(0.016)
	_assert_ok(purchase_voice.playing and game._sound.last_event == "purchase", "shop click continues while gameplay audio is silent")
	for ambient: AudioStreamPlayer2D in game._sound._loops.values():
		_assert_ok(ambient.volume_db <= -79, "shop silences all ambient loops")
	game._toggle_shop()
	var pause_event: InputEventKey = InputEventKey.new()
	pause_event.physical_keycode = KEY_P
	pause_event.pressed = true
	game._unhandled_input(pause_event)
	game._process(1)
	_assert_ok(game._remaining == remaining, "manual pause")
	for voice: AudioStreamPlayer2D in game._sound._voices:
		_assert_ok(not voice.playing, "pause stops gameplay sound tails")
	game._paused = false
	game._bugs.clear()
	_add_bug(game, Vector2(400, 300))
	game._bugs[0].life = 0.01
	game._spawn_timer = 10
	game._process(0.02)
	_assert_ok(game._health == 4, "bite damage")
	game._remaining = 0.01
	game._process(0.02)
	_assert_ok(game._over, "round finishes")
	var previous_night: int = game._progress.night
	balance = game._progress.wallet
	game._restart()
	_assert_ok(not game._intro, "next night does not show the launch instructions again")
	_assert_ok(game._progress.wallet == balance and game._progress.levels.fan == 3 and game._progress.night == previous_night + 1, "next night keeps upgrades and coins")
	game._health = 0
	game._process(0.01)
	_assert_ok(game._over, "health defeat")
	game._restart()
	_assert_ok(game._progress.night == previous_night + 1, "defeat retries the same difficulty")
	while game._bugs.size() < 4:
		game._spawn_bug()
	for id: String in game._progress.levels:
		game._progress.levels[id] = 1
	game._progress.equipped_tool = "electric"
	game._progress.wallet = 900
	game._progress.night = 3
	game._dragon_pos = Vector2(780, 240)
	game._bugs[0].pos = Vector2(620, 310)
	game._bugs[1].pos = Vector2(875, 425)
	game._bugs[2].pos = Vector2(380, 390)
	game._bugs[3].pos = Vector2(1050, 240)
	Input.warp_mouse(Vector2(680, 420))
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://preview.png"))
	game._paused = false
	game._debug_hitboxes = true
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://hitbox-preview.png"))
	game._debug_hitboxes = false
	game._toggle_shop()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shop-preview.png"))
	print("PASS: geometric hits; handle misses; click coordinates/UI/pause guards; hand → newspaper → electric → automation; tool save/migration; sounds/mute; economy; upgrades; automation; shop; night progression")
	game._sound.silence()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://verification_progression.json"))
	quit()
