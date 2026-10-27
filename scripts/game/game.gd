extends Node3D
## Game scene root: loads a level, builds its visuals, turns taps into
## GameSession moves and plays the matching animations and HUD updates.

const MENU_SCENE := "res://scenes/menu.tscn"

@export var win_delay := 0.35 ## seconds after the last car has left the screen
@export var max_exit_wait := 3.0 ## never wait longer than this for cars to leave
@export var lose_delay := 0.6 ## seconds between the final crash and the lose panel
@export_range(0.0, 1.0) var horn_chance := 0.65 ## chance a bumped car honks back
## Hint: after this many idle seconds a car that can leave flashes its arrow.
@export var hint_delay := 7.0
@export var first_level_hint_delay := 2.5 ## quicker on the very first level
@export var hint_repeat := 4.0 ## flash again this often while still idle
@export var tutorial_levels := 1 ## the first N levels also show a text tip
@export var combo_window := 1.6 ## seconds between exits that keep a combo going

var session: GameSession
var world_index := 0
var level_index := 0
var vehicle_views := {} ## vehicle id -> VehicleView
var obstacle_views := {} ## cell -> ObstacleView
var _idle := 0.0
var _next_hint := 0.0
var _hinted_id := -1
var _sun_scale := 1.0
var _combo := 0
var _best_combo := 0
var _level_start := 0.0
var _clock := 0.0 ## game time in seconds (follows pauses and time scale)
var _last_exit_time := -100.0
var _tutorial_open := false
var _ambient_scale := 1.0

@onready var board: BoardView = $Board
@onready var pieces: Node3D = $Vehicles
@onready var effects: Node3D = $Effects
@onready var scenery: Scenery = $Scenery
@onready var camera: BoardCamera = $Camera
@onready var hud: Hud = $Hud


func _ready() -> void:
	Sfx.play_music("game")
	_adapt_lighting()
	hud.restart_requested.connect(func(): Transition.cover(load_level.bind(level_index)))
	hud.next_requested.connect(func(): Transition.cover(load_level.bind(level_index + 1)))
	hud.menu_requested.connect(_to_menu)
	hud.tutorial_closed.connect(func():
		_tutorial_open = false
		Progress.mark_tutorial_seen()
		_clear_hint())
	load_level(Progress.current_level)
	if world_index == 0 and level_index == 0 and not Progress.tutorial_seen:
		_tutorial_open = true
		hud.show_tutorial()


## Devices without Vulkan fall back to the Compatibility renderer, which lights
## in a different color space and looks washed out with the same values.
func _adapt_lighting() -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_sun_scale = 0.45
		_ambient_scale = 0.5


func load_level(index: int) -> void:
	world_index = Progress.current_world
	level_index = clampi(index, 0, LevelCatalog.level_count(world_index) - 1)
	Progress.current_level = level_index
	var path := LevelCatalog.path(world_index, level_index)
	var level := LevelData.load_file(path)
	var report := LevelSolver.solve(level)
	if not report.errors.is_empty():
		push_error("Level %s is invalid: %s" % [path, report.errors])
		return
	if not report.solvable:
		push_warning("Level %s cannot be cleared; stuck vehicles: %s" % [path, report.stuck])

	session = GameSession.new(level)
	_combo = 0
	_best_combo = 0
	_level_start = _clock
	session.vehicle_exited.connect(_on_vehicle_exited)
	session.vehicle_crashed.connect(_on_vehicle_crashed)
	session.vehicle_advanced.connect(_on_vehicle_advanced)
	session.vehicle_turned.connect(_on_vehicle_turned)
	session.vehicle_locked.connect(_on_vehicle_locked)
	session.mistakes_changed.connect(func(left: int): hud.set_mistakes(left, level.mistakes))
	session.won.connect(_on_won)
	session.lost.connect(_on_lost)

	for child in pieces.get_children() + effects.get_children():
		child.queue_free()
	vehicle_views.clear()
	obstacle_views.clear()

	board.build(level.cols, level.rows)
	scenery.build(board.view_half_extents(), board.theme.road_width * 0.5, level.cols * 31 + level.rows)
	for id in session.board.vehicles:
		var view := VehicleView.new()
		pieces.add_child(view)
		view.setup(board, session.board.vehicles[id], effects)
		vehicle_views[id] = view
	for e in level.obstacles:
		var obstacle := ObstacleView.new()
		pieces.add_child(obstacle)
		obstacle.setup(board, e.type, e.cell, e.get("group", -1))
		obstacle_views[e.cell] = obstacle
	# Each level is a little later in the day: morning light to sunset.
	var hour := TimeOfDay.hour_for_level(level_index, LevelCatalog.level_count(world_index))
	TimeOfDay.apply(hour, $Sun, ($WorldEnvironment as WorldEnvironment).environment, _sun_scale, _ambient_scale)
	# Keep the exit barrier in view below the board.
	camera.frame_board(board.view_half_extents(), board.exit_gate_z() + 1.0 - board.view_half_extents().y)
	camera.play_intro()
	# Cars pop in one after another, row by row.
	for id in vehicle_views:
		var v: VehicleView = vehicle_views[id]
		v.pop_in(0.25 + minf((v.cell.y * level.cols + v.cell.x) * 0.012, 0.55))

	hud.hide_result()
	_clear_hint()
	_show_mechanic_tip(level)
	hud.set_level_title(tr("LEVEL_N") % (level_index + 1))
	hud.set_time_of_day(TimeOfDay.label(hour))
	hud.set_mistakes(session.mistakes_left, level.mistakes)


## The first level with a new mechanic explains it once.
func _show_mechanic_tip(level: LevelData) -> void:
	var tip := ""
	for e in level.vehicles:
		if e.get("cargo", false):
			tip = "CARGO"
		elif e.get("turn", 0) != 0:
			tip = "TURN"
		elif e.get("lock", -1) >= 0:
			tip = "LOCK"
	for e in level.obstacles:
		if e.type == "gate":
			tip = "GATE"
	if tip == "" or tip in Progress.tips_seen:
		return
	Progress.mark_tip_seen(tip)
	_tutorial_open = true
	hud.show_tutorial("MECH_%s_TITLE" % tip, ["MECH_%s_1" % tip, "MECH_%s_2" % tip])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: # Android back button
		_to_menu()


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
	_clock += delta
	if session == null or session.state != GameSession.State.PLAYING or _tutorial_open:
		return
	_idle += delta
	if _idle < _next_hint:
		return
	_next_hint = _idle + hint_repeat
	# Keep pointing at the same car while it can still leave; otherwise ask
	# the solver for the next move of a winning line.
	var free := session.board.free_vehicles()
	if not _hinted_id in free:
		_hinted_id = free[0] if not free.is_empty() else LevelSolver.next_tap(session.board)
	if vehicle_views.has(_hinted_id):
		vehicle_views[_hinted_id].flash_hint()
		if world_index == 0 and level_index < tutorial_levels:
			hud.show_hint(tr("HINT_TAP_FREE"))


## Restarts the idle timer after the player acts (or a level starts).
func _clear_hint() -> void:
	_idle = 0.0
	_next_hint = first_level_hint_delay if world_index == 0 and level_index == 0 else hint_delay
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


func _on_vehicle_exited(id: int, result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	vehicle_views.erase(id)
	view.play_exit()
	_play_launch_sounds(view.type)
	Haptics.pulse(12, 0.4)
	_count_combo(view)
	if view.state.key >= 0:
		_open_group(view.state.key, result.opened)


## The key car of `group` has left: its locked cars and gates open.
func _open_group(group: int, gate_cells: Array[Vector2i]) -> void:
	var opened := false
	for other in vehicle_views.values():
		if (other as VehicleView).state.lock == group:
			other.unlock()
			opened = true
	for c in gate_cells:
		var gate: ObstacleView = obstacle_views.get(c)
		obstacle_views.erase(c)
		if gate:
			gate.open()
	if not gate_cells.is_empty():
		Sfx.play("gate_open", -4.0, 1.0, 0.05)
	if opened or not gate_cells.is_empty():
		get_tree().create_timer(0.1).timeout.connect(func(): Sfx.play("unlock", -2.0, 1.0, 0.05))


## Cargo pulled forward one cell.
func _on_vehicle_advanced(id: int, _result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	view.play_advance()
	Sfx.play(VehicleCatalog.engine_sound(view.type), -9.0, VehicleCatalog.pitch(view.type) * 0.9, 0.04)
	Haptics.pulse(10, 0.3)
	_check_deadlock()


func _on_vehicle_turned(id: int, _result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	view.play_turn()
	Sfx.play("tire_squeal", -9.0, 1.15, 0.05)
	Haptics.pulse(10, 0.3)
	_check_deadlock()


func _on_vehicle_locked(id: int) -> void:
	vehicle_views[id].play_locked()
	Sfx.play("lock_rattle", -3.0, 1.0, 0.05)
	Haptics.pulse(20, 0.5)


## A pull-forward or turn can box cars in for good; say so instead of letting
## the player tap around a board that can no longer be cleared.
func _check_deadlock() -> void:
	if session.is_deadlocked():
		hud.show_hint(tr("HINT_DEADLOCK"))
		hud.pulse_retry()


## Quick successive exits build a combo: a pop-up over the car and a chime
## that climbs a whole tone per step. A crash breaks the chain.
func _count_combo(view: VehicleView) -> void:
	_combo = _combo + 1 if _clock - _last_exit_time <= combo_window else 1
	_last_exit_time = _clock
	_best_combo = maxi(_best_combo, _combo)
	if _combo < 2:
		return
	var steps := mini(_combo - 2, 8)
	Sfx.play("combo", -5.0, pow(2.0, steps * 2.0 / 12.0), 0.0)
	hud.show_combo(_combo, camera.unproject_position(view.global_position + Vector3.UP * 1.5))


## Engine, exhaust and tyres; emergency vehicles add their siren. Tyres share
## one sample and only lean a little toward the vehicle's pitch so launches
## sound consistent while trucks stay a touch deeper than sports cars.
func _play_launch_sounds(type: String) -> void:
	var pitch := VehicleCatalog.pitch(type)
	Sfx.play("exhaust_pop", -3.0, pitch, 0.08)
	Sfx.play(VehicleCatalog.engine_sound(type), -5.0, pitch, 0.04)
	Sfx.play("tire_squeal", -10.0, lerpf(1.0, pitch, 0.35), 0.03)
	var siren := VehicleCatalog.siren_sound(type)
	if siren != "":
		get_tree().create_timer(0.08).timeout.connect(func(): Sfx.play(siren, -7.0, 1.0, 0.02))


func _on_vehicle_crashed(id: int, result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	var target: Node3D = obstacle_views.get(result.contact_cell) if result.blocker < 0 \
		else vehicle_views.get(result.blocker)
	if result.turning:
		view.play_turn_crash(_on_crash_impact.bind(view, target, result.blocker))
		return
	var cell_size := board.theme.cell_size
	# From the car's center to the blocker's edge, minus the car's own half length.
	var gap := view.length * cell_size * 0.5 + result.steps * cell_size - view.half_length
	if target != null:
		gap += target.inset_toward(view.dir)
	view.play_crash(maxf(gap - 0.02, 0.05), _on_crash_impact.bind(view, target, result.blocker))


func _on_crash_impact(view: VehicleView, target: Node3D, blocker: int) -> void:
	_combo = 0
	var push := view.forward()
	if is_instance_valid(target):
		target.nudge(push)
	Effects.impact(effects, view.front_point(), push)
	camera.shake(0.45)
	Haptics.pulse(45, 0.9)
	if blocker < 0: # cone, box or gate
		Sfx.play("crash", -5.0, 1.3)
		return
	Sfx.play("crash", 0.0, 1.0, 0.1)
	if target is VehicleView and randf() < horn_chance:
		# The bumped car answers with its own horn; emergency vehicles often
		# with their siren instead.
		var type := (target as VehicleView).type
		var sound := VehicleCatalog.horn_sound(type)
		if VehicleCatalog.siren_sound(type) != "" and randf() < 0.5:
			sound = VehicleCatalog.siren_sound(type)
		get_tree().create_timer(0.12).timeout.connect(func(): Sfx.play(sound, -6.0, 1.0, 0.03))


func _on_won() -> void:
	var played := session
	var mistakes_used := session.level.mistakes - session.mistakes_left
	var stars := Economy.stars_for(mistakes_used)
	var time := _clock - _level_start
	var record := Progress.record_win(world_index, level_index, stars, time, _best_combo, session.level.hard)
	var result := {
		"stars": stars, "time": time, "combo": _best_combo, "coins": record.coins,
		"best_time": record.best_time, "perfect": mistakes_used == 0,
		"last_level": not Progress.has_next_level(world_index, level_index),
	}
	var waited := 0.0
	while VehicleView.exiting_count() > 0 and waited < max_exit_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(win_delay).timeout
	if played == session:
		Sfx.duck_music(2.0)
		Sfx.play("win", -2.0, 1.0, 0.0)
		hud.show_win(result)


func _on_lost() -> void:
	var played := session
	await get_tree().create_timer(lose_delay).timeout
	if played == session and session.state == GameSession.State.LOST:
		Sfx.duck_music(2.0)
		Sfx.play("lose", -2.0, 1.0, 0.0)
		hud.show_lose()


func _to_menu() -> void:
	MainMenu.return_to_world = true
	Transition.change_scene(MENU_SCENE)
