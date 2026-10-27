extends Node3D
## Game scene root: loads a level, builds its board and vehicle visuals and
## forwards taps to the GameSession (wired up in stage 3).

@export_file("*.json") var level_path := "res://levels/demo.json"

var session: GameSession
var vehicle_views := {} ## vehicle id -> VehicleView

@onready var board: BoardView = $Board
@onready var vehicles: Node3D = $Vehicles
@onready var camera: BoardCamera = $Camera


func _ready() -> void:
	load_level(level_path)


func load_level(path: String) -> void:
	var level := LevelData.load_file(path)
	var report := LevelSolver.solve(level)
	if not report.errors.is_empty():
		push_error("Level %s is invalid: %s" % [path, report.errors])
		return
	if not report.solvable:
		push_warning("Level %s cannot be cleared; stuck vehicles: %s" % [path, report.stuck])

	session = GameSession.new(level)
	for child in vehicles.get_children():
		child.queue_free()
	vehicle_views.clear()

	board.build(level.cols, level.rows)
	for id in session.board.vehicles:
		var view := VehicleView.new()
		vehicles.add_child(view)
		view.setup(board, session.board.vehicles[id])
		vehicle_views[id] = view
	for e in level.obstacles:
		var obstacle := ObstacleView.new()
		vehicles.add_child(obstacle)
		obstacle.setup(board, e.type, e.cell)
	camera.frame_board(board.view_half_extents())
