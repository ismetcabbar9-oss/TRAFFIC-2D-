class_name MeshMerge
## Bakes the primitive meshes under a node into one MeshInstance3D with one
## surface per material, so a prop built from many boxes and cylinders costs
## a few draw calls instead of dozens.


## Replaces every MeshInstance3D below `root` (not root's other children) with
## a single merged one added to `root`. Shadows follow `cast_shadow`.
static func merge(root: Node3D, cast_shadow := true) -> MeshInstance3D:
	var by_material := {} # Material -> SurfaceTool
	var parts: Array = root.find_children("*", "MeshInstance3D", true, false)
	for part in parts:
		var mi := part as MeshInstance3D
		var xf := _relative(root, mi)
		var mat: Material = mi.material_override
		for s in mi.mesh.get_surface_count():
			var surface_mat: Material = mat if mat else mi.mesh.surface_get_material(s)
			if not by_material.has(surface_mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_material[surface_mat] = st
			(by_material[surface_mat] as SurfaceTool).append_from(mi.mesh, s, xf)
		mi.get_parent().remove_child(mi)
		mi.free()
	var mesh := ArrayMesh.new()
	for mat in by_material:
		var st: SurfaceTool = by_material[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var out := MeshInstance3D.new()
	out.name = "Merged"
	out.mesh = mesh
	if not cast_shadow:
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(out)
	return out


static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D()
	var n: Node = node
	while n != root and n != null:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
