extends SceneTree
## Dev helper: plays the demo level with real touch events and saves screenshots
## of key moments. Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/play_scenario.gd -- <out_dir>

var game: Node
var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	await process_frame # let autoloads load the save file first
	root.get_node("Progress").current_level = 0
	root.get_node("Progress").tutorial_seen = true # skip the first-time card
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await _seconds(1.3) # level intro

	var session: GameSession = game.session
	var free_ids := session.board.free_vehicles()
	var blocked := _first_blocked(session)
	print("free at start: ", free_ids, " blocked sample: ", blocked)

	# 1. A free car launches and drives out onto the ring road.
	Engine.time_scale = 0.25 # slow motion so the effects are caught on camera
	_tap_vehicle(free_ids[-1])
	for i in 4:
		await _shot("s1_launch_%d" % i)
		await _seconds(0.07)
	Engine.time_scale = 1.0
	await _seconds(0.3)
	await _shot("s1_exit_mid")
	# 2. A blocked car hits the one in front.
	Engine.time_scale = 0.25
	_tap_vehicle(blocked)
	for i in 8:
		await _shot("s2_crash_%d" % i)
		await _seconds(0.05)
	Engine.time_scale = 1.0
	await _seconds(1.2)
	await _shot("s3_after_crash")

	# 3. Clear the board in the solver's order.
	var report := LevelSolver.solve(session.level)
	var shot_combo := false
	for id in report.order:
		if session.board.vehicles.has(id):
			_tap_vehicle(id)
			await _seconds(0.12)
			if game._combo >= 2 and not shot_combo:
				shot_combo = true
				await _seconds(0.15)
				await _shot("s4_combo")
	await _seconds(0.25)
	for i in 6:
		await _shot("s4_clear_%d" % i)
		await _seconds(0.2)
	await _seconds(2.0)
	print("state after clearing: ", session.state)
	await _shot("s5_win")
	await _seconds(2.2) # stars and coin count-up
	await _shot("s5_win_later")
	var progress := root.get_node("Progress")
	print("after win: coins ", progress.coins, " stars ", progress.level_stars(0, 0))
	game.hud._on_primary() # "Next Level"
	await _frames(10)
	print("level after next: ", game.level_index + 1)
	await _shot("s5b_next_level")

	# 4. Restart and lose by crashing until no moves are left.
	game.load_level(game.level_index)
	await _seconds(1.3)
	session = game.session
	blocked = _first_blocked(session)
	for i in session.mistakes_left:
		_tap_vehicle(blocked)
		await _seconds(0.7)
	await _seconds(0.9)
	print("state after crashes: ", session.state)
	await _shot("s6_lose")
	quit()


func _first_blocked(session: GameSession) -> int:
	for id in session.board.vehicles:
		if not session.board.probe(id).free:
			return id
	return -1


## Sends a real touch at the vehicle's on-screen position.
func _tap_vehicle(id: int) -> void:
	var view: VehicleView = game.vehicle_views[id]
	var cam: Camera3D = game.camera
	var pos := cam.unproject_position(view.global_position + Vector3.UP * 0.6)
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = pos
		e.pressed = pressed
		Input.parse_input_event(e)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	await create_timer(s).timeout
