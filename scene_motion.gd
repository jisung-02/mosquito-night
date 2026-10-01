class_name NightMotion
extends RefCounted
## Local mesh rigs leave rigid supports fixed; independent appendages can bend.
const FLYTRAP_MOUTHS: Array[Vector2] = [Vector2(0.22, 0.30), Vector2(0.55, 0.145), Vector2(0.80, 0.36), Vector2(0.64, 0.53)]
const SUNDEW_MOUTHS: Array[Vector2] = [Vector2(0.24, 0.20), Vector2(0.44, 0.13), Vector2(0.69, 0.20), Vector2(0.80, 0.32)]
var _meshes: Dictionary[String, ArrayMesh] = {}
var _grids: Dictionary[String, Dictionary] = {}

static func closing(age: float, id: String) -> float:
	if age < 0:
		return 0.0
	if id == "sundew":
		return smoothstep(0.3, 2.0, age) * (1 - smoothstep(3.0, 5.5, age))
	return smoothstep(0.3, 0.6, age) * (1 - smoothstep(3.3, 5.5, age))

static func deform(id: String, uv: Vector2, time: float, age: float, leaf: int = 0) -> Vector2:
	var offset: Vector2 = Vector2.ZERO
	if id in ["flytrap", "sundew"]:
		var living: float = 1 - smoothstep(0.56, 0.67, uv.y)
		offset.x = (sin(time * 1.2 + uv.y * 5) + sin(time * 0.73 + uv.x * 7) * 0.45) * 0.009 * living
		var mouths: Array[Vector2] = FLYTRAP_MOUTHS if id == "flytrap" else SUNDEW_MOUTHS
		var center: Vector2 = mouths[leaf % mouths.size()]
		var delta: Vector2 = uv - center
		var radius: Vector2 = Vector2(0.15, 0.14) if id == "flytrap" else Vector2(0.17, 0.23)
		var weight: float = exp(-pow((delta / radius).length(), 4)) * living
		var shut: float = closing(age, id)
		if id == "flytrap":
			# The two lobes fold onto their central seam rather than squash the pot.
			offset.y -= delta.y * shut * 0.80 * weight
			offset.x += delta.x * shut * 0.035 * weight
		else:
			var angle: float = shut * 0.63 * weight * (1 if center.x < 0.5 else -1)
			offset += delta.rotated(angle) - delta
			offset.y += shut * 0.075 * weight
	elif id == "newspaper":
		var exposed: float = 1 - smoothstep(0.54, 0.64, uv.y)
		# Paper flexes on recoil, while the grip and contact-time shape stay rigid.
		offset.x = maxf(0, age) * 0.020 * exposed * exposed
	elif id == "hand":
		var fingers: float = 1 - smoothstep(0.26, 0.45, uv.y)
		offset.x = sin(time * 1.8 + uv.x * 12) * 0.002 * fingers
		offset.y = (sin(time * 1.1) * 0.0015 + maxf(0, age) * 0.014) * fingers
	elif id == "mosquito":
		var legs: float = smoothstep(0.13, 0.44, absf(uv.x - 0.5))
		offset.x = sin(time * 9 + uv.y * 17) * 0.008 * legs
		offset.y = cos(time * 7 + uv.x * 15) * 0.009 * legs
	elif id == "dragonfly_body":
		var tail: float = smoothstep(0.40, 0.93, uv.y)
		offset.x = sin(time * 4.7 + uv.y * 3) * 0.009 * tail
		var legs: float = smoothstep(0.10, 0.23, absf(uv.x - 0.5)) * (1 - smoothstep(0.4, 0.6, uv.y))
		offset.y = sin(time * 8 + uv.x * 15) * 0.006 * legs
	return uv + offset

static func advance_dragon(state: Dictionary, target: Vector2, delta: float, pursuing: bool, level: int) -> void:
	var left: float = maxf(0, delta)
	while left > 0.000001:
		var step: float = minf(left, 1.0 / 120.0)
		var difference: Vector2 = target - Vector2(state.pos)
		var top_speed: float = 270.0 + level * 55 if pursuing else 95.0
		var desired: Vector2 = difference.normalized() * minf(top_speed, difference.length() * 5)
		state.velocity = Vector2(state.velocity).move_toward(desired, (1200.0 if pursuing else 340.0) * step)
		state.pos += Vector2(state.velocity) * step
		if Vector2(state.velocity).length() > 4:
			var target_angle: float = Vector2(state.velocity).angle() + PI / 2
			var turn: float = clampf(angle_difference(float(state.angle), target_angle), -4.5 * step, 4.5 * step)
			state.angle += turn
			state.bank = lerpf(float(state.bank), clampf(turn / step * 0.055, -0.22, 0.22), 1 - exp(-step * 6))
		left -= step

static func larva_path(index: int, time: float, width: float, height: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var phase: float = time * (1.5 + index * 0.16) + index * 2.3
	var center: Vector2 = Vector2(0.33 + index * 0.11 + sin(phase * 0.31) * 0.025, 0.53 + (index % 3) * 0.085)
	for segment: int in range(13):
		var t: float = segment / 12.0
		var point: Vector2 = center + Vector2(sin(phase + t * 4.2) * 0.037 * t, t * (0.13 if index > 0 else 0.23))
		point.x += sin(phase * 0.7) * 0.02 * t
		points.append(Vector2((point.x - 0.5) * width, (point.y - 1) * height))
	return points

func mesh(key: String, id: String, rect: Rect2, time: float, age: float = -1.0, leaf: int = 0, actions: Array[Dictionary] = []) -> ArrayMesh:
	if not _grids.has(id):
		_grids[id] = _build_grid(id)
	var grid: Dictionary = _grids[id]
	var uvs: PackedVector2Array = grid.uvs
	var vertices: PackedVector3Array = PackedVector3Array()
	vertices.resize(uvs.size())
	for index: int in range(uvs.size()):
		var uv: Vector2 = uvs[index]
		var deformed: Vector2 = deform(id, uv, time, age, leaf)
		for action: Dictionary in actions:
			deformed += deform(id, uv, 0, float(action.age), int(action.leaf)) - deform(id, uv, 0, -1, 0)
		var point: Vector2 = rect.position + deformed * rect.size
		vertices[index] = Vector3(point.x, point.y, 0)
	if not _meshes.has(key):
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = grid.indices
		var created: ArrayMesh = ArrayMesh.new()
		created.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		_meshes[key] = created
	else:
		# UVs and triangles stay on the GPU; upload only changed positions.
		_meshes[key].surface_update_vertex_region(0, 0, vertices.to_byte_array())
	var result: ArrayMesh = _meshes[key]
	result.custom_aabb = AABB(Vector3(rect.position.x - rect.size.x * 0.1, rect.position.y - rect.size.y * 0.1, -0.1), Vector3(rect.size.x * 1.2, rect.size.y * 1.2, 0.2))
	return result

func release(key: String) -> void:
	_meshes.erase(key)

func reset() -> void:
	_meshes.clear()

func _build_grid(id: String) -> Dictionary:
	# Small insects need fewer vertices than hands and folding plant leaves.
	var columns: int = 8 if id in ["mosquito", "dragonfly_body"] else 12
	var rows: int = 12 if columns == 8 else 18
	if id in ["flytrap", "sundew"]:
		columns = 14
		rows = 22
	elif id == "newspaper":
		columns = 4
		rows = 18
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for row: int in range(rows + 1):
		for column: int in range(columns + 1):
			uvs.append(Vector2(column / float(columns), row / float(rows)))
	for row: int in range(rows):
		for column: int in range(columns):
			var a: int = row * (columns + 1) + column
			indices.append_array(PackedInt32Array([a, a + 1, a + columns + 1, a + 1, a + columns + 2, a + columns + 1]))
	return {"uvs": uvs, "indices": indices}
