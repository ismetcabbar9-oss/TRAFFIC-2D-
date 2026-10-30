extends SceneTree
## Dev helper: a new player's first session, levels 1-10, from a fresh save
## (it RESETS the local progress). A bot plays at a human pace (about a tap a
## second, now and then a wrong one) through the real flow - onboarding, the
## menu after level 3, "Next" between levels - and logs what the player sees:
## tip cards, hints, toasts, results, and how long each level takes.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/first_session_demo.gd -- <out_dir> [locale]

var out_dir := "user://"
var _last_hint := ""
var _cards := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	await process_frame
	if args.size() > 1:
		TranslationServer.set_locale(args[1])
	var progress := root.get_node("Progress")
	progress.reset_progress()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _wait(2.6)
	await create_timer(3.0).timeout # the pinch / pan guide plays a round
	if is_instance_valid(current_scene.hud.zoom_guide):
		current_scene.hud.zoom_guide.closed.emit()
	await create_timer(1.2).timeout
	for level in 10:
		if current_scene.name != "Game":
			print("[menu] after level ", level, ": opening the next level from the Play button")
			await _shot("s%02d_menu" % level)
			current_scene._continue()
			await _wait(2.5)
		var game: Node = current_scene
		var start: float = game._clock
		await _wait(1.6)
		await _shot("s%02d_start" % (level + 1))
		var taps := 0
		var wrong := level in [5, 8] # a slip on levels 6 and 9
		while game.session.state == GameSession.State.PLAYING and taps < 60:
			_watch(game)
			if game._tutorial_open:
				_cards += 1
				print("  [card] level ", level + 1, " tip card open")
				await _shot("s%02d_card" % (level + 1))
				for b in game.hud.find_children("*", "Button", true, false):
					if (b as Button).text == tr("TUT_START"):
						(b as Button).pressed.emit()
				await _wait(0.8)
				continue
			var id := LevelSolver.next_tap(game.session.board, game.session.fall_budget())
			if wrong:
				for other in game.session.board.vehicles:
					if game.session.board.probe(other).action == BoardState.Action.CRASH and not game.session.board.probe(other).explodes:
						id = other
						break
				wrong = false
			if id < 0:
				break
			var view: VehicleView = game.vehicle_views[id]
			_tap(game.camera.unproject_position(view.global_position + Vector3.UP * 0.6))
			taps += 1
			await _wait(1.0)
		for i in 300:
			_watch(game)
			if game.hud._overlay.visible:
				break
			await _wait(0.05)
		print("level %d: %d cars, %d taps, %.0f s of play, crashes %d, result '%s' %s" % [level + 1,
			game.session.level.vehicles.size(), taps, game._clock - start, game.session.crashes,
			game.hud._result_title.text, game.hud._star_note.text if game.hud._star_note.visible else ""])
		await _wait(2.2)
		await _shot("s%02d_result" % (level + 1))
		game.hud._on_primary()
		await _wait(2.0)
	print("tip cards seen: ", _cards)
	quit()


## Logs hints as they change.
func _watch(game: Node) -> void:
	var text: String = game.hud._hint_label.text if game.hud._hint.visible else ""
	if text != _last_hint and text != "":
		print("  [hint] ", text)
	_last_hint = text


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = pos
		e.pressed = pressed
		Input.parse_input_event(e)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
