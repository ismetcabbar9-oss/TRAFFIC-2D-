extends SceneTree
## Dev helper: lays out every .glb of a folder on a grid with labels and saves a
## screenshot. Usage (under xvfb-run): godot --path . --rendering-method forward_plus \
##   --resolution 1600x1100 --script res://tools/model_gallery.gd -- <res_dir> <out.png> <columns> <spacing>
func _initialize():
	await process_frame
	var dir: String = OS.get_cmdline_user_args()[0]
	var out: String = OS.get_cmdline_user_args()[1]
	var cols := int(OS.get_cmdline_user_args()[2])
	var spacing := float(OS.get_cmdline_user_args()[3])
	var g: Node3D = load("res://scenes/game.tscn").instantiate()
	root.add_child(g)
	for i in 3: await process_frame
	for n in ["Board", "Scenery", "Vehicles", "Hud"]: g.get_node(n).queue_free()
	var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".glb"))
	files.sort()
	var holder := Node3D.new(); g.add_child(holder)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("5a6170"); ground.material_override = gm; holder.add_child(ground)
	var rows := ceili(files.size() / float(cols))
	for i in files.size():
		var m: Node3D = load(dir.path_join(files[i])).instantiate()
		var x := (i % cols - (cols - 1) * 0.5) * spacing
		var z := (i / cols - (rows - 1) * 0.5) * spacing
		m.position = Vector3(x, 0, z)
		holder.add_child(m)
		var l := Label3D.new(); l.text = files[i].get_basename(); l.font_size = 64; l.pixel_size = spacing * 0.0012
		l.rotation_degrees.x = -90; l.position = Vector3(x, 0.05, z + spacing * 0.42); l.modulate = Color.WHITE
		holder.add_child(l)
	var cam: Camera3D = g.get_node("Camera")
	cam.frame_board(Vector2(cols, rows) * spacing * 0.5)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
