extends SceneTree
## Dev helper: screenshots of the cut scenes - each world's level-end finale
## (slow-motion follow, "CLEARED!", the world's flourish), a hard level's and
## the explosion close-up.
## Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/cinematic_demo.gd -- <out_dir> [locale]

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
	for w in 5:
		await _finale(w, 4, "c%d" % (w + 1))
	await _finale(0, 9, "c6_hard")
	await _boom()
	quit()


## Clears the lot with the crane but for one car, then taps that one out.
func _finale(w: int, i: int, label: String) -> void:
	var game := await _open(w, i)
	var last := -1
	for id in game.session.board.vehicles.keys():
		if last < 0 and game.session.board.probe(id).free:
			last = id
	for id in game.session.board.vehicles.keys():
		if id != last:
			game.session.lift(id)
	await _wait(2.0)
	game.session.tap(last)
	await _wait(0.35)
	await _shot(label + "a_follow")
	await _wait(0.9)
	await _shot(label + "b_cleared")
	await _wait(0.5)
	await _shot(label + "c_flourish")
	game.queue_free()
	await process_frame


func _boom() -> void:
	var tanker_level := 20
	var game := await _open(0, tanker_level)
	var ids: Array = game.session.board.vehicles.keys()
	ids.sort()
	for id in ids:
		var r = game.session.board.probe(id)
		if r.action == BoardState.Action.CRASH and r.explodes:
			game.session.tap(id)
			break
	await _wait(0.4)
	await _shot("c7_boom")
	await _wait(0.6)
	await _shot("c7_boom_b")
	game.queue_free()


func _open(w: int, i: int) -> Node:
	progress.current_world = w
	progress.current_level = i
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await _wait(3.0)
	return game


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % label))
