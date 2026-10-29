extends SceneTree
## Dev helper: a hard "one chance" level, and a level cleared with a hint (the
## result screen says why the third star was missed). Usage (under xvfb-run,
## see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/difficulty_demo.gd -- <out_dir> [locale]

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
	progress.inventory = {"hint": 1}
	progress.current_world = 1
	progress.current_level = 19
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	await _shot("d1_one_chance")
	game.queue_free()
	await process_frame

	progress.current_world = 0
	progress.current_level = 10
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	await _shot("d2_level_11")
	game._on_rescue("hint")
	await create_timer(0.3).timeout
	for id in LevelSolver.solve_board(game.session.board).order:
		game.session.tap(id)
		await create_timer(0.05).timeout
	await create_timer(5.0).timeout
	await _shot("d3_result_hint")
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % label))
