extends SceneTree
## Dev tool: renders the app icon (taxi bursting out of a parking spot) with
## the game's own models. Run under xvfb-run with --resolution 1024x1024:
##   godot --path . --rendering-method forward_plus --resolution 1024x1024 \
##     --script res://tools/render_icon.gd -- res://assets/icon.png

func _initialize() -> void:
	await process_frame
	var out := OS.get_cmdline_user_args()[0]
	var scene := Node3D.new()
	root.add_child(scene)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6cc4ea")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.9, 1)
	env.environment.ambient_light_energy = 0.55
	scene.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
	scene.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("8b93a5")
	ground.material_override = gm
	scene.add_child(ground)
	for x in [-2.0, 2.0]:
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12, 0.01, 12)
		line.mesh = box
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(1, 1, 1, 0.7)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line.material_override = lm
		line.position = Vector3(x, 0.01, 0)
		scene.add_child(line)

	var car: Node3D = VehicleCatalog.load_model("taxi").instantiate()
	car.scale = Vector3.ONE * 1.25 # Kenney cars face +Z, toward the camera
	scene.add_child(car)
	var arrow: Node3D = load("res://scenes/direction_arrow.tscn").instantiate()
	arrow.scale = Vector3.ONE * 1.3
	arrow.position = Vector3(0, 1.95, 0.1)
	scene.add_child(arrow)
	var fx := Node3D.new()
	scene.add_child(fx)
	Effects.exhaust_puff(fx, Vector3(0, 0.5, -2.0), Vector3(0, 0, -1))
	Effects.backfire(fx, Vector3(0, 0.45, -1.9))

	var cam := Camera3D.new()
	cam.fov = 40
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(3.4, 5.2, 5.4), Vector3(0, 0.6, -0.5))

	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	print("saved ", out)
	quit()
