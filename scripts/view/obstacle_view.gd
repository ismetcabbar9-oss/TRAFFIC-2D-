class_name ObstacleView
extends Node3D
## Static prop (cone, box) that blocks one cell.

const MODELS := {
	"cone": {"path": "res://assets/models/props/cone.glb", "scale": 1.6, "footprint": 0.476},
	"box": {"path": "res://assets/models/props/box.glb", "scale": 1.1, "footprint": 0.715},
}

var cell := Vector2i.ZERO

var _half_size := 0.0
var _cell_size := 1.0
var _model: Node3D
var _tween: Tween


func setup(board: BoardView, type: String, p_cell: Vector2i) -> void:
	cell = p_cell
	name = "Obstacle_%s_%d_%d" % [type, cell.x, cell.y]
	_cell_size = board.theme.cell_size
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
