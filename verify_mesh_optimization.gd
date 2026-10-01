extends SceneTree
const Motion = preload("res://scene_motion.gd")
var _motion: NightMotion = Motion.new()

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var maximum: float = 0.0
	for id: String in ["mosquito", "dragonfly_body", "hand", "newspaper", "flytrap", "sundew"]:
		var grid: Dictionary = _motion._build_grid(id)
		var columns: int = 8 if id in ["mosquito", "dragonfly_body"] else (4 if id == "newspaper" else (14 if id in ["flytrap", "sundew"] else 12))
		var rows: int = 12 if columns == 8 else (22 if columns == 14 else 18)
		var size: Vector2 = Vector2(70, 70) if columns == 8 else (Vector2(280, 390) if id == "hand" else Vector2(207, 310))
		if id in ["flytrap", "sundew"]:
			size = Vector2.ONE * (69 if id == "flytrap" else 59)
		for time: float in [0.0, 0.5, 1.4, 3.5]:
			var age: float = minf(time, 1.0) if id in ["newspaper", "hand"] else time
			for y: int in range(51):
				for x: int in range(51):
					var uv: Vector2 = Vector2(x / 50.0, y / 50.0)
					var cell_x: int = mini(columns - 1, int(uv.x * columns))
					var cell_y: int = mini(rows - 1, int(uv.y * rows))
					var part: Vector2 = uv * Vector2(columns, rows) - Vector2(cell_x, cell_y)
					var a: int = cell_y * (columns + 1) + cell_x
					var expected: Vector2 = Motion.deform(id, uv, time, age, 0)
					var interpolated: Vector2
					if part.x + part.y <= 1:
						interpolated = Motion.deform(id, grid.uvs[a], time, age, 0) * (1 - part.x - part.y) + Motion.deform(id, grid.uvs[a + 1], time, age, 0) * part.x + Motion.deform(id, grid.uvs[a + columns + 1], time, age, 0) * part.y
					else:
						interpolated = Motion.deform(id, grid.uvs[a + columns + 2], time, age, 0) * (part.x + part.y - 1) + Motion.deform(id, grid.uvs[a + 1], time, age, 0) * (1 - part.y) + Motion.deform(id, grid.uvs[a + columns + 1], time, age, 0) * (1 - part.x)
					maximum = maxf(maximum, ((expected - interpolated) * size).length())
		var rect: Rect2 = Rect2(-size * 0.5, size)
		var mesh: ArrayMesh = _motion.mesh(id, id, rect, 0, -1)
		var rid: RID = mesh.get_rid()
		var triangles: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var updated: ArrayMesh = _motion.mesh(id, id, rect, 1.2, 0.5)
		assert(updated.get_rid() == rid and updated.get_surface_count() == 1, "mesh GPU resource retained")
		assert(updated.surface_get_arrays(0)[Mesh.ARRAY_INDEX] == triangles, "topology retained across motion")
		assert(grid.uvs.size() < 609, "vertex count actually reduced")
	if maximum >= 1.0:
		push_error("Mesh approximation exceeds a pixel: %.3f" % maximum)
		quit(1)
		return
	print("PASS: GPU mesh reuse; stable indices; reduced vertices; worst-case interpolation error %.3fpx" % maximum)
	quit()
