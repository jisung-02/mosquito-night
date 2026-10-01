class_name NightAudio
extends Node2D
## Separate positional voices let impacts and autonomous devices overlap.
const EVENTS: Array[String] = ["hand_hit", "hand_miss", "swing", "paper_swing", "paper_hit", "zap", "trap", "flytrap", "sundew", "dragonfly", "purchase"]
const VOICE_COUNT: int = 16
var muted: bool = false
var last_event: String = ""
var event_counts: Dictionary[String, int] = {}
var _clips: Dictionary[String, Array] = {}
var _voices: Array[AudioStreamPlayer2D] = []
var _loops: Dictionary[String, AudioStreamPlayer2D] = {}
var _next_voice: int = 0
var _was_active: bool = true

func _ready() -> void:
	for event: String in EVENTS:
		var variants: Array[AudioStream] = []
		for variant: int in range(1, 4):
			variants.append(load("res://assets/audio/%s_%d.wav" % [event, variant]) as AudioStream)
		_clips[event] = variants
		event_counts[event] = 0
	for index: int in range(VOICE_COUNT):
		var voice: AudioStreamPlayer2D = _create_voice()
		_voices.append(voice)
	for id: String in ["mosquito", "fan", "dragonfly"]:
		var player: AudioStreamPlayer2D = _create_voice()
		var stream: AudioStreamWAV = load("res://assets/audio/" + id + "_loop.wav") as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
		player.volume_db = -80
		player.play()
		_loops[id] = player

func play_event(event: String, pos: Vector2, volume: float = -5.0) -> void:
	if muted or not _clips.has(event):
		return
	last_event = event
	event_counts[event] += 1
	var voice: AudioStreamPlayer2D = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	voice.stop()
	voice.position = pos
	voice.stream = _clips[event].pick_random() as AudioStream
	voice.volume_db = volume + randf_range(-1.0, 0.7)
	voice.pitch_scale = randf_range(0.97, 1.035)
	voice.play()

func set_muted(value: bool) -> void:
	muted = value
	if muted:
		silence()

func silence() -> void:
	for voice: AudioStreamPlayer2D in _voices:
		voice.stop()
	for player: AudioStreamPlayer2D in _loops.values():
		player.volume_db = -80

func update_room(delta: float, bugs: Array[Dictionary], active: bool, levels: Dictionary[String, int], dragon_pos: Vector2) -> void:
	if muted:
		silence()
		return
	if not active:
		# Cut gameplay tails once, then allow the shop's purchase click to finish.
		if _was_active:
			silence()
		_was_active = false
		return
	_was_active = true
	var nearest: Dictionary = {}
	var distance: float = INF
	for bug: Dictionary in bugs:
		var current: float = bug.pos.distance_to(Vector2(640, 580))
		if current < distance:
			distance = current
			nearest = bug
	var mosquito: AudioStreamPlayer2D = _loops["mosquito"]
	var target_volume: float = -80.0
	if not nearest.is_empty():
		mosquito.position = mosquito.position.lerp(nearest.pos, 1 - exp(-delta * 5))
		mosquito.pitch_scale = lerpf(mosquito.pitch_scale, 0.94 + float(nearest.wing_energy) * 0.12, 1 - exp(-delta * 3))
		target_volume = -30.0 + float(nearest.depth) * 8 - minf(8, distance / 90)
	mosquito.volume_db = lerpf(mosquito.volume_db, target_volume, 1 - exp(-delta * 8))
	_loops["fan"].position = Vector2(1146, 248) if levels["fan"] > 0 else Vector2(1106, 288)
	_loops["fan"].volume_db = -30 + levels["fan"] * 1.5 if levels["fan"] > 0 else (-34 if levels["trap"] > 0 else -80)
	_loops["dragonfly"].position = dragon_pos
	_loops["dragonfly"].volume_db = -34 if levels["dragonfly"] > 0 else -80

func _create_voice() -> AudioStreamPlayer2D:
	var voice: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	voice.max_distance = 2000
	voice.attenuation = 0.0
	voice.panning_strength = 0.7
	voice.max_polyphony = 1
	add_child(voice)
	return voice
