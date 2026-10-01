extends Node2D
## Full-screen mosquito hunting; the room is the entire playfield.
const SAVE_PATH: String = "user://best.json"
const Progression = preload("res://progression.gd")
const Flight = preload("res://mosquito_flight.gd")
const Difficulty = preload("res://night_difficulty.gd")
const Props = preload("res://room_props.gd")
const Sound = preload("res://game_audio.gd")
const HitGeometry = preload("res://hit_geometry.gd")
const Motion = preload("res://scene_motion.gd")
const Clap = preload("res://clap_motion.gd")
const Swing = preload("res://weapon_swing.gd")
const PROP_POS: Dictionary = Props.POSITIONS
const SIZE: Vector2 = Vector2(1280, 720)
const START_BUTTON: Rect2 = Rect2(540, 470, 200, 52)
var _progress: NightProgression
var _assets: Dictionary[String, Texture2D] = {}
var _prop_visible: Dictionary[String, Rect2i] = {}
var _shop: bool = false
var _shop_message: String = ""
var _auto_timers: Dictionary[String, float] = {}
var _auto_effects: Array[Dictionary] = []
var _auto_kills: int = 0
var _next_bug_id: int = 0
var _dragon_pos: Vector2 = Vector2(650, 250)
var _dragon_target: int = -1
var _dragon_rotation: float = 0.0
var _save_timer: float = 0.0
var _prop_pulse: Dictionary[String, float] = {}
var _wing_samples: Array[Dictionary] = []
var _mosquito_texture: Texture2D
var _newspaper_texture: Texture2D
var _background: Texture2D
var _font: Font = SystemFont.new()
var _bugs: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _score: int = 0
var _best: int = 0
var _kills: int = 0
var _health: int = 5
var _remaining: float = 60.0
var _elapsed: float = 0.0
var _spawn_timer: float = 0.0
var _cooldown: float = 0.0
var _combo: int = 0
var _combo_timer: float = 0.0
var _flash: float = 0.0
var _swat: float = 0.0
var _swat_pos: Vector2 = Vector2.ZERO
var _zap: float = 0.0
var _spark_positions: Array[Vector2] = []
var _over: bool = false
var _intro: bool = true
var _paused: bool = false
var _muted: bool = false
var _sound: NightAudio
var _debug_hitboxes: bool = false
var _motion: NightMotion = Motion.new()
var _motion_actions: Dictionary[String, Dictionary] = {}
var _room_material: ShaderMaterial
var _background_sprite: Sprite2D
var _tool_roll: float = 0.0
var _swat_roll: float = 0.0
var _clap_pending: bool = false
var _clap_delay: float = 0.0
var _swing_tool: String = ""
var _swing_duration: float = 0.18
var _swing_layout: Dictionary = {}
var _swing_hit: bool = false
var _swing_swoosh: bool = false
var _swing_checked: bool = false
var _last_mouse: Vector2 = Vector2.ZERO
var _cursor_velocity: Vector2 = Vector2.ZERO
var _dragon_velocity: Vector2 = Vector2.ZERO
var _dragon_bank: float = 0.0
var _dragon_waypoint: Vector2 = Vector2(675, 255)
var _dragon_waypoint_timer: float = 0.0
var _death_effects: Array[Dictionary] = []

func _ready() -> void:
	_build_wing_samples()
	if OS.has_feature("web"):
		_font = load("res://assets/fonts/NightKorean.ttf") as FontFile
	else:
		var system_font: SystemFont = _font as SystemFont
		system_font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "sans-serif"])
	if ResourceLoader.exists("res://assets/bedroom.png"):
		_background = load("res://assets/bedroom.png") as Texture2D
		_background_sprite = Sprite2D.new()
		_background_sprite.texture = _background
		_background_sprite.centered = false
		_background_sprite.scale = SIZE / _background.get_size()
		_background_sprite.z_index = -10
		_room_material = ShaderMaterial.new()
		_room_material.shader = load("res://room_motion.gdshader") as Shader
		_background_sprite.material = _room_material
		add_child(_background_sprite)
	_mosquito_texture = load("res://assets/mosquito.png") as Texture2D
	_newspaper_texture = load("res://assets/newspaper.png") as Texture2D
	_sound = Sound.new()
	add_child(_sound)
	var testing: bool = "--verify-game" in OS.get_cmdline_user_args()
	_progress = Progression.new("user://verification_progression.json" if testing else "user://progression.json")
	_progress.load_save()
	if not testing and not FileAccess.file_exists(_progress.save_path) and FileAccess.file_exists(SAVE_PATH):
		var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if legacy is Dictionary:
			_progress.best = maxi(0, int(legacy.get("best", 0)))
			_progress.earn(_progress.best)
			_progress.save()
	_best = _progress.best
	_assets["swatter"] = _newspaper_texture
	_assets["newspaper"] = _newspaper_texture
	for key: String in ["hand", "clap_hand", "electric", "trap", "flytrap", "sundew", "dragonfly", "dragonfly_body", "mosquito_cautious"]:
		_assets[key] = load("res://assets/" + key + ".png") as Texture2D
	for key: String in ["trap", "flytrap", "sundew"]:
		_prop_visible[key] = _assets[key].get_image().get_used_rect()
	var fan_thumbnail: AtlasTexture = AtlasTexture.new()
	fan_thumbnail.atlas = _background
	fan_thumbnail.region = Rect2(_background.get_size() * Vector2(0.865, 0.276), _background.get_size() * Vector2(0.075, 0.17))
	_assets["fan"] = fan_thumbnail
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_last_mouse = get_global_mouse_position()
	_restart()

func _process(delta: float) -> void:
	if not (_intro or _over or _paused or _shop):
		var mouse: Vector2 = get_global_mouse_position()
		_cursor_velocity = (mouse - _last_mouse) / maxf(delta, 0.001)
		_last_mouse = mouse
	var left: float = maxf(0, delta)
	while left > 0.000001 and not (_intro or _over or _paused or _shop):
		var step: float = minf(left, 1.0 / 120.0)
		_step_game(step)
		left -= step
	_sound.update_room(delta, _bugs, not (_intro or _paused or _over or _shop), _progress.levels, _dragon_pos)
	if _room_material:
		_room_material.set_shader_parameter("room_time", _elapsed)
		_room_material.set_shader_parameter("fan_power", 1.0 + _progress.levels["fan"] * 0.35 if _progress.levels["fan"] > 0 else 0.0)
	queue_redraw()

func _step_game(delta: float) -> void:
	_cooldown = maxf(0, _cooldown - delta)
	_swat = maxf(0, _swat - delta)
	if _clap_pending:
		_clap_delay = maxf(0, _clap_delay - delta)
	_zap = maxf(0, _zap - delta)
	_flash = maxf(0, _flash - delta)
	for effect: Dictionary in _effects:
		effect.life -= delta
	_effects = _effects.filter(func(e: Dictionary) -> bool: return float(e.life) > 0.0)
	for effect: Dictionary in _death_effects:
		effect.life -= delta
	_death_effects = _death_effects.filter(func(e: Dictionary) -> bool: return float(e.life) > 0)
	_tool_roll = lerpf(_tool_roll, clampf(-_cursor_velocity.x * 0.00012, -0.16, 0.16), 1 - exp(-delta * 9))
	_elapsed += delta
	_remaining = maxf(0, _remaining - delta)
	_combo_timer -= delta
	if _combo_timer <= 0:
		_combo = 0
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		if _bugs.size() < Difficulty.active_limit(_progress.night):
			_spawn_bug()
		_spawn_timer = Difficulty.spawn_interval(_progress.night, _elapsed)
	var expired: Array[int] = []
	for i: int in range(_bugs.size()):
		var bug: Dictionary = _bugs[i]
		var wind: float = Props.wind_strength(bug.pos, _progress.levels["fan"])
		bug.life -= delta * (1.0 - wind * 0.75)
		var target_speed: float = Difficulty.speed_scale(_progress.night, _elapsed) * (1.0 - wind)
		bug.speed_scale = move_toward(float(bug.speed_scale), target_speed, delta * 0.65)
		var attractor: Vector2 = _flight_attractor(bug.pos)
		var threat: Vector2 = _swat_pos if _swat > 0.04 else Vector2.INF
		if int(bug.kind) == 3 and not threat.is_finite() and _cursor_velocity.length() > 20:
			threat = get_global_mouse_position()
		Flight.advance(bug, delta, attractor, threat)
		if float(bug.life) <= 0:
			expired.append(i)
	for i: int in range(expired.size() - 1, -1, -1):
		_motion.release("bug_%d" % int(_bugs[expired[i]].id))
		_bugs.remove_at(expired[i])
		_health -= 1
		_flash = 0.35
		_combo = 0
	if _clap_pending and _clap_delay <= 0:
		_clap_pending = false
		_resolve_strike(_swat_pos, "hand", _swat_roll)
	_update_swing()
	_update_auto(delta)
	_save_timer += delta
	if _save_timer > 2.0:
		_save_timer = 0.0
		_progress.save()
	if _health <= 0 or _remaining <= 0:
		_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _intro and not _over and not "--verify-game" in OS.get_cmdline_user_args():
		_paused = true
		if is_instance_valid(_sound):
			_sound.silence()

func _exit_tree() -> void:
	if _progress and not "--verify-game" in OS.get_cmdline_user_args():
		_progress.save()
	if is_instance_valid(_sound):
		_sound.silence()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if _intro:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
					_start_game()
				KEY_F, KEY_ESCAPE:
					_toggle_fullscreen()
				KEY_M:
					_muted = not _muted
					_sound.set_muted(_muted)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
			if START_BUTTON.has_point(pos):
				_start_game()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_B:
				_toggle_shop()
			KEY_ESCAPE:
				if _shop:
					_toggle_shop()
				else:
					_toggle_fullscreen()
			KEY_F:
				_toggle_fullscreen()
			KEY_P:
				if not _shop:
					_paused = not _paused
					if _paused:
						_sound.silence()
			KEY_M:
				_muted = not _muted
				_sound.set_muted(_muted)
			KEY_1:
				_equip_tool("hand")
			KEY_2:
				_equip_tool("swatter")
			KEY_3:
				_equip_tool("electric")
			KEY_H:
				_debug_hitboxes = not _debug_hitboxes
			KEY_R:
				if not _shop:
					_restart()
			KEY_SPACE:
				if _over and not _shop:
					_restart()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if _shop:
			_shop_click(pos)
		elif Rect2(948, 22, 170, 44).has_point(pos):
			_toggle_shop()
		elif _over:
			_restart()
		elif not _paused:
			_strike(pos)

func _start_game() -> void:
	if not _intro:
		return
	# Browsers accept fullscreen only during the start button/key input event.
	if OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	_intro = false
	_paused = false
	_last_mouse = get_global_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	queue_redraw()

func _toggle_fullscreen() -> void:
	var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_shop() -> void:
	if _intro:
		return
	_shop = not _shop
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _shop else Input.MOUSE_MODE_HIDDEN
	if _shop:
		_sound.silence()

func _equip_tool(id: String) -> void:
	if _swat > 0 or _clap_pending:
		return
	if _progress.equip(id):
		_cooldown = maxf(_cooldown, _progress.cooldown())
		_swat = 0.0
		_zap = 0.0
		_sound.play_event("purchase", get_global_mouse_position(), -14)

func _restart() -> void:
	if _over and _health > 0 and _remaining <= 0:
		_progress.night += 1
		_progress.save()
	_bugs.clear()
	_effects.clear()
	_death_effects.clear()
	_motion.reset()
	_motion_actions.clear()
	_auto_effects.clear()
	_auto_kills = 0
	_dragon_target = -1
	_dragon_velocity = Vector2.ZERO
	_dragon_bank = 0.0
	_dragon_waypoint_timer = 0.0
	_prop_pulse.clear()
	for id: String in ["trap", "flytrap", "sundew", "dragonfly"]:
		_auto_timers[id] = _progress.interval(id)
		_prop_pulse[id] = 0.0
	_score = 0
	_kills = 0
	_health = 5
	_remaining = 60.0
	_elapsed = 0.0
	_combo = 0
	_combo_timer = 0.0
	_spawn_timer = Difficulty.spawn_interval(_progress.night, 0)
	_cooldown = 0.0
	_swat = 0.0
	_clap_pending = false
	_clap_delay = 0.0
	_swing_tool = ""
	_swing_layout.clear()
	_tool_roll = 0.0
	_last_mouse = get_global_mouse_position()
	_zap = 0.0
	_spark_positions.clear()
	_over = false
	_paused = false
	_shop = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _intro else Input.MOUSE_MODE_HIDDEN
	for i: int in range(Difficulty.initial_count(_progress.night)):
		_spawn_bug()
		# Stagger the opening bites so several insects cannot expire together.
		_bugs[-1].life += i * 1.4

func _spawn_bug() -> void:
	var kind: int = 0
	var choice: float = randf()
	var golden: float = Difficulty.golden_chance(_progress.night)
	var cautious: float = golden + Difficulty.cautious_chance(_progress.night)
	var stubborn: float = cautious + Difficulty.stubborn_chance(_progress.night)
	if choice < golden:
		kind = 2
	elif choice < cautious:
		kind = 3
	elif choice < stubborn:
		kind = 4
	elif choice < stubborn + Difficulty.fast_chance(_progress.night, _elapsed):
		kind = 1
	_next_bug_id += 1
	var bug: Dictionary = Flight.create(_next_bug_id, kind, Vector2(randf_range(140, 1140), randf_range(165, 580)), randi())
	bug.life = Difficulty.bite_delay(_progress.night, _elapsed, kind)
	bug.speed_scale = Difficulty.speed_scale(_progress.night, _elapsed)
	_bugs.append(bug)

func _strike(pos: Vector2) -> void:
	if _intro or _cooldown > 0 or _paused or _shop or _over:
		return
	_cooldown = _progress.cooldown()
	_swat_pos = pos
	_swat_roll = _tool_roll
	_zap = 0.0
	_spark_positions.clear()
	_swing_tool = ""
	_swing_hit = false
	_swing_swoosh = false
	_swing_checked = false
	if _progress.equipped_tool == "hand":
		_swat = Clap.DURATION
		_clap_pending = true
		_clap_delay = Clap.CONTACT_TIME
		return
	_swing_tool = _progress.equipped_tool
	_swing_duration = _progress.cooldown()
	_swing_layout = _tool_layout().duplicate()
	_swat = _swing_duration

func _contacts(pose: Transform2D, radii: Vector2, pos: Vector2) -> int:
	var hit: int = 0
	for i: int in range(_bugs.size() - 1, -1, -1):
		if float(_bugs[i].hurt_timer) > 0:
			continue
		var contact: Dictionary = HitGeometry.contact(_bugs[i], pose, radii)
		if contact.hit:
			_spark_positions.append(contact.point)
			hit += 1
			if int(_bugs[i].hp) > 1 and _progress.equipped_tool != "electric":
				_bugs[i].hp -= 1
				_bugs[i].hurt_timer = 0.18
				_bugs[i].mode = "dart"
				_bugs[i].mode_timer = 0.5
				_effects.append({"pos": _bugs[i].pos, "life": 0.25, "hit": false, "text": ""})
				continue
			_combo += 1
			_combo_timer = 2.2
			_capture(i, "hand", pos)
	return hit

func _miss(pos: Vector2) -> void:
	_combo = 0
	_effects.append({"pos": pos, "life": 0.25, "hit": false, "text": ""})

func _resolve_strike(pos: Vector2, tool: String, roll: float) -> void:
	var hit: int = _contacts(HitGeometry.tool_pose(pos, tool, 0, roll), _tool_layout().radii, pos)
	if hit == 0:
		_miss(pos)
	_sound.play_event("hand_hit", pos, -4 if hit > 0 else -8)

func _update_swing() -> void:
	if _swing_tool.is_empty():
		return
	var u: float = 1 - _swat / _swing_duration
	if not _swing_swoosh and u >= Swing.WINDUP_END:
		_swing_swoosh = true
		_sound.play_event("paper_swing" if _swing_tool == "swatter" else "swing", _swat_pos, -12)
	if Swing.active(u):
		var pose: Transform2D = Swing.pose(_swat_pos, _swing_tool, _swing_layout, u, _swat_roll)
		var hit: int = _contacts(pose, _swing_layout.radii, _swat_pos)
		if hit > 0:
			if not _swing_hit:
				_sound.play_event("paper_hit" if _swing_tool == "swatter" else "zap", _spark_positions[-1], -5 if _swing_tool == "swatter" else -4)
			_swing_hit = true
			if _swing_tool == "electric":
				_zap = 0.14
	if not _swing_checked and u > Swing.ACTIVE_END:
		_swing_checked = true
		if not _swing_hit:
			_miss(_swat_pos)
	if _swat <= 0:
		_swing_tool = ""
		_swing_layout.clear()

func _capture(index: int, source: String, origin: Vector2) -> void:
	if index < 0 or index >= _bugs.size():
		return
	var bug: Dictionary = _bugs[index]
	_motion.release("bug_%d" % int(bug.id))
	var multiplier: int = mini(4, 1 + int(_combo / 3.0)) if source == "hand" else 1
	var reward: int = 10
	match int(bug.kind):
		2: reward = 30
		3: reward = 20
		4: reward = 25
	var points: int = reward * multiplier
	_score += points
	_kills += 1
	_progress.earn(points)
	_best = maxi(_best, _score)
	_progress.best = _best
	_effects.append({"pos": bug.pos, "life": 0.65, "hit": true, "text": "+%d" % points})
	if source != "hand":
		_auto_kills += 1
		_auto_effects.append({"from": bug.pos, "to": origin, "life": 0.65, "kind": source, "bug_kind": bug.kind, "size": bug.body_size, "rotation": bug.rotation})
		if source in ["flytrap", "sundew"]:
			var leaf: int = _closest_leaf(source, origin)
			_auto_effects[-1]["leaf"] = leaf
			_motion_actions["%s_%d" % [source, leaf]] = {"start": _elapsed, "leaf": leaf}
		_prop_pulse[source] = 0.6
		if source != "sundew" or _prop_pulse.get("sundew_sound", 0.0) <= 0:
			_sound.play_event(source, origin, -13 if source in ["flytrap", "sundew", "dragonfly"] else -8)
			if source == "sundew":
				_prop_pulse["sundew_sound"] = 0.3
	else:
		_death_effects.append({"from": bug.pos, "kind": bug.kind, "rotation": bug.rotation, "size": bug.body_size, "life": 0.38, "drift": Vector2(bug.velocity).x * 0.15})
	_bugs.remove_at(index)

func _finish() -> void:
	if _over:
		return
	_over = true
	_health = maxi(0, _health)
	_best = maxi(_best, _score)
	_progress.best = _best
	_progress.save()
	_sound.silence()

func _draw() -> void:
	if not _background:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color("293747"))
	# Subtle dimming makes flying silhouettes readable in the room.
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.015, 0.03, 0.07, 0.12))
	_draw_helpers()
	for bug: Dictionary in _bugs:
		_draw_bug(bug)
	for effect: Dictionary in _death_effects:
		var t: float = 1 - float(effect.life) / 0.38
		var pos: Vector2 = effect.from + Vector2(float(effect.drift) * t, 65 * t * t)
		draw_set_transform(pos, float(effect.rotation) + t * 1.4, Vector2.ONE * float(effect.size) / 120)
		draw_texture_rect(_bug_texture(int(effect.kind)), HitGeometry.BUG_RECT, false, Color(0.8, 0.83, 0.86, 1 - t))
		draw_set_transform(Vector2.ZERO)
	for effect: Dictionary in _effects:
		var progress: float = 1.0 - float(effect.life) / (0.65 if effect.hit else 0.25)
		var color: Color = Color("dae6e9") if effect.hit else Color("edf3ee")
		color.a = 1.0 - progress
		draw_arc(effect.pos, 5 + progress * 12, 0, TAU, 32, Color(color, color.a * 0.3), 1, true)
		if effect.hit:
			_label(effect.pos + Vector2(-20, -30 - progress * 20), effect.text, 19, color)
	if _flash > 0:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.7, 0.16, 0.2, _flash * 0.4))
	if not _intro:
		_draw_hud()
	if _intro:
		_draw_intro()
	elif _shop:
		_draw_shop()
	elif _over:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.04, 0.09, 0.62))
		_center("생존" if _health > 0 else "밤 종료", 283, 40)
		_center("%d점" % _score, 345, 28)
		_center("클릭 · 다음 밤" if _health > 0 else "클릭 · 재도전", 410, 18)
	elif _paused:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.04, 0.09, 0.45))
		_center("Ⅱ", 345, 40)
		_center("P", 390, 18)
	if not _intro and not _over and not _paused and not _shop:
		var tool_position: Vector2 = _swat_pos if _swat > 0 else get_global_mouse_position()
		_draw_tool(tool_position)
		if _debug_hitboxes:
			_draw_hitboxes(tool_position)

func _draw_intro() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02, 0.035, 0.065, 0.65))
	_center("불 끄면 모기", 221, 42)
	var instruction: String = "마우스로 겨냥하고 클릭해 손뼉을 치세요."
	if _progress.equipped_tool == "swatter":
		instruction = "마우스로 겨냥하고 클릭해 신문지를 휘두르세요."
	elif _progress.equipped_tool == "electric":
		instruction = "마우스로 겨냥하고 클릭해 전기모기채를 휘두르세요."
	_center(instruction, 294, 22)
	_center("모기를 잡아 모은 코인으로 도구·자동 사냥 동료를 구매하세요.", 337, 21)
	_center("60초 생존하면 다음 밤 · 밤마다 더 많은 모기 · 다섯 번 물리면 종료", 379, 17)
	_center("1 · 2 · 3  도구     B  상점     P  일시정지     M  소리", 429, 15)
	var hover: bool = START_BUTTON.has_point(get_global_mouse_position())
	_box(START_BUTTON, Color("4b7562") if hover else Color("34594e"), 12)
	_center("시작  SPACE", 504, 22)

func _draw_hud() -> void:
	_label(Vector2(34, 48), "%03d" % _score, 30, Color("f6eddc"))
	draw_circle(Vector2(40, 75), 5, Color("edc580"))
	_label(Vector2(53, 81), str(_progress.wallet), 16, Color("edc580"))
	_label(Vector2(34, 111), "%d번째 밤" % _progress.night, 14, Color("c5c8c4"))
	_box(Rect2(948, 22, 170, 44), Color(0.06, 0.1, 0.14, 0.65), 10)
	_label(Vector2(1001, 50), "상점 B", 17, Color("efd6a0"))
	if _combo > 1:
		_label(Vector2(112, 47), "×%d" % _combo, 16, Color("9ff4db"))
	var timer_color: Color = Color("ffa8a0") if _remaining < 10 else Color("f5ecdc")
	_label(Vector2(1180, 48), "%02d" % int(ceil(_remaining)), 33, timer_color)
	for i: int in range(5):
		draw_circle(Vector2(1109 + i * 25, 100), 6, Color("f5b6a2") if i < _health else Color(0.6, 0.6, 0.65, 0.3))

func _build_wing_samples() -> void:
	# Exposure samples cover many rapid strokes; avoid sampling 800 Hz at 60 fps.
	for side: int in [-1, 1]:
		for sample: int in range(7):
			var angle: float = (sample - 3) * 0.13 * side
			var contour: PackedVector2Array = PackedVector2Array()
			var root: Vector2 = Vector2(side * 1.5, 0)
			var tip: Vector2 = Vector2(side * 35, 9).rotated(angle)
			for i: int in range(17):
				var t: float = i / 16.0
				contour.append(root.lerp(tip, t) + Vector2(0, -sin(t * PI) * 4).rotated(angle))
			for i: int in range(16, -1, -1):
				var t: float = i / 16.0
				contour.append(root.lerp(tip, t) + Vector2(0, sin(t * PI) * 3.4).rotated(angle))
			_wing_samples.append({"shape": contour, "root": root, "tip": tip, "weight": 0.021 + (3 - absi(sample - 3)) * 0.012, "vein": sample == 2 or sample == 4})

func _draw_bug(bug: Dictionary) -> void:
	var pos: Vector2 = bug.pos
	var kind: int = int(bug.kind)
	var scale_factor: float = float(bug.body_size) / 120.0
	if float(bug.life) < 3:
		draw_arc(pos, maxf(17, float(bug.body_size) * 0.32), -PI / 2, -PI / 2 + TAU * (1 - float(bug.life) / 3), 36, Color(0.85, 0.43, 0.36, 0.65), 1.2, true)
	draw_set_transform(pos, float(bug.rotation), Vector2.ONE * scale_factor)
	# Wings attach to the thorax and share the body pivot and depth scale.
	for wing: Dictionary in _wing_samples:
		var opacity: float = float(wing.weight) * float(bug.wing_energy) * (0.92 + sin(float(bug.phase) * 11 + float(bug.seed)) * 0.08)
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in wing.shape:
			points.append(Vector2(point.x * (0.98 + sin(float(bug.phase) * 8) * 0.025), point.y))
		draw_colored_polygon(points, Color(0.74, 0.81, 0.85, opacity))
		if wing.vein:
			draw_line(wing.root, wing.tip, Color(0.77, 0.8, 0.81, 0.08), 0.65, true)
	var tint: Color = Color(0.92, 0.94, 1.0) if kind != 2 else Color(1.0, 0.93, 0.74)
	if kind == 4:
		tint = Color(0.94, 0.79, 0.74)
	if float(bug.hurt_timer) > 0:
		tint = Color(1.0, 0.92, 0.76)
	draw_mesh(_motion.mesh("bug_%d" % int(bug.id), "mosquito", HitGeometry.BUG_RECT, float(bug.phase) + float(bug.seed)), _bug_texture(kind), Transform2D.IDENTITY, tint)
	if kind == 4 and int(bug.hp) > 1:
		for index: int in range(2):
			draw_circle(Vector2(-3 + index * 6, 64), 1.3, Color(0.84, 0.63, 0.47, 0.75))
	draw_set_transform(Vector2.ZERO)

func _bug_texture(kind: int) -> Texture2D:
	return _assets["mosquito_cautious"] if kind == 3 else _mosquito_texture

func _draw_tool(pos: Vector2) -> void:
	if _progress.equipped_tool == "hand":
		_draw_clap(pos)
		return
	var layout: Dictionary = _swing_layout if not _swing_tool.is_empty() else _tool_layout()
	var roll: float = _swat_roll if _swat > 0 else _tool_roll
	var u: float = 1 - _swat / _swing_duration if not _swing_tool.is_empty() else -1.0
	var pose: Transform2D = _weapon_pose(pos, layout, roll)
	if u >= Swing.WINDUP_END and u < Swing.FOLLOW_END:
		for index: int in range(2):
			var trail: Transform2D = Swing.pose(pos, _swing_tool, layout, maxf(0, u - (index + 1) * 0.045), roll)
			draw_set_transform_matrix(trail)
			draw_texture_rect(_assets[_progress.equipped_tool], layout.rect, false, Color(0.83, 0.88, 0.94, 0.055))
	draw_set_transform_matrix(pose)
	if _progress.equipped_tool == "swatter":
		draw_mesh(_motion.mesh("newspaper", "newspaper", layout.rect, _elapsed, Swing.paper_flex(u) if u >= 0 else 0), _assets["swatter"], Transform2D.IDENTITY, Color(0.83, 0.88, 0.94))
	else:
		draw_texture_rect(_assets[_progress.equipped_tool], layout.rect, false, Color(0.83, 0.88, 0.94))
	# The marker stays on the palm or mesh centre and exposes the aiming point.
	draw_circle(Vector2.ZERO, 1.5, Color(0.96, 0.98, 1, 0.65))
	if _zap > 0 and _progress.equipped_tool == "electric":
		for i: int in range(3 + _progress.levels["electric"]):
			var points: PackedVector2Array = PackedVector2Array()
			for j: int in range(6):
				var x: float = (j / 5.0 - 0.5) * float(layout.radii.x) * 1.2
				var y: float = (i / float(2 + _progress.levels["electric"]) - 0.5) * float(layout.radii.y) * 1.1
				points.append(Vector2(x, y + sin(floor(_elapsed * 60) * 3.7 + i * 13 + j * 5.3) * 4))
			draw_polyline(points, Color(0.73, 0.83, 1, _zap / 0.14 * 0.8), 1.3, true)
	draw_set_transform(Vector2.ZERO)
	if _zap > 0:
		for contact: Vector2 in _spark_positions:
			for i: int in range(5):
				var direction: Vector2 = Vector2.from_angle(i * TAU / 5 + _zap * 16)
				var length: float = 11 + sin(floor(_elapsed * 60) * 4.9 + i * 7.3) * 5
				draw_line(contact, contact + direction * length, Color(0.8, 0.88, 1, _zap / 0.14), 1.4, true)

func _draw_clap(pos: Vector2) -> void:
	var age: float = Clap.DURATION - _swat if _swat > 0 else -1.0
	var roll: float = _swat_roll if _swat > 0 else _tool_roll
	for side: int in [-1, 1]:
		if age > 0 and age < Clap.CONTACT_TIME:
			for sample: int in range(2):
				draw_set_transform_matrix(Clap.palm_pose(pos, side, maxf(0, age - (sample + 1) * 0.012), roll))
				draw_texture_rect(_assets["clap_hand"], Clap.HAND_RECT, false, Color(0.83, 0.88, 0.94, 0.055))
		draw_set_transform_matrix(Clap.palm_pose(pos, side, age, roll))
		draw_mesh(_motion.mesh("clap_%d" % side, "hand", Clap.HAND_RECT, _elapsed, 1 - Clap.openness(age)), _assets["clap_hand"], Transform2D.IDENTITY, Color(0.83, 0.88, 0.94))
	draw_set_transform(Vector2.ZERO)
	if _swat <= 0:
		draw_circle(pos, 1.5, Color(0.96, 0.98, 1, 0.65))

func _tool_layout() -> Dictionary:
	return HitGeometry.tool_layout(_progress.equipped_tool, _progress.reach(), _assets[_progress.equipped_tool].get_size())

func _weapon_pose(pos: Vector2, layout: Dictionary, roll: float) -> Transform2D:
	if not _swing_tool.is_empty():
		return Swing.pose(pos, _swing_tool, layout, 1 - _swat / _swing_duration, roll)
	return HitGeometry.tool_pose(pos, _progress.equipped_tool, 0, roll)

func _draw_hitboxes(pos: Vector2) -> void:
	var layout: Dictionary = _swing_layout if not _swing_tool.is_empty() else _tool_layout()
	var pose: Transform2D = _weapon_pose(pos, layout, _swat_roll if _swat > 0 else _tool_roll)
	var tool_outline: PackedVector2Array = HitGeometry.ellipse_outline(Vector2.ZERO, layout.radii, pose)
	tool_outline.append(tool_outline[0])
	var live: bool = not _swing_tool.is_empty() and Swing.active(1 - _swat / _swing_duration)
	draw_polyline(tool_outline, Color(0.3, 1, 0.8, 0.9) if live else Color(0.6, 0.78, 0.82, 0.45), 1.3, true)
	for bug: Dictionary in _bugs:
		for outline: PackedVector2Array in HitGeometry.bug_outlines(bug):
			outline.append(outline[0])
			draw_polyline(outline, Color(1, 0.72, 0.27, 0.8), 1.0, true)

func _label(pos: Vector2, text: String, size: int, color: Color) -> void:
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.02, 0.04, 0.08, 0.5))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(text: String, y: float, size: int) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_label(Vector2((1280 - width) / 2, y), text, size, Color("f9ebd3"))

func _update_auto(delta: float) -> void:
	for effect: Dictionary in _auto_effects:
		effect.life -= delta
	_auto_effects = _auto_effects.filter(func(e: Dictionary) -> bool: return float(e.life) > 0)
	for id: String in _prop_pulse:
		_prop_pulse[id] = maxf(0, _prop_pulse[id] - delta)
	for id: String in ["trap", "flytrap", "sundew", "dragonfly"]:
		if _progress.levels[id] <= 0:
			continue
		_auto_timers[id] -= delta
		if id == "dragonfly":
			continue
		if _auto_timers[id] > 0:
			continue
		var origin: Vector2 = _helper_origin(id)
		var reach: float = 360.0 + (_progress.levels[id] - 1) * 60.0
		var count: int = 2 if id == "sundew" else 1
		var captured: bool = false
		for n: int in range(count):
			var index: int = -1
			if id == "trap":
				index = _nearest_bug(origin, reach)
			else:
				var nearest: float = INF
				for leaf: int in range(4):
					if not _leaf_available(id, leaf):
						continue
					var mouth: Vector2 = _helper_origin(id, leaf)
					var candidate: int = _nearest_bug(mouth, 20 + _progress.levels[id] * 3)
					if candidate >= 0 and mouth.distance_to(_bugs[candidate].pos) < nearest:
						index = candidate
						origin = mouth
						nearest = mouth.distance_to(_bugs[candidate].pos)
			if index >= 0:
				_capture(index, id, origin)
				captured = true
		_auto_timers[id] = _progress.interval(id) if captured else 0.3
	if _progress.levels["dragonfly"] <= 0:
		return
	if _dragon_target < 0 and _auto_timers["dragonfly"] <= 0:
		var next: int = _nearest_bug(_dragon_pos, 2000)
		if next >= 0:
			_dragon_target = int(_bugs[next].id)
	var target_index: int = -1
	for i: int in range(_bugs.size()):
		if int(_bugs[i].id) == _dragon_target:
			target_index = i
			break
	if _dragon_target >= 0 and target_index < 0:
		_dragon_target = -1
	_dragon_waypoint_timer -= delta
	if _dragon_waypoint_timer <= 0 or _dragon_pos.distance_to(_dragon_waypoint) < 12:
		_dragon_waypoint = Vector2(randf_range(480, 960), randf_range(180, 360))
		_dragon_waypoint_timer = randf_range(2.2, 4.5)
	var target: Vector2 = _bugs[target_index].pos if target_index >= 0 else _dragon_waypoint
	var state: Dictionary = {"pos": _dragon_pos, "velocity": _dragon_velocity, "angle": _dragon_rotation, "bank": _dragon_bank}
	Motion.advance_dragon(state, target, delta, target_index >= 0, _progress.levels["dragonfly"])
	_dragon_pos = state.pos
	_dragon_velocity = state.velocity
	_dragon_rotation = state.angle
	_dragon_bank = state.bank
	if target_index >= 0 and _dragon_pos.distance_to(target) < 26:
		_capture(target_index, "dragonfly", _dragon_pos + Vector2(0, -15).rotated(_dragon_rotation))
		_dragon_target = -1
		_auto_timers["dragonfly"] = _progress.interval("dragonfly")

func _nearest_bug(pos: Vector2, radius: float) -> int:
	var closest: float = radius
	var index: int = -1
	for i: int in range(_bugs.size()):
		var distance: float = pos.distance_to(_bugs[i].pos)
		if distance <= closest:
			closest = distance
			index = i
	return index

func _prop_rect(id: String) -> Rect2:
	return Props.sprite_rect(id, _assets[id].get_size(), _prop_visible[id])

func _leaf_available(id: String, leaf: int) -> bool:
	var key: String = "%s_%d" % [id, leaf]
	return not _motion_actions.has(key) or _elapsed - float(_motion_actions[key].start) > 5.5

func _plant_actions(id: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for leaf: int in range(4):
		var key: String = "%s_%d" % [id, leaf]
		if _motion_actions.has(key):
			var age: float = _elapsed - float(_motion_actions[key].start)
			if age < 5.5:
				actions.append({"age": age, "leaf": leaf})
	return actions

func _helper_origin(id: String, leaf: int = 0) -> Vector2:
	var rect: Rect2 = _prop_rect(id)
	var uv: Vector2 = Vector2(0.5, 0.20)
	if id == "flytrap":
		uv = Motion.FLYTRAP_MOUTHS[leaf]
	elif id == "sundew":
		uv = Motion.SUNDEW_MOUTHS[leaf]
	if id in ["flytrap", "sundew"]:
		uv = Motion.deform(id, uv, _elapsed, -1)
	return PROP_POS[id] + rect.position + uv * rect.size

func _closest_leaf(id: String, pos: Vector2) -> int:
	var chosen: int = 0
	var distance: float = INF
	for leaf: int in range(4):
		if not _leaf_available(id, leaf):
			continue
		var current: float = pos.distance_to(_helper_origin(id, leaf))
		if current < distance:
			distance = current
			chosen = leaf
	return chosen

func _flight_attractor(pos: Vector2) -> Vector2:
	var closest: float = INF
	var chosen: Vector2 = Vector2.INF
	for id: String in ["trap", "flytrap", "sundew"]:
		if _progress.levels[id] <= 0:
			continue
		var leaf: int = _closest_leaf(id, pos) if id != "trap" else 0
		if id != "trap" and not _leaf_available(id, leaf):
			continue
		var origin: Vector2 = _helper_origin(id, leaf)
		var distance: float = pos.distance_to(origin)
		if distance < closest and distance < (350 if id == "trap" else 260 + _progress.levels[id] * 35):
			chosen = origin
			closest = distance
	return chosen

func _draw_helpers() -> void:
	for id: String in ["trap", "flytrap", "sundew"]:
		if _progress.levels[id] <= 0:
			continue
		var pos: Vector2 = PROP_POS[id]
		var pulse: float = _prop_pulse.get(id, 0.0)
		var rect: Rect2 = _prop_rect(id)
		var texture: Texture2D = _assets[id]
		# Layered contact shadows stay on the same support plane as each base.
		for layer: int in range(3):
			draw_set_transform(pos + Vector2(2 + layer * 1.5, 0.4), 0.02, Vector2(1, 0.13))
			draw_circle(Vector2.ZERO, float(Props.FOOT_WIDTHS[id]) + layer * 3, Color(0, 0, 0, 0.12 - layer * 0.025))
		draw_set_transform(pos)
		if id in ["flytrap", "sundew"]:
			draw_mesh(_motion.mesh(id, id, rect, _elapsed, -1, 0, _plant_actions(id)), texture, Transform2D.IDENTITY, Props.tint(id))
		else:
			draw_texture_rect(texture, rect, false, Props.tint(id))
		draw_set_transform(Vector2.ZERO)
		if id == "trap":
			_draw_intake(_helper_origin("trap"), pulse)
	if _progress.levels["dragonfly"] > 0:
		_draw_dragonfly()
	for effect: Dictionary in _auto_effects:
		var t: float = clampf(1.0 - float(effect.life) / 0.65, 0, 1)
		var ease: float = t * t * (3 - 2 * t)
		var destination: Vector2 = effect.to
		if effect.kind == "dragonfly":
			destination = _dragon_pos + Vector2(0, -15).rotated(_dragon_rotation)
		elif effect.kind in ["flytrap", "sundew"]:
			var id: String = effect.kind
			var leaf: int = effect.leaf
			var uv: Vector2 = Motion.FLYTRAP_MOUTHS[leaf] if id == "flytrap" else Motion.SUNDEW_MOUTHS[leaf]
			var age: float = _elapsed - float(_motion_actions["%s_%d" % [id, leaf]].start)
			var rect: Rect2 = _prop_rect(id)
			destination = PROP_POS[id] + rect.position + Motion.deform(id, uv, _elapsed, age, leaf) * rect.size
		var pos: Vector2 = effect.from.lerp(destination, ease)
		if effect.kind == "trap":
			pos += Vector2(sin(t * TAU * 1.5), cos(t * TAU * 1.5)) * (1 - t) * t * 20
		var scale_factor: float = float(effect.size) / 120.0 * (1.0 - t * 0.35)
		draw_set_transform(pos, float(effect.rotation) + (t * 1.8 if effect.kind == "trap" else t * 0.4), Vector2.ONE * scale_factor)
		draw_texture_rect(_bug_texture(int(effect.get("bug_kind", 0))), HitGeometry.BUG_RECT, false, Color(0.8, 0.85, 0.9, 1 - smoothstep(0.62, 1.0, t)))
		draw_set_transform(Vector2.ZERO)

func _draw_intake(origin: Vector2, pulse: float) -> void:
	draw_set_transform(origin, 0, Vector2(1, 0.34))
	for sample: int in range(5):
		var angle: float = _elapsed * 8 + sample * 0.18
		for blade: int in range(3):
			var start: float = angle + blade * TAU / 3
			draw_arc(Vector2.ZERO, 10 + sample * 0.6, start, start + 0.55, 12, Color(0.3, 0.35, 0.43, 0.045 + pulse * 0.045), 3, true)
	draw_arc(Vector2.ZERO, 17, 0, TAU, 40, Color(0.62, 0.57, 0.96, 0.16 + pulse * 0.2), 1, true)
	draw_set_transform(Vector2.ZERO)
	for index: int in range(9):
		var t: float = fposmod(_elapsed * (0.38 + pulse * 0.5) + index / 9.0, 1)
		var angle: float = index * 2.399 + t * 2.8
		var pos: Vector2 = origin + Vector2(cos(angle), sin(angle) * 0.5) * (9 + (1 - t) * 26)
		draw_circle(pos, 0.8, Color(0.8, 0.85, 0.91, sin(t * PI) * (0.13 + pulse * 0.28)))

func _draw_dragonfly() -> void:
	draw_set_transform(_dragon_pos, _dragon_rotation)
	var wing_polygons: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0.485, 0.31), Vector2(0.18, 0.16), Vector2(0.02, 0.14), Vector2(0.00, 0.25), Vector2(0.22, 0.36), Vector2(0.47, 0.36)]),
		PackedVector2Array([Vector2(0.48, 0.365), Vector2(0.22, 0.35), Vector2(0.01, 0.39), Vector2(0.02, 0.53), Vector2(0.30, 0.54), Vector2(0.48, 0.41)]),
	]
	for side: int in [-1, 1]:
		for pair: int in range(2):
			for sample: int in range(3):
				var uvs: PackedVector2Array = PackedVector2Array()
				var points: PackedVector2Array = PackedVector2Array()
				var spread: float = 0.85 + sin(_elapsed * 8.3 + pair * 1.7) * 0.10 + (sample - 1) * 0.07 - absf(_dragon_bank) * 0.35
				var pitch: float = sin(_elapsed * 7.1 + pair * 0.9) * 0.12 + (sample - 1) * 0.08
				for uv: Vector2 in wing_polygons[pair]:
					var source: Vector2 = Vector2(uv.x if side == -1 else 1 - uv.x, uv.y)
					uvs.append(source)
					var local: Vector2 = (source - Vector2(0.5, 0.33)) * 96
					local.x *= spread
					points.append(local.rotated(pitch * side))
				draw_polygon(points, PackedColorArray([Color(0.82, 0.9, 0.95, 0.28)]), uvs, _assets["dragonfly"])
	var rect: Rect2 = Rect2(-48, -96 * 0.26, 96, 96)
	draw_mesh(_motion.mesh("dragonfly_body", "dragonfly_body", rect, _elapsed), _assets["dragonfly_body"], Transform2D.IDENTITY, Color(0.87, 0.92, 0.97))
	draw_set_transform(Vector2.ZERO)

func _shop_rect(index: int) -> Rect2:
	return Rect2(110 + (index % 4) * 268, 180 + int(index / 4.0) * 212, 252, 198)

func _shop_click(pos: Vector2) -> void:
	if Rect2(1107, 105, 50, 44).has_point(pos):
		_toggle_shop()
		return
	for i: int in range(Progression.CATALOG.size()):
		var rect: Rect2 = _shop_rect(i)
		if not Rect2(rect.position + Vector2(14, 155), Vector2(224, 31)).has_point(pos):
			continue
		var item: Dictionary = Progression.CATALOG[i]
		var locked: String = _progress.requirement(item.id)
		if not locked.is_empty():
			_shop_message = locked + " 후 열립니다."
		elif _progress.levels[item.id] >= int(item.max):
			_shop_message = item.name + " · 최고 단계입니다."
		else:
			var previous_tool: String = _progress.equipped_tool
			if not _progress.purchase(item.id):
				_shop_message = "%d코인 부족" % (_progress.cost(item.id) - _progress.wallet)
				return
			if _progress.equipped_tool != previous_tool:
				_clap_pending = false
				_swat = 0
				_swing_tool = ""
				_swing_layout.clear()
			_shop_message = item.name + " Lv.%d" % _progress.levels[item.id]
			if _auto_timers.has(item.id):
				_auto_timers[item.id] = minf(1, _progress.interval(item.id))
			_sound.play_event("purchase", pos, -7)

func _draw_shop() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.015, 0.025, 0.045, 0.74))
	_box(Rect2(80, 90, 1120, 562), Color(0.045, 0.065, 0.085, 0.96), 18)
	_label(Vector2(112, 132), "상점", 29, Color("f4e1bd"))
	_label(Vector2(720, 130), "보유  %d 코인" % _progress.wallet, 24, Color("e8c483"))
	_label(Vector2(1118, 134), "×", 30, Color("d7dfe2"))
	var mouse: Vector2 = get_global_mouse_position()
	for i: int in range(Progression.CATALOG.size()):
		var item: Dictionary = Progression.CATALOG[i]
		var rect: Rect2 = _shop_rect(i)
		var level: int = _progress.levels[item.id]
		var capped: bool = level >= int(item.max)
		var locked: String = _progress.requirement(item.id)
		var price: int = _progress.cost(item.id)
		var affordable: bool = _progress.wallet >= price and not capped and locked.is_empty()
		_box(rect, Color("182832"), 10)
		_draw_thumbnail(_assets[item.asset], Rect2(rect.position + Vector2(12, 12), Vector2(55, 62)))
		_label(rect.position + Vector2(78, 34), item.name, 16, Color("ecdcc0"))
		_label(rect.position + Vector2(78, 58), "Lv.%d / %d" % [level, item.max], 13, Color("86b5ac"))
		var lines: PackedStringArray = String(item.detail).split(" · ")
		for j: int in range(mini(lines.size(), 3)):
			_label(rect.position + Vector2(15, 92 + j * 19), lines[j], 12, Color("b3c2c6"))
		if item.id in ["trap", "flytrap", "sundew", "dragonfly"] and level > 0:
			_label(rect.position + Vector2(15, 143), "현재 간격 %.1f초" % _progress.interval(item.id), 11, Color("86a3b4"))
		var button: Rect2 = Rect2(rect.position + Vector2(14, 155), Vector2(224, 31))
		var color: Color = Color("34594e") if affordable else Color("2a3740")
		if affordable and button.has_point(mouse):
			color = Color("4b7562")
		_box(button, color, 6)
		var text: String = "최고 단계" if capped else ("구매" if level == 0 else "강화") + "  ·  %d 코인" % price
		if not locked.is_empty():
			text = locked
		_label(button.position + Vector2(12, 21), text, 14, Color("f2e3c4") if affordable else Color("879ba3"))
	_label(Vector2(112, 628), _shop_message, 14, Color("d7c6a5"))

func _draw_thumbnail(texture: Texture2D, rect: Rect2) -> void:
	var scale_factor: float = minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var size: Vector2 = texture.get_size() * scale_factor
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - size) / 2, size), false)

func _box(rect: Rect2, color: Color, radius: int) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)
