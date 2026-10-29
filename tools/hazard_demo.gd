extends SceneTree
## Dev helper: screenshots of the hazards - a sinkhole swallowing a car, a
## crash into a fuel tanker, a time bomb going off and the "BOOM!" panel.
## Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/hazard_demo.gd -- <out_dir> [locale]

var out_dir := "user://"
var progress: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	await process_frame
	if args.size() > 1:
		TranslationServer.set_locale(args[1])
	progress = root.get_node("Progress")
	progress.tutorial_seen = true
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE", "TANKER", "BOMB"]

	# Sinkhole: the tip card, the board, then a car tipping in.
	var game := await _open(1, _first_with(1, "pit"))
	await _shot("h1_pit_tip")
	for b in game.hud.find_children("*", "Button", true, false):
		if (b as Button).text == tr("TUT_START"):
			(b as Button).pressed.emit()
	await _wait(2.5)
	var faller := _find(game, func(r): return r.action == BoardState.Action.FALL and not r.explodes)
	await _shot("h2_pit_board")
	game.session.tap(faller)
	await _wait(0.22)
	await _shot("h3_pit_falling")
	await _wait(2.5)
	await _shot("h4_pit_filled")
	game.queue_free()
	await process_frame

	# Fuel tanker: a car drives into it.
	game = await _open(0, _first_with(0, "tanker"))
	await _shot("h5_tanker_board")
	var bumper := _find(game, func(r): return r.action == BoardState.Action.CRASH and r.explodes)
	game.session.tap(bumper)
	await _wait(0.2)
	await _shot("h6_tanker_boom")
	await _wait(0.6)
	await _shot("h7_tanker_smoke")
	await _wait_panel(game)
	await _shot("h8_boom_panel")
	game.queue_free()
	await process_frame

	# Time bomb: the countdown, then it runs out.
	game = await _open(2, _first_with(2, "bomb"))
	await _shot("h9_bomb_board")
	var bomb_id := -1
	for id in game.session.board.vehicles:
		if game.session.board.vehicles[id].bomb > 0:
			bomb_id = id
	game.session.board.vehicles[bomb_id].bomb = 4
	game.vehicle_views[bomb_id].update_bomb(false)
	var other := _find(game, func(r): return r.free, bomb_id)
	game.session.tap(other)
	await _wait(0.5)
	await _shot("h10_bomb_urgent")
	game.session.board.vehicles[bomb_id].bomb = 1
	other = _find(game, func(r): return r.free, bomb_id)
	game.session.tap(other)
	await _wait(0.25)
	await _shot("h11_bomb_boom")
	await _wait_panel(game)
	await _shot("h12_bomb_panel")
	quit()


func _first_with(w: int, hazard: String) -> int:
	for i in LevelCatalog.level_count(w):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelCatalog.path(w, i)))
		var c := HazardPlacer.count(data)
		if c[{"pit": "pits"}.get(hazard, hazard)] > 0:
			return i
	return 0


func _open(w: int, i: int) -> Node:
	progress.current_world = w
	progress.current_level = i
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await _wait(3.0)
	return game


## First vehicle (other than `skip`) whose tap would do what `test` wants.
func _find(game: Node, test: Callable, skip := -1) -> int:
	var ids: Array = game.session.board.vehicles.keys()
	ids.sort()
	for id in ids:
		if id != skip and test.call(game.session.board.probe(id)):
			return id
	return ids[0]


func _wait_panel(game: Node) -> void:
	for i in 200:
		if game.hud._overlay.visible:
			break
		await _wait(0.05)
	await _wait(0.8)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % label))
