class_name Scenery
extends Node3D
## Decorates the grass around the board: street lamps and street furniture
## along the pavement, a belt of trees and bushes, and shops and houses further
## out. Placement is seeded by the
## board size, so a level always looks the same. Nothing tall is put right in
## front of the camera (bottom side), where it would hide the exit traffic.
## All copies of a mesh are drawn with one MultiMesh to keep draw calls low.

const PROPS := "res://assets/models/hq/props/"
const TREE_DIR := "res://assets/models/hq/trees/"
const LAMP := PROPS + "street_light.glb"
const LAMP_SCALE := 0.65
## Leafy trees and round bushes picked from the C4 pack: [file, scale].
const TREES := [
	["tree_02", 1.7], ["tree_04", 1.6], ["tree_06", 1.8], ["tree_11", 1.8], ["tree_15", 1.7],
	["tree_16", 1.7], ["tree_17", 1.6], ["tree_21", 1.7], ["tree_23", 1.4], ["tree_26", 1.6], ["tree_28", 1.7],
]
const BUSHES := [
	["tree_38", 1.1], ["tree_39", 1.0], ["tree_43", 1.2], ["tree_44", 1.0], ["tree_45", 1.2], ["tree_50", 1.1],
]
## Street furniture placed now and then on the grass beside the pavement.
const FURNITURE := [["bench", 0.55], ["trash_can", 0.6], ["hydrant", 0.6], ["post_box", 0.6], ["bench_short", 0.55]]
## Buildings: low ones may stand on any side, tall ones never in front of the camera.
const LOW_BUILDINGS := ["bakery", "coffee_shop", "market", "pizzeria", "police_station", "blue_house"]
const TALL_BUILDINGS := ["hotel", "hospital", "cinema", "green_house", "fire_station", "yellow_house"]
const BUILDING_SCALE := 0.7

var _rng := RandomNumberGenerator.new()
var _taken: Array[Rect2] = [] ## footprints already used (XZ)
var _placements := {} ## model path -> Array[Transform3D]


## `inner_half`: half extents of the outer pavement edge; nothing goes inside.
## `exit_half_width`: half width of the exit road running down from the ring.
func build(inner_half: Vector2, exit_half_width: float, seed_value: int) -> void:
	for child in get_children():
		child.queue_free()
	_taken.clear()
	_placements.clear()
	_rng.seed = seed_value
	# Keep the exit road (and a margin) free.
	_taken.append(Rect2(-exit_half_width - 1.4, inner_half.y - 1.0, (exit_half_width + 1.4) * 2.0, 200.0))
	_add_lamps(inner_half, exit_half_width)
	_add_belt(inner_half)
	_add_houses(inner_half)
	_bake()


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
			_place(LAMP, at, LAMP_SCALE, atan2(inward.x, inward.y), false)
			# Now and then a bench, bin, hydrant or post box on the grass behind it.
			if _rng.randf() < 0.45 and side != 2:
				var item: Array = FURNITURE.pick_random()
				var spot := at - inward * 1.0 + Vector2(inward.y, inward.x) * 1.2
				_place(PROPS + item[0] + ".glb", spot, item[1], atan2(inward.x, inward.y), true, 0.6)


## Trees and bushes just outside the pavement; bottom side gets bushes only.
func _add_belt(inner_half: Vector2) -> void:
	var attempts := 140
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
		var pick: Array = BUSHES.pick_random() if near_camera or _rng.randf() < 0.3 else TREES.pick_random()
		_place(TREE_DIR + pick[0] + ".glb", at, pick[1] * _rng.randf_range(0.85, 1.15), _rng.randf() * TAU, true, 0.9)


## Shops and houses in a ring further out, facing the road.
func _add_houses(inner_half: Vector2) -> void:
	_place(PROPS + "bus_stop.glb", Vector2(inner_half.x * 0.45, -inner_half.y - 1.6), 0.5, 0.0, true, 1.6)
	for ring in 2:
		var gap := 6.2 + ring * 8.0
		var outer := inner_half + Vector2.ONE * gap
		for side in 4:
			var horizontal := side % 2 == 0
			var length := outer.x * 2.0 if horizontal else outer.y * 2.0
			var count := int(length / 8.0)
			for i in count:
				var t := -length * 0.5 + (i + 0.5) * length / count + _rng.randf_range(-0.8, 0.8)
				var at: Vector2 = [Vector2(t, -outer.y), Vector2(outer.x, t), Vector2(t, outer.y), Vector2(-outer.x, t)][side]
				var facing: float = [0.0, -PI * 0.5, PI, PI * 0.5][side]
				var pool: Array = LOW_BUILDINGS if side == 2 and ring == 0 else LOW_BUILDINGS + TALL_BUILDINGS
				var building: String = pool[_rng.randi() % pool.size()]
				_place(PROPS + building + ".glb", at, BUILDING_SCALE, facing, true, 3.6)
				# A tree or two in the yard.
				for k in _rng.randi_range(0, 2):
					var yard := at + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
					var tree: Array = TREES.pick_random()
					_place(TREE_DIR + tree[0] + ".glb", yard, tree[1] * _rng.randf_range(0.9, 1.2), _rng.randf() * TAU, true, 0.9)


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
