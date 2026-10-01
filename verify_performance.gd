extends SceneTree
## Repeatable CPU drawing workload, independent of screen refresh rate.
class MeasuredGame:
	extends "res://main.gd"
	var draw_times: Array[int] = []
	func _draw() -> void:
		var started: int = Time.get_ticks_usec()
		super._draw()
		draw_times.append(Time.get_ticks_usec() - started)

var game: MeasuredGame

func _initialize() -> void:
	call_deferred("_benchmark")

func _benchmark() -> void:
	assert("--verify-game" in OS.get_cmdline_user_args(), "isolated test saves required")
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game = MeasuredGame.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game._intro = false
	game._paused = false
	game._over = false
	game._progress.night = 12
	for id: String in game._progress.levels:
		game._progress.levels[id] = 3
	game._progress.equipped_tool = "hand"
	game._bugs.clear()
	for index: int in range(12):
		game._bugs.append(game.Flight.create(index + 1, index % 5, Vector2(200 + index * 60, 270 + index % 3 * 40), 100 + index))
	for index: int in range(40):
		game._elapsed = index / 60.0
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	game.draw_times.clear()
	for index: int in range(240):
		game._elapsed = index / 60.0
		for bug: Dictionary in game._bugs:
			bug.phase += 1.0 / 60
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	game.draw_times.sort()
	var total: int = 0
	for value: int in game.draw_times:
		total += value
	var result: Dictionary = {"scenario": "12 mosquitoes, all utilities, two hands, 240 draws", "samples": game.draw_times.size(), "mean_draw_us": total / float(game.draw_times.size()), "p50_draw_us": game.draw_times[game.draw_times.size() / 2], "p95_draw_us": game.draw_times[int(game.draw_times.size() * 0.95)], "texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
	print("BENCHMARK ", JSON.stringify(result))
	game._sound.silence()
	game.queue_free()
	await process_frame
	quit()
