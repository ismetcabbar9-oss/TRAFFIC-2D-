extends SceneTree
## Dev helper: the fuel tanker next to a delivery truck and a sedan, seen from
## the side and from the game camera's angle.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 1280x720 --script res://tools/tanker_preview.gd -- <out.png>


func _initialize() -> void:
	await process_frame
	var out: String = OS.get_cmdline_user_args()[0]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bfe3f2")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5a6170")
	ground.material_override = gm
	world.add_child(ground)
	var x := -7.0
	for type in ["sedan", "delivery", "tanker"]:
		var m: Node3D = VehicleCatalog.load_model(type).instantiate()
		var aabb := VehicleView._model_aabb(m, Transform3D())
		var s := 2.4 / aabb.size.x
		m.scale = Vector3.ONE * s
		m.position = Vector3(x, 0, 0)
		m.rotation.y = PI * 0.5
		world.add_child(m)
		x += 6.5
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 45
	cam.look_at_from_position(Vector3(4, 7, 13), Vector3(0, 1, 0))
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
