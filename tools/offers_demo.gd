extends SceneTree
## Dev helper: screenshots of the ad / coin rescues - rewind after an
## explosion, "Bomb +3", the Rush Hour continue and the "so close" note.
## Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/offers_demo.gd -- <out_dir> [locale]

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
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE", "PIT", "TANKER", "BOMB", "RUSH"]

	var g := await _open(0, 20) # tanker
	for id in g.session.board.vehicles.keys():
		var r = g.session.board.probe(id)
		if r.action == BoardState.Action.CRASH and r.explodes:
			g.session.tap(id)
			break
	await _panel(g)
	await _shot("o1_rewind_offer")
	g._on_continue(false)
	await _wait(1.0)
	await _shot("o2_after_rewind")
	g.queue_free()

	g = await _open(2, 10) # bomb
	for id in g.session.board.vehicles:
		if g.session.board.vehicles[id].bomb > 0:
			g.session.board.vehicles[id].bomb = 3
			g.vehicle_views[id].update_bomb()
	await _wait(0.8)
	await _shot("o3_bomb_button")
	g._offer("bomb_time")
	await _wait(0.6)
	await _shot("o4_bomb_offer")
	g.queue_free()

	Rush.start(0)
	g = await _open(0, 0)
	g._rush_score = 520
	g._rush_best_before = 600
	g.session.end("full")
	await _panel(g)
	await _shot("o5_rush_continue")
	Rush.stop()
	g.queue_free()

	g = await _open(0, 15) # out of moves with three cars left
	var ids: Array = g.session.board.vehicles.keys()
	for id in ids.slice(0, ids.size() - 3):
		g.session.lift(id)
	await _wait(1.5)
	g.session.mistakes_left = 1
	for id in g.session.board.vehicles.keys():
		if not g.session.board.probe(id).free and g.session.state == GameSession.State.PLAYING:
			g.session.tap(id)
	await _panel(g)
	await _shot("o6_so_close")
	quit()


func _open(w: int, i: int) -> Node:
	progress.current_world = w
	progress.current_level = i
	var g: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	await _wait(3.0)
	return g


func _panel(g: Node) -> void:
	for i in 300:
		if g.hud._overlay.visible:
			break
		await _wait(0.05)
	await _wait(1.0)


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % label))
