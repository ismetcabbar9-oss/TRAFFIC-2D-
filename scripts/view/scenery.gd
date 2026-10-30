class_name Scenery
extends Node3D
## Decorates the ground around the board in the world's theme (WorldTheme):
## street lamps and furniture along the pavement, a belt of trees and bushes,
## landmarks, ground patches (sea, apron) and buildings further out. Placement is seeded by the
## board size, so a level always looks the same. Nothing tall is put right in
## front of the camera (bottom side), where it would hide the exit traffic.
## All copies of a mesh are drawn with one MultiMesh to keep draw calls low.

const WATER_SHADER := preload("res://shaders/water.gdshader")
const GLOW_SHADER := preload("res://shaders/glow.gdshader")

var _rng := RandomNumberGenerator.new()
var _taken: Array[Rect2] = [] ## footprints already used (XZ)
var _placements := {} ## model path -> Array[Transform3D]
var _sparse := false
var _theme: WorldTheme
var _lamp_spots: Array[Vector3] = [] ## lamp heads, for the night glow


## `inner_half`: half extents of the outer pavement edge; nothing goes inside.
## `exit_half_width`: half width of the exit road running down from the ring.
## `sparse`: low graphics quality - fewer trees, one ring of houses, less snow.
func build(inner_half: Vector2, exit_half_width: float, seed_value: int, theme: WorldTheme, sparse := false) -> void:
	_sparse = sparse
	for child in get_children():
		child.queue_free()
	_taken.clear()
	_placements.clear()
	_lamp_spots.clear()
	_theme = theme
	_rng.seed = seed_value
	# Keep the exit road (and a margin) free.
	_taken.append(Rect2(-exit_half_width - 1.4, inner_half.y - 1.0, (exit_half_width + 1.4) * 2.0, 200.0))
	_add_lamps(inner_half, exit_half_width)
	_add_landmarks(inner_half)
	_add_patches(inner_half)
	_add_belt(inner_half)
	_add_houses(inner_half)
	_bake()
	if theme.night:
		_add_lamp_glow()
	if theme.snow:
		_add_snowfall(inner_half)


func _add_lamps(inner_half: Vector2, exit_half_width: float) -> void:
	var spacing := 5.0
	var inset := 0.35 # from the outer pavement edge toward the road
	for side in 4:
		var horizontal := side % 2 == 0
		var length := inner_half.x * 2.0 if horizontal else inner_half.y * 2.0
		var count := maxi(int(length / spacing), 1)
		for i in count:
			var t := -length * 0.5 + (i + 0.5) * length / count
			var at: Vector2 = [Vector2(t, -inner_half.y + inset), Vector2(inner_half.x - inset, t),
					Vector2(t, inner_half.y - inset), Vector2(-inner_half.x + inset, t)][side]
			if side == 2 and absf(t) < exit_half_width + 1.0:
				continue
			var inward: Vector2 = [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)][side]
			_place(_theme.lamp[0], at, _theme.lamp[1], atan2(inward.x, inward.y), false)
			# The lamp arm leans over the road; its light lands a little inward.
			_lamp_spots.append(Vector3(at.x + inward.x * 0.7, 0.0, at.y + inward.y * 0.7))
			# Now and then a bench, bin, hydrant or post box on the grass behind it
			# (not along the top, where it would peek out behind the top bar).
			if _rng.randf() < 0.45 and side % 2 == 1 and not _theme.furniture.is_empty():
				var item: Array = _theme.furniture.pick_random()
				var spot := at - inward * 1.0 + Vector2(inward.y, inward.x) * 1.2
				_place(item[0], spot, item[1], atan2(inward.x, inward.y), true, 0.6)


## Trees and bushes just outside the pavement; bottom side gets bushes only.
func _add_belt(inner_half: Vector2) -> void:
	var attempts := 60 if _sparse else 140
	for i in attempts:
		var side := _rng.randi_range(0, 3)
		var depth := _rng.randf_range(0.9, 4.5)
		var along := _rng.randf_range(-1.0, 1.0)
		var at: Vector2
		match side:
			0: at = Vector2(along * (inner_half.x + 4.5), -inner_half.y - depth)
			1: at = Vector2(inner_half.x + depth, along * (inner_half.y + 4.5))
			2: at = Vector2(along * (inner_half.x + 4.5), inner_half.y + depth)
			3: at = Vector2(-inner_half.x - depth, along * (inner_half.y + 4.5))
		var near_camera := side == 2 and depth < 3.0
		var bush := near_camera or _rng.randf() < 0.3 or _theme.trees.is_empty()
		var pool: Array = _theme.bushes if bush else _theme.trees
		if pool.is_empty():
			continue
		var pick: Array = pool.pick_random()
		_place(pick[0], at, pick[1] * _rng.randf_range(0.85, 1.15), _rng.randf() * TAU, true, 0.9)


## Shops and houses in a ring further out, facing the road.
func _add_houses(inner_half: Vector2) -> void:
	var radius := _theme.building_radius
	for ring in (1 if _sparse else 2):
		var gap := 6.2 + ring * 8.0 + (radius - 3.6)
		var outer := inner_half + Vector2.ONE * gap
		for side in 4:
			var horizontal := side % 2 == 0
			var length := outer.x * 2.0 if horizontal else outer.y * 2.0
			var count := int(length / (radius * 2.2))
			for i in count:
				var t := -length * 0.5 + (i + 0.5) * length / count + _rng.randf_range(-0.8, 0.8)
				var at: Vector2 = [Vector2(t, -outer.y), Vector2(outer.x, t), Vector2(t, outer.y), Vector2(-outer.x, t)][side]
				var facing: float = [0.0, -PI * 0.5, PI, PI * 0.5][side]
				var pool: Array = _theme.low_buildings if side == 2 and ring == 0 \
						else _theme.low_buildings + _theme.tall_buildings
				if pool.is_empty():
					continue
				var building: String = pool[_rng.randi() % pool.size()]
				_place(building, at, _theme.building_scale, facing, true, radius)
				# A tree or two in the yard.
				if _theme.trees.is_empty():
					continue
				for k in _rng.randi_range(0, 2):
					var yard := at + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
					var tree: Array = _theme.trees.pick_random()
					_place(tree[0], yard, tree[1] * _rng.randf_range(0.9, 1.2), _rng.randf() * TAU, true, 0.9)


## Big themed models (bus stop, lifeguard chairs, control tower, planes):
## placed before trees so they get their spot.
func _add_landmarks(inner_half: Vector2) -> void:
	for entry in _theme.landmarks:
		var placed := 0
		for attempt in 40:
			if placed >= entry[3]:
				break
			var at: Vector2
			if entry[4] == "back":
				# Toward the corners: the middle of the top edge is behind the
				# level title and the moves counter.
				var side := -1.0 if _rng.randf() < 0.5 else 1.0
				at = Vector2(side * _rng.randf_range(inner_half.x * 0.5, inner_half.x),
						-inner_half.y - entry[2] - _rng.randf_range(0.5, 4.0))
			elif entry[4] == "front":
				var side := -1.0 if placed % 2 == 0 else 1.0
				at = Vector2(side * (entry[2] + _rng.randf_range(4.0, 5.5)), inner_half.y + entry[2] + _rng.randf_range(1.5, 3.0))
			else:
				var side := -1.0 if _rng.randf() < 0.5 else 1.0
				at = Vector2(side * (inner_half.x + entry[2] + _rng.randf_range(1.5, 5.0)),
						_rng.randf_range(-inner_half.y, inner_half.y * 0.6))
			var before := _taken.size()
			var facing: float = {"back": PI, "front": 0.0}.get(entry[4], PI * 0.5)
			_place(entry[0], at, entry[1], _rng.randf_range(-0.6, 0.6) + facing, true, entry[2])
			if _taken.size() > before:
				placed += 1


## Flat areas beyond the pavement: a beach and the sea, or an apron.
func _add_patches(inner_half: Vector2) -> void:
	for patch in _theme.patches:
		var start: float = inner_half.y + patch[1]
		var depth: float = patch[2]
		var width := inner_half.x * 2.0 + 300.0
		var quad := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(width, depth)
		quad.mesh = mesh
		quad.position = Vector3(0.0, 0.02, -start - depth * 0.5)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if patch[4] == "water":
			var m := ShaderMaterial.new()
			m.shader = WATER_SHADER
			m.set_shader_parameter("base_color", patch[3])
			quad.material_override = m
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = patch[3]
			m.roughness = 0.95
			quad.material_override = m
		add_child(quad)
		# Nothing is planted on the sea; land patches stay free of trees too.
		_taken.append(Rect2(-width * 0.5, -start - depth, width, depth))


## Night: a warm pool of light under every lamp and a glowing bulb.
func _add_lamp_glow() -> void:
	var pool := QuadMesh.new()
	pool.size = Vector2(4.2, 4.2)
	pool.orientation = PlaneMesh.FACE_Y
	var pool_mat := ShaderMaterial.new()
	pool_mat.shader = GLOW_SHADER
	pool_mat.set_shader_parameter("glow_color", Color(1.0, 0.82, 0.5))
	pool_mat.set_shader_parameter("strength", 0.55)
	pool.material = pool_mat
	var bulb := QuadMesh.new()
	bulb.size = Vector2(1.1, 1.1)
	bulb.orientation = PlaneMesh.FACE_Y
	var bulb_mat := ShaderMaterial.new()
	bulb_mat.shader = GLOW_SHADER
	bulb_mat.set_shader_parameter("glow_color", Color(1.0, 0.93, 0.75))
	bulb_mat.set_shader_parameter("strength", 1.4)
	bulb.material = bulb_mat
	for mesh_and_y in [[pool, 0.07], [bulb, 2.9]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_and_y[0]
		mm.instance_count = _lamp_spots.size()
		for i in _lamp_spots.size():
			mm.set_instance_transform(i, Transform3D(Basis(), _lamp_spots[i] + Vector3.UP * mesh_and_y[1]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


## Light snowfall over the board (soft white flakes drifting down).
func _add_snowfall(inner_half: Vector2) -> void:
	var flakes := CPUParticles3D.new()
	flakes.amount = 110 if _sparse else 260
	flakes.lifetime = 7.0
	flakes.preprocess = 7.0
	flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flakes.emission_box_extents = Vector3(inner_half.x + 6.0, 0.5, inner_half.y + 6.0)
	flakes.position = Vector3(0.0, 12.0, 0.0)
	flakes.direction = Vector3(0.15, -1.0, 0.05)
	flakes.spread = 12.0
	flakes.gravity = Vector3.ZERO
	flakes.initial_velocity_min = 1.4
	flakes.initial_velocity_max = 2.2
	flakes.scale_amount_min = 0.6
	flakes.scale_amount_max = 1.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = m
	flakes.mesh = quad
	flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flakes)


## Places a model unless its footprint (radius) overlaps something already placed.
func _place(path: String, at: Vector2, scale_factor: float, yaw: float, check_overlap: bool, radius := 0.5) -> void:
	var rect := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if check_overlap:
		for other in _taken:
			if other.intersects(rect):
				return
	_taken.append(rect)
	if not _placements.has(path):
		_placements[path] = []
	_placements[path].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor), Vector3(at.x, 0.0, at.y)))


## Turns every placement into MultiMesh instances, one per distinct mesh.
func _bake() -> void:
	var batches := {} ## Mesh -> Array[Transform3D]
	for path in _placements:
		var template: Node = (load(path) as PackedScene).instantiate()
		var parts: Array = []
		_collect_meshes(template, Transform3D(), parts)
		template.free()
		for placement: Transform3D in _placements[path]:
			for part in parts:
				if not batches.has(part[0]):
					batches[part[0]] = []
				batches[part[0]].append(placement * part[1])
	for mesh: Mesh in batches:
		var transforms: Array = batches[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


static func _collect_meshes(node: Node, xf: Transform3D, out: Array) -> void:
	var t: Transform3D = xf * ((node as Node3D).transform if node is Node3D else Transform3D())
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append([(node as MeshInstance3D).mesh, t])
	for child in node.get_children():
		_collect_meshes(child, t, out)
