extends SceneTree
const HitGeometry = preload("res://hit_geometry.gd")

func _initialize() -> void:
	var bug: Dictionary = {"pos": Vector2.ZERO, "rotation": 0.0, "body_size": 70.0}
	var probe: Vector2 = Vector2(2, 2)
	assert(HitGeometry.contact(bug, Transform2D(0, Vector2(0, 12)), probe).hit, "body overlap")
	assert(HitGeometry.contact(bug, Transform2D(0, Vector2(17, 2)), probe).hit, "wing overlap")
	assert(not HitGeometry.contact(bug, Transform2D(0, Vector2(33, 38)), probe).hit, "thin leg tips excluded")
	assert(not HitGeometry.contact(bug, Transform2D(0, Vector2(33, -23)), probe).hit, "transparent sprite corners excluded")
	bug.body_size = 42.0
	assert(not HitGeometry.contact(bug, Transform2D(0, Vector2(19, 2)), probe).hit, "small mosquito has small hurtbox")
	bug.body_size = 70.0
	assert(HitGeometry.contact(bug, Transform2D(0, Vector2(19, 2)), probe).hit, "same wing probe hits larger mosquito")
	for tool: String in ["hand", "swatter", "electric"]:
		for reach: float in ([29.0] if tool == "hand" else [47.0, 59.0, 115.0]):
			var layout: Dictionary = HitGeometry.tool_layout(tool, reach, Vector2(1024, 1536))
			assert(is_equal_approx(maxf(layout.radii.x, layout.radii.y), reach), "drawn surface and upgraded range grow together")
			var pivot: Vector2 = Vector2(0.53, 0.56) if tool == "hand" else (Vector2(0.5, 0.255) if tool == "electric" else Vector2(0.54, 0.31))
			assert((layout.rect.position + layout.rect.size * pivot).length() < 0.0001, "aim at visible palm or mesh pivot")
			var pose: Transform2D = HitGeometry.tool_pose(Vector2(500, 350), tool, 1)
			for angle: float in [-0.45, 0.0, 0.45]:
				for size: float in [42.0, 70.0]:
					bug = {"pos": pose.origin, "rotation": angle, "body_size": size}
					assert(HitGeometry.contact(bug, pose, layout.radii).hit, "rotated body in tool surface")
					# The insect centre lies outside the surface, but part of its wing crosses the edge.
					bug.pos = pose * Vector2(layout.radii.x + 5, 0)
					var result: Dictionary = HitGeometry.contact(bug, pose, layout.radii)
					assert(result.hit, "partial overlap counts even when centre is outside")
					assert(((pose.affine_inverse() * result.point) / layout.radii).length() <= 1.0001, "spark starts inside the touching surface")
					bug.pos = pose * Vector2(layout.radii.x + 40, 0)
					assert(not HitGeometry.contact(bug, pose, layout.radii).hit, "clearly separated target misses")
			# A handle/wrist or finger is visible here, but it is not the striking face.
			bug.pos = pose * Vector2(0, layout.rect.size.y * (0.88 - pivot.y))
			bug.body_size = 42.0
			assert(not HitGeometry.contact(bug, pose, layout.radii).hit, "handle or wrist does not capture")
	var palm: Dictionary = HitGeometry.tool_layout("hand", 29, Vector2(1024, 1536))
	var paper: Dictionary = HitGeometry.tool_layout("swatter", 47, Vector2(1024, 1536))
	assert(paper.radii.y > palm.radii.y * 1.5 and paper.radii.x < palm.radii.x * 0.7, "newspaper is distinctly longer and narrower than clapping palms")
	var hand_pose: Transform2D = HitGeometry.tool_pose(Vector2.ZERO, "hand", 1)
	var paper_pose: Transform2D = HitGeometry.tool_pose(Vector2.ZERO, "swatter", 1)
	for roll: float in [-0.3, 0.0, 0.3]:
		var turn: Transform2D = Transform2D(roll, Vector2.ZERO)
		var long_target: Dictionary = {"pos": turn * paper_pose * Vector2(0, 40), "rotation": roll, "body_size": 12.0}
		assert(HitGeometry.contact(long_target, turn * paper_pose, paper.radii).hit, "paper reaches along its exposed length")
		assert(not HitGeometry.contact(long_target, turn * hand_pose, palm.radii).hit, "same long target is outside the palm clap")
		var side_target: Dictionary = {"pos": turn * Vector2(25, 0), "rotation": roll, "body_size": 12.0}
		assert(HitGeometry.contact(side_target, turn * hand_pose, palm.radii).hit, "round clap catches a nearby side target")
		assert(not HitGeometry.contact(side_target, turn * paper_pose, paper.radii).hit, "narrow paper cannot catch the same side target")
		var grip: Dictionary = {"pos": turn * paper_pose * Vector2(0, 80), "rotation": roll, "body_size": 42.0}
		assert(not HitGeometry.contact(grip, turn * paper_pose, paper.radii).hit, "newspaper gripping hand is excluded")
		var normal_long: Dictionary = {"pos": turn * paper_pose * Vector2(0, 45), "rotation": roll, "body_size": 42.0}
		assert(HitGeometry.contact(normal_long, turn * paper_pose, paper.radii).hit and not HitGeometry.contact(normal_long, turn * hand_pose, palm.radii).hit, "normal game-size bug is caught farther along the paper but missed by palms")
		var normal_side: Dictionary = {"pos": turn * Vector2(36, 0), "rotation": roll, "body_size": 42.0}
		assert(HitGeometry.contact(normal_side, turn * hand_pose, palm.radii).hit and not HitGeometry.contact(normal_side, turn * paper_pose, paper.radii).hit, "normal game-size bug at the side is caught by palms but missed by narrow paper")
	# Translating and rotating the whole encounter does not change its result.
	var common: Transform2D = Transform2D(0.73, Vector2(120, 80))
	var local_bug: Dictionary = {"pos": Vector2(34, 6), "rotation": 0.24, "body_size": 54.0}
	var local_pose: Transform2D = Transform2D(-0.15, Vector2.ZERO)
	var local_result: bool = HitGeometry.contact(local_bug, local_pose, Vector2(29, 36)).hit
	local_bug.pos = common * local_bug.pos
	local_bug.rotation += 0.73
	assert(HitGeometry.contact(local_bug, common * local_pose, Vector2(29, 36)).hit == local_result, "shared coordinate-space invariance")
	print("PASS: body/wing overlap; transparent corners/leg tips/handle/wrist rejection; size/rotation; partial edge contact; spark contact point; distinct palm/newspaper directional reach; gripping-hand rejection; matching rendered upgrade radius/pivot; coordinate-space invariance")
	quit()
