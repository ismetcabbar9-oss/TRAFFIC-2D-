extends SceneTree
## Dev helper: opens a level and prints render statistics.
## Usage (under xvfb-run): godot --path . --script res://tools/measure_perf.gd -- <level_number> [world_number]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	await process_frame # let autoloads load the save file first
	var progress := root.get_node("Progress")
	progress.current_level = int(args[0]) - 1 if args.size() > 0 else 9
	progress.current_world = int(args[1]) - 1 if args.size() > 1 else 0
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE", "PIT", "TANKER", "BOMB"]
	root.add_child(load("res://scenes/game.tscn").instantiate())
	for i in 30:
		await process_frame
	print("draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"  objects: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"  primitives: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"  nodes: ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	quit()
