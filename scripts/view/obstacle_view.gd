class_name ObstacleView
extends Node3D
## Static prop on one cell: a cone, a box, a gate (barrier in its group
## color) that opens when the group's key car leaves, or a pit that swallows
## the first car driving over it and is then patched.

const MODELS := {
	"cone": {"path": "res://assets/models/props/cone.glb", "scale": 1.6, "footprint": 0.476},
	"box": {"path": "res://assets/models/props/box.glb", "scale": 1.1, "footprint": 0.715},
}

var cell := Vector2i.ZERO

var _half_size := 0.0
var _cell_size := 1.0
var _model: Node3D
var _tween: Tween


func setup(board: BoardView, type: String, p_cell: Vector2i, group := -1) -> void:
	cell = p_cell
	name = "Obstacle_%s_%d_%d" % [type, cell.x, cell.y]
	_cell_size = board.theme.cell_size
	position = board.cell_to_world(Vector2(cell))
	if type == "gate":
		_build_gate(MechanicStyle.group_color(group))
		return
	if type == "pit":
		_build_pit(board.theme.lot)
		return
	var info: Dictionary = MODELS[type]
	var s: float = _cell_size * info.scale
	_model = (load(info.path) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * s
	add_child(_model)
	_half_size = info.footprint * s * 0.5
	position = board.cell_to_world(Vector2(cell))


## Free space between the prop and the edge of its cell.
func inset_toward(_axis_dir: int) -> float:
	return _cell_size * 0.5 - _half_size


## Wobbles away from a hit.
func nudge(push: Vector3) -> void:
	if _tween:
		_tween.kill()
	var tilt := Vector3(push.z, 0, -push.x) * 0.35
	_tween = create_tween()
	_tween.tween_property(_model, "rotation", tilt, 0.07).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "rotation", Vector3.ZERO, 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


var _arm: Node3D


## Two posts and a striped arm across the cell, with a padlock on the ground.
func _build_gate(color: Color) -> void:
	_model = Node3D.new()
	add_child(_model)
	var span := _cell_size * 0.86
	_half_size = span * 0.5
	var post_mat := _material(Color("4a4f5c"))
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.8, 0.22)
		post.mesh = mesh
		post.material_override = post_mat
		post.position = Vector3(side * span * 0.5, 0.4, 0.0)
		_model.add_child(post)
	# The arm hinges on the left post.
	_arm = Node3D.new()
	_arm.position = Vector3(-span * 0.5, 0.66, 0.0)
	_model.add_child(_arm)
	const STRIPES := 5
	var stripe := span / STRIPES
	for i in STRIPES:
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(stripe, 0.22, 0.22)
		part.mesh = mesh
		part.material_override = _material(color if i % 2 == 0 else Color("f4f4f0"))
		part.position = Vector3(stripe * (i + 0.5), 0.0, 0.0)
		_arm.add_child(part)
	var lock := FlatIcon.create(FlatIcon.padlock_shapes(), color, 0.07, FlatIcon.padlock_details())
	lock.scale = Vector3.ONE * _cell_size * 0.4
	lock.position = Vector3(0.0, 0.02, _cell_size * 0.24)
	_model.add_child(lock)
	var frame := FlatIcon.create(FlatIcon.frame_shapes(Vector2.ONE * (_cell_size - 0.12), 0.08), Color(color, 0.85), 0.025)
	frame.position.y = 0.012
	_model.add_child(frame)
	var tint := FlatIcon.create([FlatIcon._rect(Vector2.ONE * -0.5, Vector2.ONE * 0.5)], Color(color, 0.22), 0.0)
	tint.scale = Vector3.ONE * (_cell_size - 0.12)
	tint.position.y = 0.006
	_model.add_child(tint)


## Lifts the arm, sinks the gate and frees it.
func open() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if _arm:
		_tween.tween_property(_arm, "rotation:z", deg_to_rad(80.0), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_model, "scale", Vector3(1.0, 0.01, 1.0), 0.25).set_ease(Tween.EASE_IN)
	_tween.tween_callback(queue_free)


# --- Pit -------------------------------------------------------------------------

var _hole: Node3D


## A collapsed patch of the lot: broken rim, cracks and a dark hole.
func _build_pit(lot: Color) -> void:
	_model = Node3D.new()
	add_child(_model)
	_model.rotation.y = randf() * TAU
	var r := _cell_size * 0.48
	_half_size = r
	_disc(_model, r, lot.lightened(0.18), 0.004, 9) # broken edge
	for i in 5: # cracks running out into the asphalt
		var crack := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.01, r * randf_range(0.45, 0.7))
		crack.mesh = mesh
		crack.material_override = _material(lot.darkened(0.5))
		var a := TAU * (i + randf_range(-0.2, 0.2)) / 5.0
		crack.position = Vector3(sin(a), 0.0, cos(a)) * (r + mesh.size.z * 0.4) + Vector3.UP * 0.006
		crack.rotation.y = a
		_model.add_child(crack)
	var rim := Node3D.new()
	_model.add_child(rim)
	for part in _model.get_children():
		if part != rim:
			part.reparent(rim, false)
	_hole = Node3D.new()
	_model.add_child(_hole)
	_disc(_hole, r * 0.86, Color("3a2d22"), 0.01, 10)
	_disc(_hole, r * 0.68, Color("17110d"), 0.014, 10)
	_disc(_hole, r * 0.42, Color("030202"), 0.018, 8)
	for i in 5: # chunks of asphalt on the rim
		var chunk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.1, 0.18), 0.06, randf_range(0.08, 0.14))
		chunk.mesh = mesh
		chunk.material_override = _material(lot.lightened(0.08))
		var a := TAU * (i + 0.5) / 5.0 + randf_range(-0.3, 0.3)
		chunk.position = Vector3(sin(a), 0.0, cos(a)) * r * 0.9 + Vector3.UP * 0.03
		chunk.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		rim.add_child(chunk)
	MeshMerge.merge(rim, false)
	MeshMerge.merge(_hole, false)


## Something fell in: rubble fills the hole and a patch of fresh asphalt
## closes it.
func fill() -> void:
	if _hole == null:
		return
	var patch := Node3D.new()
	_model.add_child(patch)
	_disc(patch, _half_size * 0.86, Color("3d424c"), 0.02, 10)
	patch.scale = Vector3.ONE * 0.01
	var t := create_tween()
	t.tween_property(_hole, "scale", Vector3(0.6, 1.0, 0.6), 0.25)
	t.tween_property(patch, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_hole.queue_free)
	_hole = null


static func _disc(parent: Node3D, radius: float, color: Color, y: float, sides: int) -> void:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.004
	mesh.radial_segments = sides
	mesh.rings = 1
	m.mesh = mesh
	m.material_override = _material(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = y
	parent.add_child(m)


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m
