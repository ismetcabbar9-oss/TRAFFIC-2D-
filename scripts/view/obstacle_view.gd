class_name ObstacleView
extends Node3D
## Static prop (cone, box) that blocks one cell.

const MODELS := {
	"cone": "res://assets/models/props/cone.glb",
	"box": "res://assets/models/props/box.glb",
}


func setup(board: BoardView, type: String, cell: Vector2i) -> void:
	name = "Obstacle_%s_%d_%d" % [type, cell.x, cell.y]
	var model: Node3D = (load(MODELS[type]) as PackedScene).instantiate()
	model.scale = Vector3.ONE * board.theme.cell_size * (1.6 if type == "cone" else 1.1)
	add_child(model)
	position = board.cell_to_world(Vector2(cell))
