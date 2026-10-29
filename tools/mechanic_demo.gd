extends SceneTree
## Dev helper: plays a small level using every world mechanic and saves
## screenshots after each move. Usage (under xvfb-run, see capture.gd):
##   godot --path . --rendering-method forward_plus --resolution 720x1280 \
##     --script res://tools/mechanic_demo.gd -- <out_dir>

const LEVEL := {
	"cols": 6, "rows": 7, "mistakes": 3,
	"vehicles": [
		{"type": "pickup", "col": 0, "row": 4, "dir": "up", "cargo": true},
		{"type": "sedan", "col": 2, "row": 2, "dir": "right", "turn": "cw"},
		{"type": "sedan_sports", "col": 4, "row": 5, "dir": "right", "key": 0},
		{"type": "suv", "col": 0, "row": 0, "dir": "right", "lock": 0},
		{"type": "taxi", "col": 5, "row": 2, "dir": "down", "key": 1},
		{"type": "van", "col": 3, "row": 4, "dir": "left", "turn": "ccw"},
	],
	"obstacles": [{"type": "gate", "col": 3, "row": 0, "group": 1}],
}
const MOVES := [[-1, "start"], [0, "cargo_step"], [1, "turn"], [3, "locked_tap"],
	[2, "key_leaves"], [4, "gate_opens"]]

var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	await process_frame
	var progress := root.get_node("Progress")
	progress.tutorial_seen = true
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE", "PIT", "TANKER", "BOMB"]
	var path := "user://mechanic_demo.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(LEVEL))
	f.close()
	LevelCatalog.override_path = path
	progress.current_world = 0
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	for move in MOVES:
		if move[0] >= 0:
			game.session.tap(move[0])
			await create_timer(0.16).timeout
			await _shot(move[1] + "_mid")
			await create_timer(0.6).timeout
		await _shot(move[1])
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("mech_%s.png" % label))
