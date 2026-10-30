extends SceneTree
## Dev helper: the level 1 gesture guide (pinch to zoom, drag to pan) from a
## fresh save (it RESETS the local progress), then the tap hand after "Got it".
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 720x1280 --script res://tools/zoom_guide_demo.gd -- <out_dir> [locale]

var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	await process_frame
	if args.size() > 1:
		TranslationServer.set_locale(args[1])
	root.get_node("Progress").reset_progress()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	var start := Time.get_ticks_msec()
	for at in [2.0, 3.1, 4.6, 6.4]:
		while Time.get_ticks_msec() - start < at * 1000.0:
			await process_frame
		await _shot("z_%.1f" % at)
	current_scene.hud.zoom_guide.closed.emit()
	await create_timer(2.5).timeout
	await _shot("z_after")
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
