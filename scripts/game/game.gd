extends Node3D
## Game scene root: loads a level, builds its visuals, turns taps into
## GameSession moves and plays the matching animations and HUD updates.

const MENU_SCENE := "res://scenes/menu.tscn"

@export var lose_delay := 0.6 ## seconds between the final crash and the lose panel
@export_range(0.0, 1.0) var horn_chance := 0.65 ## chance a bumped car honks back
## Hint: after this many idle seconds a car that can leave flashes its arrow.
@export var hint_delay := 15.0
@export var idle_hint_levels := 30 ## no idle hint from this level on (Daily included)
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
var _crane_mode := false ## next tapped car is lifted out
var _held_hint := -1 ## car glowing from a paid hint
var _earned := 0 ## coins from the last win (for "double coins")
var _done_at_start: Array = [] ## achievements already reached when the level began
var _gestures := TouchGestures.new()
var _headlights: HeadlightPool ## night worlds: all headlight pools in one draw
var _rescued := false ## a rescue was used in this attempt (no third star)
var _paused := false ## the pause panel is open (the level clock stops)
var _onboarding := false ## first session: levels 1-3 guided by a pointing hand
var _guide_id := -1 ## car the hand points at
var _guide_delay := 0.0 ## seconds until the hand shows
var _last_empty_tap := {"time": -10.0, "pos": Vector2.ZERO} ## for double tap to zoom

# Endless "rush hour" mode (see Rush).
var _rush_rng := RandomNumberGenerator.new()
var _rush_score := 0
var _rush_arrived := 0 ## cars dropped in so far
var _rush_timer := 0.0 ## seconds until the next car drops
var _rush_next := {} ## the car about to drop (its spot is marked)
var _rush_marker: Node3D
var _rush_landed := {} ## vehicle id -> clock time it landed (quick bonus)
var _rush_best_before := 0 ## best score when this run began
var _rush_paid := 0 ## points already paid out in coins (a continued run pays the rest)
var _rush_continued := false ## the one continue of a run is used

# Rescues offered on the lose panel and next to bombs.
var _continue_kind := "" ## what the lose panel's rescue buttons do right now
var _rewound := false ## the rewind rescue is used on this level
var _bomb_boosted := {} ## bomb vehicle id -> true once given more time

# Cut scenes: the level-end finale and the explosion close-up.
var _cinematic := false ## a cut scene is running (a tap skips it)
var _skip := false
var _follow: VehicleView ## car the camera follows during the finale
var _last_out: VehicleView ## the car that most recently left the lot

@onready var board: BoardView = $Board
@onready var pieces: Node3D = $Vehicles
@onready var effects: Node3D = $Effects
@onready var scenery: Scenery = $Scenery
@onready var camera: BoardCamera = $Camera
@onready var hud: Hud = $Hud


func _ready() -> void:
	_adapt_lighting()
	hud.restart_requested.connect(func(): Transition.cover(load_level.bind(level_index)))
	hud.next_requested.connect(func(): Transition.cover(load_level.bind(level_index + 1)))
	hud.menu_requested.connect(_to_menu)
	hud.rescue_pressed.connect(_on_rescue)
	_gestures.tapped.connect(_on_tap)
	_gestures.panned.connect(func(delta: Vector2): camera.pan_by(delta))
	_gestures.pinched.connect(func(factor: float, center: Vector2): camera.zoom_at(factor, center))
	hud.dev_requested.connect(_show_dev_panel)
	hud.bomb_time_requested.connect(func(): _offer("bomb_time"))
	hud.paused_changed.connect(func(on: bool): _paused = on)
	hud.offer_accepted.connect(_on_offer_accepted)
	hud.continue_requested.connect(_on_continue)
	hud.double_coins_requested.connect(func():
		AdManager.show_rewarded("double_coins", func():
			Progress.add_coins(_earned, "ad:double_coins")
			hud.coins_doubled()))
	Progress.coins_changed.connect(func(total: int):
		hud.set_coins(total)
		_refresh_rescues())
	hud.tutorial_closed.connect(func():
		_tutorial_open = false
		_clear_hint())
	load_level(Progress.current_level)


## Devices without Vulkan fall back to the Compatibility renderer, which lights
## in a different color space and looks washed out with the same values.
func _adapt_lighting() -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_sun_scale = 0.45
		_ambient_scale = 0.5


func load_level(index: int) -> void:
	Engine.time_scale = 1.0
	_cinematic = false
	_follow = null
	hud.hide_banner()
	var level: LevelData
	var path := "daily"
	if Rush.playing:
		world_index = Rush.world_index
		level_index = 0
		path = "rush"
		_rush_rng.randomize()
		level = Rush.start_level(_rush_rng)
	elif Daily.playing:
		# The daily puzzle borrows the look of the world its mechanic comes from.
		world_index = Daily.world_index
		level_index = 0
		level = LevelData.from_dict(Daily.level_data)
	else:
		world_index = Progress.current_world
		level_index = clampi(index, 0, LevelCatalog.level_count(world_index) - 1)
		Progress.current_level = level_index
		path = LevelCatalog.path(world_index, level_index)
		level = LevelData.load_file(path)
	_done_at_start = Achievements.done_ids(Progress)
	var report := LevelSolver.solve(level)
	if not report.errors.is_empty():
		push_error("Level %s is invalid: %s" % [path, report.errors])
		return
	if not report.solvable:
		push_warning("Level %s cannot be cleared; stuck vehicles: %s" % [path, report.stuck])

	# Each pit costs a move when something falls in: it comes with one extra.
	if not Rush.playing:
		level.mistakes = Economy.mistakes_for(world_index, level_index, level.hard, Daily.playing) \
				+ level.obstacles.filter(func(o): return o.type == "pit").size()
	session = GameSession.new(level)
	session.endless = Rush.playing
	session.vehicle_added.connect(_on_vehicle_added)
	session.rewound.connect(_on_rewound)
	_rewound = false
	_bomb_boosted = {}
	_rush_best_before = int(Progress.stats.get("rush_best", 0))
	_rush_paid = 0
	_rush_continued = false
	hud.set_bomb_offer(false)
	_rush_score = 0
	_rush_arrived = 0
	_rush_timer = Rush.interval(0) + 1.0 # a moment to look before the first drop
	_rush_next = {}
	_rush_landed = {}
	_rush_marker = null
	_combo = 0
	_best_combo = 0
	_level_start = _clock
	session.vehicle_exited.connect(_on_vehicle_exited)
	session.vehicle_crashed.connect(_on_vehicle_crashed)
	session.vehicle_advanced.connect(_on_vehicle_advanced)
	session.vehicle_turned.connect(_on_vehicle_turned)
	session.vehicle_locked.connect(_on_vehicle_locked)
	session.vehicle_lifted.connect(_on_vehicle_lifted)
	session.vehicle_restored.connect(_on_vehicle_restored)
	session.vehicle_fell.connect(_on_vehicle_fell)
	session.exploded.connect(_on_exploded)
	session.bombs_ticked.connect(_on_bombs_ticked)
	session.mistakes_changed.connect(func(_left: int): _refresh_rescues())
	session.mistakes_changed.connect(func(left: int): hud.set_mistakes(left, level.mistakes))
	session.won.connect(_on_won)
	session.lost.connect(_on_lost)

	for child in pieces.get_children() + effects.get_children():
		child.queue_free()
	vehicle_views.clear()
	obstacle_views.clear()

	var world_theme := WorldTheme.for_world(world_index)
	Sfx.play_music(world_theme.music)
	VehicleView.headlights = world_theme.night
	if world_theme.night and _headlights == null:
		_headlights = HeadlightPool.new()
		add_child(_headlights)
	board.theme = world_theme.board
	board.build(level.cols, level.rows)
	scenery.build(board.view_half_extents(), board.theme.road_width * 0.5, level.cols * 31 + level.rows, world_theme)
	_build_pieces()
	# Each level is a little later in the day: morning light to sunset.
	var hour := TimeOfDay.hour_for_level(level_index, LevelCatalog.level_count(world_index))
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.background_color = world_theme.sky
	if world_theme.night:
		hour = TimeOfDay.NIGHT_HOUR
		TimeOfDay.apply_night($Sun, env, _sun_scale, _ambient_scale)
	else:
		TimeOfDay.apply(hour, $Sun, env, _sun_scale, _ambient_scale)
	# Keep the exit barrier in view below the board.
	camera.frame_board(board.view_half_extents(), board.exit_gate_z() + 1.0 - board.view_half_extents().y)
	camera.reset_view()
	camera.play_intro()
	# Cars pop in one after another, row by row.
	for id in vehicle_views:
		var v: VehicleView = vehicle_views[id]
		v.pop_in(0.25 + minf((v.cell.y * level.cols + v.cell.x) * 0.012, 0.55))

	hud.hide_result()
	_onboarding = Progress.in_onboarding() and world_index == 0 and level_index < 3 and not Daily.playing \
			and not Rush.playing
	_rescued = false
	if Rush.playing:
		Analytics.design("rush:start")
	else:
		Analytics.level("Start", world_index, level_index, Daily.playing)
	hud.set_onboarding(_onboarding)
	_reset_guide()
	_clear_hint()
	_set_crane_mode(false)
	_held_hint = -1
	hud.set_coins(Progress.coins)
	_refresh_rescues()
	_show_mechanic_tip(level)
	if not Rush.playing:
		_maybe_gift_crane()
	# The first big board tells how to zoom (once).
	if level.cols * level.rows >= 49 and not Progress.flag("zoom_tip") and not _tutorial_open:
		Progress.set_flag("zoom_tip")
		hud.show_hint(tr("HINT_ZOOM"))
	var title := tr("LEVEL_N") % (level_index + 1)
	if Daily.playing:
		title = tr("DAILY_TITLE")
	elif level.hard:
		title += "  ·  " + tr("LEVEL_ONE_CHANCE" if level.mistakes == 1 else "LEVEL_HARD")
	hud.set_level_title(title, level.hard)
	hud.set_time_of_day(TimeOfDay.label(hour))
	hud.set_rush(Rush.playing)
	if Rush.playing:
		_show_rush_score()
	hud.set_mistakes(session.mistakes_left, level.mistakes)


## The first level with a new mechanic explains it once.
func _show_mechanic_tip(level: LevelData) -> void:
	var tip := ""
	if Rush.playing:
		if not "RUSH" in Progress.tips_seen:
			Progress.mark_tip_seen("RUSH")
			_tutorial_open = true
			hud.show_tutorial("RUSH_TITLE", ["RUSH_TIP_1", "RUSH_TIP_2", "RUSH_TIP_3"])
		return
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
	# Hazards win over mechanics: they are the new thing to learn here.
	for e in level.vehicles:
		if e.get("bomb", 0) > 0 and not "BOMB" in Progress.tips_seen:
			tip = "BOMB"
		elif e.type == "tanker" and not "TANKER" in Progress.tips_seen:
			tip = "TANKER"
	for e in level.obstacles:
		if e.type == "pit" and not "PIT" in Progress.tips_seen:
			tip = "PIT"
	if tip == "" or tip in Progress.tips_seen:
		return
	Progress.mark_tip_seen(tip)
	_tutorial_open = true
	hud.show_tutorial("MECH_%s_TITLE" % tip, ["MECH_%s_1" % tip, "MECH_%s_2" % tip])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: # Android back button: pause
		if not _onboarding and not _paused and session != null and session.state == GameSession.State.PLAYING:
			hud.show_pause()


func _unhandled_input(event: InputEvent) -> void:
	# Mouse clicks arrive as touches too (pointing/emulate_touch_from_mouse).
	if _gestures.handle(event, get_viewport().get_visible_rect().size.y):
		get_viewport().set_input_as_handled()
		return
	# Desktop: mouse wheel and trackpad pinch zoom as well.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom_at(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom_at(1.0 / 1.12, event.position)
	elif event is InputEventMagnifyGesture:
		camera.zoom_at(event.factor, event.position)


## A finger lifted without dragging: tap the car under it. Two quick taps on
## empty ground zoom in there (or back out).
func _on_tap(screen_pos: Vector2) -> void:
	if _cinematic:
		_skip = true
		return
	if session == null:
		return
	var id := _pick_vehicle(screen_pos)
	if id < 0:
		var now := _clock
		if now - _last_empty_tap.time < 0.35 and screen_pos.distance_to(_last_empty_tap.pos) < 80.0:
			var ground: Variant = camera.ground_point(screen_pos)
			if ground != null:
				camera.toggle_zoom(ground)
			_last_empty_tap.time = -10.0
		else:
			_last_empty_tap = {"time": now, "pos": screen_pos}
		return
	_clear_hint()
	_release_held_hint()
	if _onboarding and level_index == 0:
		_reset_guide()
		_guide_delay = 0.9
	if _crane_mode:
		_set_crane_mode(false)
		if session.state == GameSession.State.PLAYING and Progress.use_item("crane"):
			Analytics.design("rescue:crane:owned")
			_rescued = true
			session.lift(id)
	else:
		session.tap(id)
	_refresh_rescues()


func _process(delta: float) -> void:
	if _paused:
		return
	_clock += delta
	if session != null:
		_refresh_bomb_offer()
	if is_instance_valid(_follow):
		camera.cinematic_follow(_follow.global_position, delta / maxf(Engine.time_scale, 0.01))
	if session == null or session.state != GameSession.State.PLAYING or _tutorial_open:
		hud.hide_hand()
		return
	if _onboarding and level_index == 0:
		_update_guide(delta)
		return
	if Rush.playing:
		_rush_tick(delta)
		return
	if level_index >= idle_hint_levels and not Daily.playing:
		return
	_idle += delta
	if _idle < _next_hint:
		return
	_next_hint = _idle + hint_repeat
	# Keep pointing at the same car while it can still leave; otherwise ask
	# the solver for the next move of a winning line.
	var free := session.board.free_vehicles()
	if not _hinted_id in free:
		var risky := session.board.has_bombs() or not session.board.pits.is_empty()
		_hinted_id = free[0] if not free.is_empty() and not risky else LevelSolver.next_tap(session.board, session.fall_budget())
	if vehicle_views.has(_hinted_id):
		vehicle_views[_hinted_id].flash_hint()
		if world_index == 0 and level_index < tutorial_levels:
			hud.show_hint(tr("HINT_TAP_FREE"))


## First level: a hand taps the next car of a winning line, right after
## every move.
func _update_guide(delta: float) -> void:
	_guide_delay -= delta
	if _guide_delay > 0.0:
		return
	if not vehicle_views.has(_guide_id) or not _guide_id in session.board.vehicles:
		_guide_id = LevelSolver.next_tap(session.board, session.fall_budget())
	if not vehicle_views.has(_guide_id):
		hud.hide_hand()
		return
	var view: VehicleView = vehicle_views[_guide_id]
	hud.show_hand(camera.unproject_position(view.global_position + Vector3.UP * 0.8))
	if level_index == 0 and session.taps == 0:
		hud.show_hint(tr("HINT_TAP_FREE"))


func _reset_guide() -> void:
	_guide_id = -1
	_guide_delay = 1.2
	hud.hide_hand()


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
	if occupant >= 0:
		return occupant
	return _nearest_vehicle(ground)


## Forgiving touch for small screens: the car whose footprint is closest to
## the finger, if within about half a cell.
func _nearest_vehicle(ground: Vector3) -> int:
	var cell_size := board.theme.cell_size
	var p := (Vector2(ground.x, ground.z) + board.lot_size() * 0.5) / cell_size
	var best := -1
	var best_distance := 0.45
	for id in session.board.vehicles:
		var v: VehicleState = session.board.vehicles[id]
		var span := Vector2(v.length, 1) if GridDir.is_horizontal(v.dir) else Vector2(1, v.length)
		var rect := Rect2(Vector2(v.cell), span)
		var closest := p.clamp(rect.position, rect.end)
		var distance := p.distance_to(closest)
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


func _on_vehicle_exited(id: int, result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	vehicle_views.erase(id)
	_last_out = view
	view.play_exit()
	Progress.add_stat("cars")
	Quests.report(Progress, "cars")
	_play_launch_sounds(view.type)
	Haptics.pulse(12, 0.4)
	_count_combo(view)
	if view.state.key >= 0:
		_open_group(view.state.key, result.opened)
	if Rush.playing:
		var quick := _clock - float(_rush_landed.get(id, _level_start)) <= Rush.FAST_TIME
		var points := Rush.points(_combo, quick)
		_rush_score += points
		_show_rush_score()
		hud.show_points(points, camera.unproject_position(view.global_position + Vector3.UP * 0.8))


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
	if _combo >= 2:
		Quests.report(Progress, "combo", _combo)
	Progress.max_stat("best_combo", _combo)
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
	var impact := _on_crash_impact.bind(view, target, result.blocker)
	if result.explodes:
		var crashed: Array = [view]
		if target is VehicleView:
			crashed.append(target)
		impact = func():
			_on_crash_impact(view, target, result.blocker)
			_explode(view.front_point(), crashed)
	if result.turning:
		view.play_turn_crash(impact)
		return
	var cell_size := board.theme.cell_size
	# From the car's center to the blocker's edge, minus the car's own half length.
	var gap := view.length * cell_size * 0.5 + result.steps * cell_size - view.half_length
	if target != null:
		gap += target.inset_toward(view.dir)
	view.play_crash(maxf(gap - 0.02, 0.05), impact)


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
	Sfx.play("glass_break", -9.0, 1.0, 0.1)
	Effects.shards(effects, view.front_point(), push)
	view.jolt(randf_range(0.12, 0.2) * (1.0 if randf() < 0.5 else -1.0))
	if target is VehicleView:
		(target as VehicleView).jolt(randf_range(-0.15, 0.15))
	if target is VehicleView and randf() < horn_chance:
		# The bumped car answers with its own horn; emergency vehicles often
		# with their siren instead.
		var type := (target as VehicleView).type
		var sound := VehicleCatalog.horn_sound(type)
		if VehicleCatalog.siren_sound(type) != "" and randf() < 0.5:
			sound = VehicleCatalog.siren_sound(type)
		get_tree().create_timer(0.12).timeout.connect(func(): Sfx.play(sound, -6.0, 1.0, 0.03))


# --- Hazards -----------------------------------------------------------------------

## A car drove into a pit: it tips in, dust flies and the pit is patched.
func _on_vehicle_fell(id: int, result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	vehicle_views.erase(id)
	_combo = 0
	var pit_view: ObstacleView = obstacle_views.get(result.contact_cell)
	obstacle_views.erase(result.contact_cell)
	var pit := board.cell_to_world(Vector2(result.contact_cell))
	Sfx.play("tire_squeal", -6.0, 0.9, 0.05)
	view.play_fall(pit, func():
		if result.explodes:
			_explode(pit, [])
			return
		Sfx.play("pit_fall", 0.0, 1.0, 0.05)
		Effects.dust_burst(effects, pit + Vector3.UP * 0.2, Color(0.72, 0.66, 0.58, 0.9))
		camera.shake(0.35)
		Haptics.pulse(60, 0.8)
		if is_instance_valid(pit_view):
			pit_view.fill())
	if view.state.key >= 0 and not result.explodes:
		_open_group(view.state.key, result.opened)
	if not result.explodes:
		_check_deadlock()


## A bomb reached zero (tanker blasts start from their crash instead).
func _on_exploded(id: int, cell: Vector2i) -> void:
	if session.lose_reason != "bomb":
		return
	var view: VehicleView = vehicle_views.get(id)
	_explode(board.cell_to_world(Vector2(cell)), [view] if view else [])


## The blast: slow motion, flash and fire, the cars caught in it burnt and
## the ones nearby thrown aside, heavy shake and rumble; the camera rushes in
## on it under a red flash and a "BOOM!".
func _explode(at: Vector3, burnt: Array) -> void:
	_boom_cinematic(at)
	_clear_hint()
	_release_held_hint()
	Effects.explosion(effects, at)
	Sfx.play("explosion", 2.0, 1.0, 0.04)
	Sfx.duck_music(3.0, -20.0)
	camera.shake(1.0)
	Haptics.pulse(400, 1.0)
	for v in burnt:
		if is_instance_valid(v):
			var away: Vector3 = (v as VehicleView).global_position - at
			away.y = 0.0
			(v as VehicleView).play_burnt(away.normalized() if away.length() > 0.1 else Vector3.ZERO)
	var reach := board.theme.cell_size * 2.6
	for v in vehicle_views.values():
		if v in burnt:
			continue
		var away: Vector3 = (v as VehicleView).global_position - at
		away.y = 0.0
		if away.length() < reach:
			(v as VehicleView).nudge(away.normalized() * 2.5)
			(v as VehicleView).jolt(randf_range(-0.3, 0.3))
	# A heartbeat of slow motion (in real time, so it always ends).
	Engine.time_scale = 0.3
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


## Every tap counts the bombs down: the numbers jump, beeps get higher.
func _on_bombs_ticked() -> void:
	var lowest := 99
	for v in vehicle_views.values():
		if (v as VehicleView).state.bomb > 0:
			(v as VehicleView).update_bomb()
			lowest = mini(lowest, (v as VehicleView).state.bomb)
	if lowest < 99 and session.state == GameSession.State.PLAYING:
		Sfx.play("bomb_beep", -4.0 if lowest <= 3 else -9.0, 1.0 if lowest > 3 else 1.25, 0.0)
		if lowest <= 3:
			Haptics.pulse(30, 0.6)


## Offers "Bomb +3" while a bomb that has not had extra time is down to 3.
func _refresh_bomb_offer() -> void:
	hud.set_bomb_offer(session.state == GameSession.State.PLAYING and _urgent_bomb() >= 0)


func _urgent_bomb() -> int:
	var best := -1
	for id in session.board.vehicles:
		var v: VehicleState = session.board.vehicles[id]
		if v.bomb > 0 and v.bomb <= 3 and not _bomb_boosted.has(id):
			if best < 0 or v.bomb < (session.board.vehicles[best] as VehicleState).bomb:
				best = id
	return best


# --- Cut scenes --------------------------------------------------------------------

## Level-end finale (about 2 s, a tap skips it): the last car leaves in slow
## motion with the camera on its tail, sparks fly as it passes the barrier,
## then the view pulls back, "CLEARED!" slams in with the best combo and the
## world's own flourish plays (bigger on hard levels).
func _win_cinematic(played: GameSession) -> void:
	_cinematic = true
	_skip = false
	var car := _last_out if is_instance_valid(_last_out) and _last_out.is_processing() else null
	if car:
		Engine.time_scale = 0.45
		camera.cinematic_to(car.global_position, 1.7, 0.3)
		_follow = car
		var gate := Vector3(0.0, 0.9, board.exit_gate_z())
		var sparked := false
		var start := Time.get_ticks_msec()
		# Follow until the car is past the barrier (at most 1.5 s).
		while Time.get_ticks_msec() - start < 1500 and not _skip and played == session and is_instance_valid(car) \
				and car.global_position.z < gate.z + 1.5:
			if not sparked and car.global_position.z > gate.z - 0.4:
				sparked = true
				Effects.impact(effects, gate, Vector3.BACK)
				Sfx.play("gate_open", -2.0, 0.8, 0.0)
				Haptics.pulse(20, 0.5)
			await get_tree().process_frame
		_follow = null
		Engine.time_scale = 1.0
	camera.cinematic_end(0.2 if _skip else 0.45)
	if played != session:
		_cinematic = false
		return
	if not _skip:
		var hard := session.level.hard
		hud.flash(Color(1, 1, 1, 0.6 if hard else 0.45))
		var sub := tr("CLEARED_COMBO") % _best_combo if _best_combo >= 3 else ""
		hud.show_banner(tr("CLEARED_HARD" if hard else "CLEARED"), Color("ffd34d"), Color("b5541c"), sub)
		Sfx.play("celebrate", -2.0, 1.0, 0.0)
		Haptics.pulse(40, 0.7)
		var world_theme := WorldTheme.for_world(world_index)
		var extent := maxf(board.view_half_extents().x, board.view_half_extents().y)
		Flourish.play(effects, world_theme.id, Vector3.ZERO, extent, hard)
		if world_theme.id == "city":
			hud.confetti()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < (1300 if hard else 1000) and not _skip and played == session:
			await get_tree().process_frame
	hud.hide_banner()
	_cinematic = false


## Explosion close-up: the camera rushes to the blast under a red flash and a
## shaking "BOOM!", holds a moment, then pulls back for the lose panel.
func _boom_cinematic(at: Vector3) -> void:
	var played := session
	camera.cinematic_to(at, 1.8, 0.25)
	hud.flash(Color(1.0, 0.18, 0.1, 0.55), 0.7)
	hud.show_banner(tr("LOSE_BOOM_TITLE"), Color("ff4433"), Color("4a0b07"))
	await get_tree().create_timer(1.3, true, false, true).timeout
	if played != session:
		return
	hud.hide_banner()
	camera.cinematic_end(0.5)


# --- Rush hour (endless mode) -----------------------------------------------------

func _rush_tick(delta: float) -> void:
	_rush_timer -= delta
	hud.set_rush_progress(1.0 - _rush_timer / Rush.interval(_rush_arrived))
	if _rush_next.is_empty() and _rush_timer <= Rush.WARNING:
		_rush_next = Rush.pick(session.board, _rush_rng, _rush_arrived)
		if _rush_next.is_empty():
			session.end("full")
			return
		_mark_drop(_rush_next)
	if _rush_timer > 0.0:
		return
	var entry := _rush_next
	_rush_next = {}
	if is_instance_valid(_rush_marker):
		_rush_marker.queue_free()
	# The marked spot may have been taken in the meantime (a pull-forward).
	if session.add_vehicle(entry) < 0:
		entry = Rush.pick(session.board, _rush_rng, _rush_arrived)
		if entry.is_empty() or session.add_vehicle(entry) < 0:
			session.end("full")
			return
	_rush_arrived += 1
	_rush_timer = Rush.interval(_rush_arrived)


## Pulsing outline where the next car is about to land.
func _mark_drop(entry: Dictionary) -> void:
	var length := VehicleCatalog.cells(entry.type)
	var cell_size := board.theme.cell_size
	var span := Vector2(length - 1, 0) if GridDir.is_horizontal(entry.dir) else Vector2(0, length - 1)
	var area := Vector2(cell_size - 0.1, cell_size * length - 0.1)
	_rush_marker = FlatIcon.create(FlatIcon.frame_shapes(area, 0.1), Color("ff8a3d"), 0.03)
	_rush_marker.position = board.cell_to_world(Vector2(entry.cell) + span * 0.5) + Vector3.UP * 0.02
	_rush_marker.rotation.y = GridDir.to_yaw(entry.dir)
	effects.add_child(_rush_marker)
	var t := _rush_marker.create_tween().set_loops()
	t.tween_property(_rush_marker, "scale", Vector3(1.08, 1.0, 1.05), 0.2)
	t.tween_property(_rush_marker, "scale", Vector3.ONE, 0.2)


func _on_vehicle_added(id: int) -> void:
	var view := VehicleView.new()
	pieces.add_child(view)
	view.setup(board, session.board.vehicles[id], effects)
	vehicle_views[id] = view
	view.drop_in(func():
		_rush_landed[id] = _clock
		Sfx.play("crash", -10.0, 0.7, 0.1)
		camera.shake(0.15)
		Haptics.pulse(15, 0.4))
	_refresh_rescues()


func _show_rush_score() -> void:
	hud.set_level_title(tr("RUSH_SCORE") % _rush_score)
	hud.set_time_of_day(tr("RUSH_BEST") % int(Progress.stats.get("rush_best", 0)))


## The run is over: keep the best score, pay out coins and show the panel.
func _on_rush_over() -> void:
	var played := session
	if is_instance_valid(_rush_marker):
		_rush_marker.queue_free()
	var best_before := _rush_best_before
	Progress.max_stat("rush_best", _rush_score)
	Quests.report(Progress, "rush_score", _rush_score)
	if not _rush_continued:
		Progress.add_stat("rush_runs")
	var per_coin := int(Economy.value("rush_points_per_coin"))
	var coins := _rush_score / per_coin - _rush_paid / per_coin # a continued run pays only what is new
	_rush_paid = _rush_score
	if coins > 0:
		Progress.add_coins(coins, "rush")
	Progress.save()
	var time := _clock - _level_start
	Analytics.design("rush:score", _rush_score)
	Analytics.design("rush:over:%s" % (session.lose_reason if session.lose_reason != "" else "moves"), time)
	await get_tree().create_timer(lose_delay + (1.6 if session.lose_reason in ["explosion", "bomb"] else 0.4)).timeout
	if played != session:
		return
	Sfx.duck_music(2.0)
	Sfx.play("lose", -2.0, 1.0, 0.0)
	var note := ""
	if best_before > 0 and _rush_score < best_before and _rush_score >= best_before * 0.8:
		note = tr("RUSH_ALMOST") % (best_before - _rush_score)
	hud.set_bomb_offer(false)
	hud.show_rush_over({"score": _rush_score, "best": maxi(best_before, _rush_score),
		"new_best": _rush_score > best_before and _rush_score > 0, "time": time, "combo": _best_combo,
		"coins": coins, "reason": session.lose_reason, "offer": _continue_offer(), "note": note})
	_announce_achievements()


func _on_won() -> void:
	var played := session
	_set_crane_mode(false)
	var mistakes_used := session.crashes
	var stars := Economy.stars_for(mistakes_used, _rescued)
	var time := _clock - _level_start
	var record: Dictionary
	if Daily.playing:
		var daily := Progress.record_daily_win()
		record = {"coins": daily.coins, "best_time": false, "streak": daily.streak}
	else:
		record = Progress.record_win(world_index, level_index, stars, time, _best_combo, session.level.hard)
	var result := {
		"stars": stars, "time": time, "combo": _best_combo, "coins": record.coins,
		"best_time": record.best_time, "perfect": stars == 3,
		"star_note": "" if stars == 3 else ("STAR_NOTE_RESCUE" if _rescued and mistakes_used == 0 else "STAR_NOTE_CRASH"),
		"last_level": Daily.playing or not Progress.has_next_level(world_index, level_index),
		"double_ok": record.coins > 0 and AdManager.rewarded_available("double_coins"),
	}
	if record.has("streak"):
		result["streak"] = record.streak
	Quests.report(Progress, "level_won")
	if stars == 3:
		Quests.report(Progress, "perfect")
	if Daily.playing:
		Quests.report(Progress, "daily")
	if session.level.vehicles.any(func(e): return e.type == "tanker"):
		Quests.report(Progress, "tanker_level")
	if session.level.vehicles.any(func(e): return e.get("bomb", 0) > 0):
		Quests.report(Progress, "bomb_level")
	Analytics.level("Complete", world_index, level_index, Daily.playing, stars,
			{"time": snappedf(time, 0.1), "crashes": session.crashes, "taps": session.taps, "combo": _best_combo})
	if _onboarding:
		result["onboarding"] = true
		result["double_ok"] = false
		if level_index == 2:
			# Third level done: the menu opens for the first time.
			Progress.mark_tutorial_seen()
			result["last_level"] = true
			result["onboarding_done"] = true
	_earned = record.coins
	await _win_cinematic(played)
	if played == session:
		Sfx.duck_music(2.0)
		Sfx.play("win", -2.0, 1.0, 0.0)
		hud.show_win(result)
		_announce_achievements()


func _on_lost() -> void:
	if Rush.playing:
		_on_rush_over()
		return
	var played := session
	var reason := session.lose_reason
	Analytics.level("Fail", world_index, level_index, Daily.playing, -1,
			{"time": snappedf(_clock - _level_start, 0.1), "cars_left": session.board.vehicles.size(),
			"reason": reason if reason != "" else "moves"})
	# Let an explosion burn for a moment before the panel covers it.
	await get_tree().create_timer(lose_delay + (1.6 if reason != "" else 0.0)).timeout
	if played == session and session.state == GameSession.State.LOST:
		Sfx.duck_music(2.0)
		Sfx.play("lose", -2.0, 1.0, 0.0)
		var offer := {} if _onboarding else _continue_offer()
		var left := session.board.vehicles.size()
		var note := ""
		if not offer.is_empty() and left > 0 and (left <= 5 or left <= session.level.vehicles.size() * 0.3):
			note = tr("LOSE_ALMOST") % left
		hud.set_bomb_offer(false)
		hud.show_lose(offer, reason, note)


# --- Rescues -------------------------------------------------------------------------

## Updates the rescue bar badges: owned count, free hints, else the price.
func _refresh_rescues() -> void:
	if session == null:
		return
	var hints := Progress.item_count("hint") + Progress.free_hints_left()
	_set_badge("hint", hints)
	_set_badge("undo", Progress.item_count("undo"), session.can_undo())
	_set_badge("crane", Progress.item_count("crane"))


func _set_badge(kind: String, owned: int, enabled := true) -> void:
	if owned > 0:
		hud.set_rescue(kind, str(owned), false, enabled)
	else:
		hud.set_rescue(kind, str(Economy.price(kind)), true, enabled)


func _on_rescue(kind: String) -> void:
	if session == null or session.state != GameSession.State.PLAYING or _tutorial_open:
		return
	match kind:
		"hint":
			var owned := Progress.use_item("hint")
			if owned or Progress.use_free_hint():
				Analytics.design("rescue:hint:%s" % ("owned" if owned else "free"))
				_give_hint()
			else:
				_offer("hint")
		"undo":
			if not session.can_undo():
				return
			if Progress.use_item("undo"):
				Analytics.design("rescue:undo:owned")
				_undo()
			else:
				_offer("undo")
		"crane":
			if _crane_mode:
				_set_crane_mode(false)
			elif Progress.item_count("crane") > 0:
				_set_crane_mode(true)
			else:
				_offer("crane")
	_refresh_rescues()


func _offer(kind: String) -> void:
	Analytics.design("offer:" + kind)
	var price := Economy.price(kind)
	var ad_ok := kind != "undo" and AdManager.rewarded_available(kind)
	hud.show_offer(kind, price, Progress.coins >= price, ad_ok)


## Paid with coins or an ad: the rescue goes into the inventory and is used.
func _on_offer_accepted(kind: String, with_ad: bool) -> void:
	var grant := func():
		Progress.add_item(kind)
		_on_rescue(kind)
	if kind == "bomb_time":
		grant = func():
			var id := _urgent_bomb()
			if id < 0:
				return
			Analytics.design("rescue:bomb_time:%s" % ("ad" if with_ad else "coins"))
			_bomb_boosted[id] = true
			_rescued = true
			session.add_bomb_time(id, int(Economy.value("bomb_time")))
			Sfx.play("unlock", -2.0, 1.2, 0.0)
	if with_ad:
		AdManager.show_rewarded(kind, grant)
	elif Progress.spend_coins(Economy.price(kind), "rescue:" + kind):
		grant.call()


## Lights up the next car of a winning line until it is tapped.
func _give_hint() -> void:
	var id := LevelSolver.next_tap(session.board, session.fall_budget())
	if id < 0:
		hud.show_hint(tr("HINT_DEADLOCK_UNDO"))
		return
	_release_held_hint()
	_held_hint = id
	_rescued = true
	vehicle_views[id].hold_hint()
	hud.show_hint(tr("HINT_GLOWING"))
	Sfx.play("combo", -8.0, 1.3, 0.0)


func _release_held_hint() -> void:
	if vehicle_views.has(_held_hint):
		vehicle_views[_held_hint].clear_hint()
	_held_hint = -1


func _undo() -> void:
	var was := session.undo()
	if was < 0:
		Progress.add_item("undo") # nothing to take back: keep it
		return
	_rescued = true
	Sfx.play("ui_click", -2.0, 0.8, 0.0)
	hud.hide_hint()
	if was == BoardState.Action.CRASH:
		hud.hide_result() # a lost level resumes


func _set_crane_mode(on: bool) -> void:
	_crane_mode = on
	hud.set_crane_active(on)
	if on:
		hud.show_hint(tr("HINT_CRANE"))
	else:
		hud.hide_hint()


## The first time the player reaches the gift level, a free crane and a tip.
func _maybe_gift_crane() -> void:
	var at: Array = Economy.value("crane_gift_level")
	if world_index != int(at[0]) or level_index != int(at[1]) or Progress.flag("crane_gift"):
		return
	Progress.set_flag("crane_gift")
	Progress.add_item("crane")
	_refresh_rescues()
	if not _tutorial_open:
		_tutorial_open = true
		hud.show_tutorial("CRANE_GIFT_TITLE", ["CRANE_GIFT_1", "CRANE_GIFT_2"])


## The lose panel's rescue: rewind an explosion (once per level) or buy
## extra moves; in Rush Hour, one continue per run (clear cars from a full
## lot, a life, or a rewind). Empty when nothing can help.
func _continue_offer() -> Dictionary:
	_continue_kind = ""
	var kind := ""
	if Rush.playing:
		if not _rush_continued:
			match session.lose_reason:
				"full": kind = "rush_clear"
				"": kind = "rush_life"
				_: kind = "rewind" if session.can_rewind() else ""
	elif session.can_rewind():
		kind = "rewind" if not _rewound else ""
	elif not session.is_deadlocked_ignoring_moves():
		kind = "continue"
	if kind == "":
		return {}
	_continue_kind = kind
	var placement := _continue_placement()
	var price := Economy.price(placement)
	Analytics.design("offer:" + kind)
	return {"kind": kind, "moves": int(Economy.value("continue_moves")), "price": price,
		"can_afford": Progress.coins >= price, "ad_ok": AdManager.rewarded_available(placement)}


## Ad placement (and price) of the current lose-panel rescue.
func _continue_placement() -> String:
	if Rush.playing:
		return "rush_continue"
	return "rewind" if _continue_kind == "rewind" else "continue"


func _on_continue(with_ad: bool) -> void:
	var kind := _continue_kind
	var placement := _continue_placement()
	var resume := func():
		Analytics.design("rescue:%s:%s" % [kind, "ad" if with_ad else "coins"])
		_rescued = true
		hud.hide_result()
		match kind:
			"continue":
				session.add_mistakes(int(Economy.value("continue_moves")))
			"rewind":
				_rewound = true
				_rush_continued = Rush.playing
				session.rewind()
			"rush_life":
				_rush_continued = true
				session.add_mistakes(1)
			"rush_clear":
				_rush_continued = true
				_rush_clear(int(Economy.value("rush_continue_clears")))
		_refresh_rescues()
	if with_ad:
		AdManager.show_rewarded(placement, resume)
	elif Progress.spend_coins(Economy.price(placement), "rescue:" + kind):
		resume.call()


## Rush continue on a full lot: the crane takes `count` cars away (the most
## boxed-in first) and the run goes on with a breather before the next drop.
func _rush_clear(count: int) -> void:
	var ids: Array = session.board.vehicles.keys()
	ids.sort_custom(func(a, b): return session.board.probe(a).free and not session.board.probe(b).free)
	ids.reverse()
	session.resume()
	for id in ids.slice(0, count):
		session.lift(id)
	_rush_next = {}
	if is_instance_valid(_rush_marker):
		_rush_marker.queue_free()
	_rush_timer = Rush.interval(_rush_arrived) + 1.5


## Rewind rescue: the lot is rebuilt as it was before the fatal tap, with a
## quick "tape rewinding" flash.
func _on_rewound() -> void:
	Engine.time_scale = 1.0
	camera.reset_view()
	hud.hide_banner()
	for child in pieces.get_children() + effects.get_children():
		child.queue_free()
	vehicle_views.clear()
	obstacle_views.clear()
	_build_pieces()
	for id in vehicle_views:
		vehicle_views[id].pop_in(0.05)
	hud.flash(Color(0.55, 0.8, 1.0, 0.6), 0.5)
	Sfx.play("tire_squeal", -4.0, 1.6, 0.0)
	_combo = 0


## Views for every vehicle and obstacle on the board as it is now (gates
## already opened and pits already filled stay away).
func _build_pieces() -> void:
	for id in session.board.vehicles:
		var view := VehicleView.new()
		pieces.add_child(view)
		view.setup(board, session.board.vehicles[id], effects)
		vehicle_views[id] = view
	for e in session.level.obstacles:
		if e.type == "gate" and not session.board.gates.has(e.cell):
			continue
		if e.type == "pit" and not session.board.pits.has(e.cell):
			continue
		var obstacle := ObstacleView.new()
		pieces.add_child(obstacle)
		obstacle.setup(board, e.type, e.cell, e.get("group", -1))
		obstacle_views[e.cell] = obstacle


func _on_vehicle_lifted(id: int, result: BoardState.MoveResult) -> void:
	var view: VehicleView = vehicle_views[id]
	vehicle_views.erase(id)
	view.play_lift()
	Progress.add_stat("cars")
	Progress.add_stat("cranes")
	_announce_achievements()
	Sfx.play("unlock", -4.0, 0.7, 0.0)
	Haptics.pulse(25, 0.5)
	if view.state.key >= 0:
		_open_group(view.state.key, result.opened)


func _on_vehicle_restored(id: int) -> void:
	var view: VehicleView = vehicle_views[id]
	view.state = session.board.vehicles[id]
	view.play_restore()
	view.update_bomb(false)


# --- Developer mode ---------------------------------------------------------------

func _show_dev_panel() -> void:
	var actions := [
		[tr("DEV_AUTO_SOLVE"), _dev_auto_solve],
		[tr("DEV_WIN"), _dev_win],
		[tr("DEV_LOSE"), _dev_lose],
		[tr("DEV_COINS"), func(): Progress.add_coins(1000, "dev:dev")],
		[tr("DEV_RESCUES"), func():
			for item in ["hint", "undo", "crane"]:
				Progress.add_item(item, 5)
			_refresh_rescues()],
	]
	if not Daily.playing:
		actions.append([tr("DEV_PREV"), func(): Transition.cover(load_level.bind(level_index - 1))])
		actions.append([tr("DEV_NEXT"), func(): Transition.cover(load_level.bind(level_index + 1))])
	hud.show_dev_panel(actions)


## Plays the solver's winning line, one tap at a time.
func _dev_auto_solve() -> void:
	var played := session
	var report := LevelSolver.solve_board(session.board, session.fall_budget())
	if not report.solvable:
		hud.show_hint(tr("HINT_DEADLOCK_UNDO"))
		return
	for id in report.order:
		if played != session or session.state != GameSession.State.PLAYING:
			return
		_clear_hint()
		session.tap(id)
		await get_tree().create_timer(0.3).timeout


## Lifts every remaining car out at once.
func _dev_win() -> void:
	for id in session.board.vehicles.keys():
		if session.state == GameSession.State.PLAYING:
			session.lift(id)


func _dev_lose() -> void:
	if session.state != GameSession.State.PLAYING:
		return
	session.mistakes_left = 0
	session.state = GameSession.State.LOST
	session.mistakes_changed.emit(0)
	session.lost.emit()


## Toasts every achievement reached since the level began (once each).
func _announce_achievements() -> void:
	if _onboarding:
		return # the first levels stay free of pop-ups; trophies wait in the menu
	var now := Achievements.done_ids(Progress)
	var delay := 0.0
	for id in now:
		if id in _done_at_start:
			continue
		_done_at_start.append(id)
		get_tree().create_timer(delay).timeout.connect(func():
			hud.show_toast(tr("ACH_UNLOCKED"), tr("ACH_" + str(id).to_upper())))
		delay += 2.6


func _to_menu() -> void:
	Progress.save() # lifetime stats gathered during play
	if session != null and session.state == GameSession.State.PLAYING and not Rush.playing:
		Analytics.level("Fail", world_index, level_index, Daily.playing, -1, {"quit": 1})
	MainMenu.return_to_world = not Daily.playing and not Rush.playing and not _onboarding
	if _onboarding:
		MainMenu.skip_gift_once() # the menu's first visit should not open with a pop-up
	Daily.stop()
	Rush.stop()
	Transition.change_scene(MENU_SCENE)
