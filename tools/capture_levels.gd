extends SceneTree
## Dev helper: saves a screenshot of every level's starting layout (or of one).
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/capture_levels.gd -- <out_dir> [world_number] [level_number]

func _initialize() -> void:
	var out_dir := OS.get_cmdline_user_args()[0]
	await process_frame # let autoloads load the save file first
	var args := OS.get_cmdline_user_args()
	var world := int(args[1]) - 1 if args.size() > 1 else 0
	var levels := range(LevelCatalog.level_count(world))
	if args.size() > 2:
		levels = [int(args[2]) - 1]
	var progress := root.get_node("Progress")
	progress.current_world = world
	progress.tutorial_seen = true
	progress.tips_seen = ["CARGO", "TURN", "LOCK", "GATE"]
	for i in levels:
		progress.current_level = i
		var game: Node = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		await create_timer(1.3).timeout # level intro: camera glide and cars popping in
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("w%d_level_%02d.png" % [world + 1, i + 1]))
		game.queue_free()
		await process_frame
	print("saved %d levels" % levels.size())
	quit()
