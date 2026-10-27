extends SceneTree
## Dev helper: switches developer mode on with seven clicks on the title,
## unlocks everything, opens the in-game developer panel and auto-solves a
## level, saving screenshots. Leaves developer mode off again at the end.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/dev_mode_demo.gd -- <out_dir>
var out := ""
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	await process_frame
	var p := root.get_node("Progress")
	p.dev = {}
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._show("home", false)
	for i in 5: await process_frame
	# Find the title label and click it 7 times like a finger would.
	var title: Label
	for l in menu._pages["home"].get_children():
		if l is Label and l.text == "Traffic Escape":
			title = l
	var at := title.get_global_rect().get_center()
	for i in 7:
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.position = at
			e.global_position = at
			root.push_input(e)
			await process_frame
	print("dev enabled after 7 taps: ", p.dev_enabled(), " page ", menu._current)
	for i in 10: await process_frame
	await _shot("dev_page")
	p.set_dev("unlock_all", true)
	menu._world = 4
	menu._show("world", false)
	for i in 10: await process_frame
	await _shot("dev_world5")
	print("airport level 20 unlocked: ", p.is_level_unlocked(4, 19))
	menu.queue_free()
	p.current_world = 4
	p.current_level = 7
	p.tips_seen = ["CARGO", "TURN", "LOCK", "GATE"]
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	game._show_dev_panel()
	await create_timer(0.3).timeout
	await _shot("dev_panel")
	var dim: Node = game.hud._root.get_child(game.hud._root.get_child_count() - 1)
	dim.queue_free()
	game._dev_auto_solve()
	await create_timer(2.0).timeout
	await _shot("dev_autosolve")
	await create_timer(12.0).timeout
	print("auto solve state: ", game.session.state)
	p.set_dev("enabled", false)
	p.set_dev("unlock_all", false)
	quit()
func _shot(n):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(n + ".png"))
