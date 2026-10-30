extends SceneTree
## Dev helper: every garage paint job on the civilian cars, one row per paint.
## Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 1400x1800 --script res://tools/paint_preview.gd -- <out.png>

const TYPES := ["sedan", "hatchback", "sedan_sports", "suv", "suv_luxury", "van", "pickup", "delivery", "bus"]


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
	env.environment.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.environment.ambient_light_energy = 0.7
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5a6170")
	ground.material_override = gm
	world.add_child(ground)
	var paints: Array = Cosmetics.items("paint")
	for row in paints.size():
		for col in TYPES.size():
			var m: Node3D = VehicleCatalog.load_model(TYPES[col]).instantiate()
			FleetPaint.apply(m, TYPES[col], col, paints[row])
			var aabb := VehicleView._model_aabb(m, Transform3D())
			m.scale = Vector3.ONE * 2.0 / aabb.size.x
			m.position = Vector3((col - 4) * 3.0, 0, (row - paints.size() * 0.5) * 4.2)
			world.add_child(m)
		var label := Label3D.new()
		label.text = tr("COS_" + str(paints[row].id).to_upper())
		label.font_size = 96
		label.pixel_size = 0.012
		label.rotation_degrees.x = -90
		label.position = Vector3(-17.5, 0.1, (row - paints.size() * 0.5) * 4.2)
		world.add_child(label)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50
	cam.look_at_from_position(Vector3(-2, 42, 14), Vector3(-2, 0, -1.5))
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
