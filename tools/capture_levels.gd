extends SceneTree
## Dev helper: saves a screenshot of every level's starting layout (or of one).
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/capture_levels.gd -- <out_dir> [level_number]

func _initialize() -> void:
	var out_dir := OS.get_cmdline_user_args()[0]
	await process_frame # let autoloads load the save file first
	var levels := range(LevelCatalog.count())
	if OS.get_cmdline_user_args().size() > 1:
		levels = [int(OS.get_cmdline_user_args()[1]) - 1]
	for i in levels:
		root.get_node("Progress").current_level = i
		var game: Node = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		for f in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("level_%02d.png" % (i + 1)))
		game.queue_free()
		await process_frame
	print("saved %d levels" % levels.size())
	quit()
