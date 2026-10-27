extends SceneTree
## Dev helper: saves a screenshot of every level's starting layout.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/capture_levels.gd -- <out_dir>

func _initialize() -> void:
	var out_dir := OS.get_cmdline_user_args()[0]
	for i in LevelCatalog.count():
		root.get_node("Progress").current_level = i
		var game: Node = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		for f in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join("level_%02d.png" % (i + 1)))
		game.queue_free()
		await process_frame
	print("saved %d levels" % LevelCatalog.count())
	quit()
