extends Node3D
## Game scene root: loads a level, builds its visuals, turns taps into
## GameSession moves and plays the matching animations and HUD updates.

@export_file("*.json") var level_path := "res://levels/demo.json"
@export var win_delay := 0.35 ## seconds after the last car has left the screen
@export var max_exit_wait := 3.0 ## never wait longer than this for cars to leave
@export var lose_delay := 0.6 ## seconds between the final crash and the lose panel

var session: GameSession
var vehicle_views := {} ## vehicle id -> VehicleView
var obstacle_views := {} ## cell -> ObstacleView

@onready var board: BoardView = $Board
@onready var pieces: Node3D = $Vehicles
@onready var camera: BoardCamera = $Camera
@onready var hud: Hud = $Hud


func _ready() -> void:
	hud.restart_requested.connect(func(): load_level(level_path))
	hud.next_requested.connect(func(): load_level(level_path))
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
	session.vehicle_exited.connect(_on_vehicle_exited)
	session.vehicle_crashed.connect(_on_vehicle_crashed)
	session.mistakes_changed.connect(func(left: int): hud.set_mistakes(left, level.mistakes))
	session.won.connect(_on_won)
	session.lost.connect(_on_lost)

	for child in pieces.get_children():
		child.queue_free()
	vehicle_views.clear()
	obstacle_views.clear()

	board.build(level.cols, level.rows)
	for id in session.board.vehicles:
		var view := VehicleView.new()
		pieces.add_child(view)
		view.setup(board, session.board.vehicles[id])
		vehicle_views[id] = view
	for e in level.obstacles:
		var obstacle := ObstacleView.new()
		pieces.add_child(obstacle)
		obstacle.setup(board, e.type, e.cell)
		obstacle_views[e.cell] = obstacle
	camera.frame_board(board.view_half_extents())

	hud.hide_result()
	hud.set_level_title(level.name)
	hud.set_mistakes(session.mistakes_left, level.mistakes)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse clicks arrive as touches too (pointing/emulate_touch_from_mouse).
	if event is InputEventScreenTouch and event.pressed and event.index == 0:
		var id := _pick_vehicle(event.position)
		if id >= 0 and session != null:
			session.tap(id)
			get_viewport().set_input_as_handled()


## Vehicle under a screen position, or -1.
func _pick_vehicle(screen_pos: Vector2) -> int:
	var from := camera.project_ray_origin(screen_pos)
	var normal := camera.project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + normal * 500.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("vehicle_id"):
		return hit.collider.get_meta("vehicle_id")
	# Between cars: fall back to the cell under the finger.
	var ground: Variant = Plane(Vector3.UP, board.surface_height()).intersects_ray(from, normal)
	if ground == null:
		return -1
	var occupant := session.board.at(board.world_to_cell(ground))
	return occupant if occupant >= 0 else -1


func _on_vehicle_exited(id: int, _result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	vehicle_views.erase(id)
	view.play_exit()


func _on_vehicle_crashed(id: int, result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	var target: Node3D = obstacle_views.get(result.contact_cell) if result.blocker == BoardState.OBSTACLE \
		else vehicle_views.get(result.blocker)
	var cell_size := board.theme.cell_size
	# From the car's center to the blocker's edge, minus the car's own half length.
	var gap := view.length * cell_size * 0.5 + result.steps * cell_size - view.half_length
	if target != null:
		gap += target.inset_toward(view.dir)
	var push := view.forward()
	view.play_crash(maxf(gap - 0.02, 0.05), func(): if is_instance_valid(target): target.nudge(push))


func _on_won() -> void:
	var played := session
	var waited := 0.0
	while VehicleView.exiting_count() > 0 and waited < max_exit_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(win_delay).timeout
	if played == session:
		hud.show_win()


func _on_lost() -> void:
	var played := session
	await get_tree().create_timer(lose_delay).timeout
	if played == session and session.state == GameSession.State.LOST:
		hud.show_lose()
