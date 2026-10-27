extends Node3D
## Game scene root: loads a level, builds its visuals, turns taps into
## GameSession moves and plays the matching animations and HUD updates.

const MENU_SCENE := "res://scenes/menu.tscn"

@export var win_delay := 0.35 ## seconds after the last car has left the screen
@export var max_exit_wait := 3.0 ## never wait longer than this for cars to leave
@export var lose_delay := 0.6 ## seconds between the final crash and the lose panel
@export_range(0.0, 1.0) var horn_chance := 0.65 ## chance a bumped car honks back
@export var hint_levels := 1 ## the first N levels show a hint when the player waits
@export var hint_delay := 2.5 ## idle seconds before the hint appears

var session: GameSession
var level_index := 0
var vehicle_views := {} ## vehicle id -> VehicleView
var obstacle_views := {} ## cell -> ObstacleView
var _idle := 0.0
var _hinted_id := -1

@onready var board: BoardView = $Board
@onready var pieces: Node3D = $Vehicles
@onready var effects: Node3D = $Effects
@onready var camera: BoardCamera = $Camera
@onready var hud: Hud = $Hud


func _ready() -> void:
	_adapt_lighting()
	hud.restart_requested.connect(func(): load_level(level_index))
	hud.next_requested.connect(func(): load_level(level_index + 1))
	hud.menu_requested.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	load_level(Progress.current_level)


## Devices without Vulkan fall back to the Compatibility renderer, which lights
## in a different color space and looks washed out with the same values.
func _adapt_lighting() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	($Sun as DirectionalLight3D).light_energy *= 0.45
	($WorldEnvironment as WorldEnvironment).environment.ambient_light_energy *= 0.5


func load_level(index: int) -> void:
	level_index = clampi(index, 0, LevelCatalog.count() - 1)
	Progress.current_level = level_index
	var path := LevelCatalog.path(level_index)
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

	for child in pieces.get_children() + effects.get_children():
		child.queue_free()
	vehicle_views.clear()
	obstacle_views.clear()

	board.build(level.cols, level.rows)
	for id in session.board.vehicles:
		var view := VehicleView.new()
		pieces.add_child(view)
		view.setup(board, session.board.vehicles[id], effects)
		vehicle_views[id] = view
	for e in level.obstacles:
		var obstacle := ObstacleView.new()
		pieces.add_child(obstacle)
		obstacle.setup(board, e.type, e.cell)
		obstacle_views[e.cell] = obstacle
	camera.frame_board(board.view_half_extents())

	hud.hide_result()
	_clear_hint()
	hud.set_level_title(level.name)
	hud.set_mistakes(session.mistakes_left, level.mistakes)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: # Android back button
		get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse clicks arrive as touches too (pointing/emulate_touch_from_mouse).
	# Every finger counts, so two quick taps with two fingers both register.
	if event is InputEventScreenTouch and event.pressed:
		var id := _pick_vehicle(event.position)
		if id >= 0 and session != null:
			_clear_hint()
			session.tap(id)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if level_index >= hint_levels or session == null or session.state != GameSession.State.PLAYING:
		return
	_idle += delta
	if _idle >= hint_delay and _hinted_id < 0:
		var free := session.board.free_vehicles()
		if not free.is_empty() and vehicle_views.has(free[0]):
			_hinted_id = free[0]
			vehicle_views[_hinted_id].set_hint(true)
			hud.show_hint("Yolu açık bir arabaya dokun!")


func _clear_hint() -> void:
	_idle = 0.0
	if _hinted_id >= 0 and vehicle_views.has(_hinted_id):
		vehicle_views[_hinted_id].set_hint(false)
	_hinted_id = -1
	hud.hide_hint()


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
	var size_pitch := 0.85 if view.length >= 3 else 1.0
	Sfx.play("exhaust_pop", -3.0, size_pitch, 0.12)
	Sfx.play("car_go", -5.0, size_pitch)
	Haptics.pulse(12, 0.4)


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
	view.play_crash(maxf(gap - 0.02, 0.05), _on_crash_impact.bind(view, target, result.blocker))


func _on_crash_impact(view: VehicleView, target: Node3D, blocker: int) -> void:
	var push := view.forward()
	if is_instance_valid(target):
		target.nudge(push)
	Effects.impact(effects, view.front_point(), push)
	camera.shake(0.45)
	Haptics.pulse(45, 0.9)
	if blocker == BoardState.OBSTACLE:
		Sfx.play("crash", -5.0, 1.3)
		return
	Sfx.play("crash", 0.0, 1.0, 0.1)
	if target is VehicleView and randf() < horn_chance:
		var horn_pitch := 0.8 if (target as VehicleView).length >= 3 else 1.0
		get_tree().create_timer(0.12).timeout.connect(
			func(): Sfx.play("horn_double" if randf() < 0.4 else "horn", -6.0, horn_pitch))


func _on_won() -> void:
	var played := session
	Progress.complete(level_index)
	var waited := 0.0
	while VehicleView.exiting_count() > 0 and waited < max_exit_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(win_delay).timeout
	if played == session:
		Sfx.play("win", -2.0, 1.0, 0.0)
		hud.show_win(not Progress.has_next(level_index))


func _on_lost() -> void:
	var played := session
	await get_tree().create_timer(lose_delay).timeout
	if played == session and session.state == GameSession.State.LOST:
		Sfx.play("lose", -2.0, 1.0, 0.0)
		hud.show_lose()
