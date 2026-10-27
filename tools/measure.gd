extends SceneTree
# Prints the combined mesh AABB of every vehicle/prop model (dev helper).
func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var t: Transform3D = xf * ((n as Node3D).transform if n is Node3D else Transform3D())
	if n is MeshInstance3D:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_aabb(c, t, acc)

func _init() -> void:
	for d in ["res://assets/models/hq/vehicles/", "res://assets/models/props/", "res://assets/models/hq/props/", "res://assets/models/hq/trees/"]:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".glb"):
				var n: Node = load(d + f).instantiate()
				var acc := [null]
				_aabb(n, Transform3D(), acc)
				print(f, " ", acc[0], " children: ", n.get_children().map(func(c): return c.name))
	quit()
