extends SceneTree
## Dev helper: opens a level at the current window size (use a phone-like
## --resolution such as 540x1200), then pinches in and pans with simulated
## fingers, saving a screenshot of each step.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 540x1200 --script res://tools/phone_demo.gd -- <out_dir> <world> <level>

var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	await process_frame
	var progress := root.get_node("Progress")
	progress.tutorial_seen = true
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE"]
	progress.flags["crane_gift"] = true
	progress.current_world = int(args[1]) - 1
	progress.current_level = int(args[2]) - 1
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await create_timer(1.4).timeout
	await _shot("phone_1_full")
	var size := root.get_visible_rect().size
	var c := size * Vector2(0.5, 0.42)
	# Pinch: two fingers spreading apart around the middle of the board.
	_touch(0, c - Vector2(60, 0), true)
	_touch(1, c + Vector2(60, 0), true)
	for i in 10:
		_drag(0, c - Vector2(60 + i * 12, 0))
		_drag(1, c + Vector2(60 + i * 12, 0))
		await process_frame
	_touch(0, c - Vector2(180, 0), false)
	_touch(1, c + Vector2(180, 0), false)
	await create_timer(0.2).timeout
	await _shot("phone_2_zoomed")
	# One-finger pan toward the bottom-right corner.
	_touch(0, c, true)
	for i in 10:
		_drag(0, c - Vector2(i * 14, i * 14))
		await process_frame
	_touch(0, c - Vector2(140, 140), false)
	await create_timer(0.2).timeout
	await _shot("phone_3_panned")
	print("zoom ", game.camera.zoom, " pan ", game.camera.pan)
	quit()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
