extends SceneTree
## Dev helper: plays the first session from a fresh save with real touches
## (it RESETS the local progress): the game must open straight into level 1,
## a hand guides the taps, levels 1-3 have no menu or rescues, and after
## level 3 the menu opens. Saves screenshots of each step.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/onboarding_demo.gd -- <out_dir>

var out_dir := "user://"


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	await process_frame
	var progress := root.get_node("Progress")
	progress.reset_progress()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await create_timer(2.6).timeout
	print("first scene: ", current_scene.name)
	await _shot("o1_level1_hand")
	for level in 3:
		var game: Node = current_scene
		var guard := 0
		while game.session.state == GameSession.State.PLAYING and guard < 40:
			guard += 1
			var id := LevelSolver.next_tap(game.session.board)
			var view: VehicleView = game.vehicle_views[id]
			_tap(game.camera.unproject_position(view.global_position + Vector3.UP * 0.6))
			await create_timer(0.35).timeout
		while not game.hud._overlay.visible:
			await process_frame
		await create_timer(2.2).timeout # stars and coins count up
		await _shot("o%d_win_level%d" % [level + 2, level + 1])
		game.hud._on_primary()
		await create_timer(1.4).timeout
		if level == 1:
			await create_timer(4.5).timeout # level 3: the hand waits for hesitation
			await _shot("o4b_level3_idle_hand")
	await create_timer(1.5).timeout
	print("after level 3: ", current_scene.name, ", tutorial seen: ", progress.tutorial_seen)
	await _shot("o6_menu")
	quit()


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = pos
		e.pressed = pressed
		Input.parse_input_event(e)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
