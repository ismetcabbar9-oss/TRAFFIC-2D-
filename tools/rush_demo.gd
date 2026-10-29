extends SceneTree
## Dev helper: screenshots of the Rush Hour mode - the menu card, the tip
## card, a run in progress (a bot taps cars out while new ones drop in) and
## the lot filling up until the run ends. The end of the run writes the
## local save (best score, coins), like any run.
## Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/rush_demo.gd -- <out_dir> [locale]

var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	await process_frame
	if args.size() > 1:
		TranslationServer.set_locale(args[1])
	var progress := root.get_node("Progress")
	progress.tutorial_seen = true
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE", "PIT", "TANKER", "BOMB"]
	progress.levels = {}
	for i in 12:
		progress.levels["0:%d" % i] = {"stars": 2, "time": 20.0, "combo": 3}
	progress.stats["rush_best"] = 640

	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	menu._show("home", false) # past the daily gift pop-up
	await _wait(1.5)
	await _shot("r1_menu_card")
	menu.queue_free()
	await process_frame

	Rush.start(0)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await _wait(3.0)
	await _shot("r2_tip")
	for b in game.hud.find_children("*", "Button", true, false):
		if (b as Button).text == tr("TUT_START"):
			(b as Button).pressed.emit()
	await _wait(1.0)
	await _shot("r3_start")
	# A bot clears cars quickly for a while.
	var shot_marked := false
	for step in 60:
		var id := LevelSolver.next_tap(game.session.board, 0)
		if id >= 0 and game.session.state == GameSession.State.PLAYING:
			game.session.tap(id)
		await _wait(0.45)
		if not shot_marked and is_instance_valid(game._rush_marker) and step > 6:
			await _shot("r4_drop_marked")
			shot_marked = true
	await _shot("r5_mid_run")
	# Then nobody plays: the lot fills up (sped up).
	Engine.time_scale = 3.0
	var busy_shot := false
	for i in 1200:
		if game.session.state != GameSession.State.PLAYING:
			break
		if not busy_shot and game.session.board.vehicles.size() >= 14:
			Engine.time_scale = 1.0
			await _wait(1.5)
			await _shot("r6_busy")
			busy_shot = true
			Engine.time_scale = 3.0
		await _wait(0.1)
	Engine.time_scale = 1.0
	print("run over: ", game.session.lose_reason, ", cars on the lot ", game.session.board.vehicles.size(),
		", views ", game.vehicle_views.size())
	for i in 100:
		if game.hud._overlay.visible:
			break
		await _wait(0.1)
	await _wait(1.0)
	await _shot("r7_over")
	quit()


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % label))
