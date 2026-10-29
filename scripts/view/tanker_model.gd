class_name TankerModel
## Fuel tanker: the delivery truck's tractor (repainted red) pulling a chrome
## tank trailer with a red band and orange hazard diamonds, built from
## primitive meshes. Faces +Z like the imported models; the trailer is
## baked into one mesh with a surface per color. Packed once and reused.

const CAB := "res://assets/models/hq/vehicles/delivery.glb"

static var _scene: PackedScene


static func packed() -> PackedScene:
	if _scene == null:
		var root := _build()
		_scene = PackedScene.new()
		_scene.pack(root)
		root.free()
	return _scene


static func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "Tanker"
	var cab: Node3D = (load(CAB) as PackedScene).instantiate()
	cab.name = "Cab"
	root.add_child(cab)
	var body := cab.get_node("body") as MeshInstance3D
	var paint := (body.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	paint.albedo_color = Color("d8352a")
	body.set_surface_override_material(0, paint)

	var trailer := Node3D.new()
	trailer.name = "Trailer"
	root.add_child(trailer)
	var red := _mat(Color("d8352a"), 0.45)
	var dark := _mat(Color("2b2f38"), 0.8)
	var steel := _mat(Color("dfe4ea"), 0.25, 0.6)
	var orange := _mat(Color("ff8a1f"), 0.5)

	const Y := 2.3 # tank axis height
	const R := 1.3
	_box(trailer, dark, Vector3(1.6, 0.35, 4.0), Vector3(0, 0.95, -4.3)) # trailer frame
	var tank := _cyl(trailer, steel, R, 6.2, Vector3(0, Y, -2.55))
	tank.rotation.x = PI * 0.5
	for z in [-5.68, 0.58]:
		var cap := _cyl(trailer, dark, R * 0.92, 0.14, Vector3(0, Y, z))
		cap.rotation.x = PI * 0.5
	for z in [-4.3, -0.8]:
		var band := _cyl(trailer, red, R + 0.04, 0.4, Vector3(0, Y, z))
		band.rotation.x = PI * 0.5
	_box(trailer, dark, Vector3(0.6, 0.14, 0.6), Vector3(0, Y + R + 0.02, -2.55)) # hatch
	for s in [-1.0, 1.0]:
		var diamond := _box(trailer, orange, Vector3(0.06, 0.75, 0.75), Vector3(s * (R + 0.02), Y, -2.55))
		diamond.rotation.x = PI * 0.25
	var back := _box(trailer, orange, Vector3(0.75, 0.75, 0.06), Vector3(0, Y, -5.78))
	back.rotation.z = PI * 0.25

	var tyre := _mat(Color("1d1f24"), 0.9)
	var hub := _mat(Color("cfd4de"), 0.4, 0.5)
	for z in [-4.0, -5.0]:
		for side in [-1.0, 1.0]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side * 1.1, 0.42, z)
			trailer.add_child(wheel)
			var t := _cyl(wheel, tyre, 0.42, 0.5, Vector3.ZERO)
			t.rotation.z = PI * 0.5
			var h := _cyl(wheel, hub, 0.2, 0.52, Vector3.ZERO)
			h.rotation.z = PI * 0.5
	# One mesh for the whole trailer: a handful of draw calls, not thirty.
	MeshMerge.merge(trailer)
	_own(root, root)
	return root


static func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)


static func _box(parent: Node3D, mat: Material, size: Vector3, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _cyl(parent: Node3D, mat: Material, radius: float, height: float, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	parent.add_child(m)
	return m


static func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m
