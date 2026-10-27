class_name ObstacleView
extends Node3D
## Static prop that blocks one cell: a cone, a box, or a gate (barrier in its
## group color) that opens when the group's key car leaves.

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


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m
