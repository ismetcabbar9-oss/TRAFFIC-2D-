extends SceneTree
## Dev helper: shows the rescue bar, a paid hint, the crane, a rescue offer and
## the lose panel with its continue offer. Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/rescue_demo.gd -- <out_dir>

var out_dir := "user://"


func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	var progress := root.get_node("Progress")
	progress.tutorial_seen = true
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE", "PIT", "TANKER", "BOMB"]
	progress.flags["crane_gift"] = true
	progress.coins = 260
	progress.inventory = {"crane": 1}
	progress.current_world = 0
	progress.current_level = 9
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	await _shot("r1_bar")
	game._on_rescue("hint")
	await create_timer(0.5).timeout
	await _shot("r2_hint")
	game._on_rescue("crane")
	await create_timer(0.2).timeout
	await _shot("r3_crane_mode")
	var id: int = game.session.board.vehicles.keys()[3]
	game._set_crane_mode(false)
	progress.use_item("crane")
	game.session.lift(id)
	game._refresh_rescues()
	await create_timer(0.55).timeout
	await _shot("r4_lift")
	await create_timer(1.0).timeout
	game._on_rescue("crane") # none left: offer
	await create_timer(0.4).timeout
	await _shot("r5_offer")
	var hud_root: Control = game.hud._root
	hud_root.get_child(hud_root.get_child_count() - 1).queue_free() # close the offer
	game.session.mistakes_left = 1
	var blocked := -1
	for v in game.session.board.vehicles:
		if not game.session.board.probe(v).free:
			blocked = v
			break
	game.session.tap(blocked)
	await create_timer(1.6).timeout
	await _shot("r6_lose")
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % label))
