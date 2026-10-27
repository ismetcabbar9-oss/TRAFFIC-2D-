extends SceneTree
## Dev helper: renders the main scene for a few frames and saves a screenshot.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution WxH --script res://tools/capture.gd -- <out.png> [frames]
## forward_plus is used because the Mobile renderer with shadows renders dark on
## the software Vulkan driver (lavapipe) in cloud sessions; real GPUs are fine.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://capture.png"
	var frames := int(args[1]) if args.size() > 1 else 30
	var scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene"))
	root.add_child(scene.instantiate())
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
