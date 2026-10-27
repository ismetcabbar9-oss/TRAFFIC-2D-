extends SceneTree
## Dev tool: splits downloaded Sketchfab packs into one .glb per model, ready
## for the game. Vehicles are turned to face +Z (using their wheel positions),
## every model is set on the ground (min y = 0), merged into a single mesh with
## one surface per material (few draw calls), and textures are shrunk.
##
## Usage: godot --headless --path . --script res://tools/extract_models.gd -- <packs_dir>
## <packs_dir> holds A10.glb, A8.glb, C4.glb, C6.glb, C12.glb (Sketchfab downloads).

const OUT := "res://assets/models/hq/"
const MAX_TEXTURE := 256
## A8 paints some bodies near-black; lift them so cars read on the dark lot.
const RECOLOR := {
	"body_dark_purple": Color("2a9d8f"),
	"body_dark_green": Color("43a352"),
	"body_dark_blue": Color("ece6d8"),
}

## type -> [pack, body node, wheel name style]
const VEHICLES := {
	"sedan": ["A10", "SHTV_Model_Car_Sedan", "shtv"],
	"hatchback": ["A10", "SHTV_Model_Car_Hatchback", "shtv"],
	"police": ["A10", "SHTV_Model_Car_Police", "shtv"],
	"ambulance": ["A10", "SHTV_Model_Car_Ambulance", "shtv"],
	"taxi": ["A8", "Taxi", "words"],
	"sedan_sports": ["A8", "Sports", "words"],
	"suv": ["A8", "SUV", "words"],
	"suv_luxury": ["A8", "Muscle", "words"],
	"van": ["A8", "Van", "words"],
	"pickup": ["A8", "Pickup", "words"],
	"delivery": ["A8", "Truck", "words"],
	"firetruck": ["A8", "Firetruck", "words"],
	"bus": ["A8", "Bus", "words"],
}

## out name -> [pack, node name prefix]
const PROPS := {
	"bench": ["C6", "ParkBenchLong"],
	"bench_short": ["C6", "ParkBenchShort"],
	"trash_can": ["C6", "TrashCanLarge"],
	"hydrant": ["C6", "FireHydrant"],
	"post_box": ["C6", "PostBox"],
	"bus_stop": ["C6", "BusStop"],
	"street_light": ["C6", "Light"],
	"parking_meter": ["C6", "ParkingMeter"],
	"bollard": ["C6", "PostBarrier"],
	"bakery": ["C12", "bakery_27"],
	"blue_house": ["C12", "blue_house_28"],
	"cinema": ["C12", "cinema_29"],
	"coffee_shop": ["C12", "coffe_shop_30"],
	"fire_station": ["C12", "fire_station_31"],
	"green_house": ["C12", "green_house_35"],
	"hotel": ["C12", "hotel_36"],
	"market": ["C12", "market_37"],
	"pizzeria": ["C12", "pizzeria_38"],
	"police_station": ["C12", "police_station_39"],
	"yellow_house": ["C12", "yellow_house_40"],
	"hospital": ["C12", "hospital_41"],
	"c12_tree_1": ["C12", "tree_1_19"],
	"c12_tree_2": ["C12", "tree_2_20"],
	"c12_tree_3": ["C12", "tree_3_21"],
	"c12_bush": ["C12", "bush_3"],
	"lantern": ["C12", "lantern_10"],
	"traffic_light": ["C12", "light_green_25"],
}

var _packs := {}


func _initialize() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	for pack in ["A10", "A8", "C4", "C6", "C12"]:
		var state := GLTFState.new()
		var doc := GLTFDocument.new()
		var err := doc.append_from_file(dir.path_join(pack + ".glb"), state)
		if err != OK:
			push_error("cannot read %s: %s" % [pack, err])
			quit(1)
			return
		_packs[pack] = doc.generate_scene(state)
	for d in ["vehicles", "props", "trees"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + d))

	for type in VEHICLES:
		var spec: Array = VEHICLES[type]
		_save(_build_vehicle(_packs[spec[0]], spec[1], spec[2]), OUT + "vehicles/%s.glb" % type)
	for out_name in PROPS:
		var spec: Array = PROPS[out_name]
		var node := _find(_packs[spec[0]], spec[1])
		_save(_grounded(_copy_global(node)), OUT + "props/%s.glb" % out_name)
	_extract_trees()
	quit()


## C4 holds dozens of trees named "Tree N_M"; keep the green, leafy ones.
func _extract_trees() -> void:
	var count := 0
	for node in _packs["C4"].find_children("Tree*", "Node3D", true, false):
		if node.get_child_count() < 2:
			continue
		var aabb := _subtree_aabb(node, Transform3D())
		if aabb.size.y < 0.1:
			continue
		count += 1
		_save(_grounded(_copy_global(node)), OUT + "trees/tree_%02d.glb" % count)
	print("trees: ", count)


func _build_vehicle(pack: Node, body_name: String, style: String) -> Node3D:
	var body := _find(pack, body_name)
	var root := Node3D.new()
	root.name = body_name
	var body_copy := _copy_global(body)
	body_copy.name = "body"
	root.add_child(body_copy)

	var front := Vector3.ZERO
	var back := Vector3.ZERO
	var fronts := 0
	var backs := 0
	for node in pack.find_children("*", "Node3D", true, false):
		var wheel_name := _wheel_name(node.name, body_name, style)
		if wheel_name == "":
			continue
		var copy := _copy_global(node)
		var center := _subtree_aabb(copy, Transform3D()).get_center()
		var pivot := Node3D.new()
		pivot.name = wheel_name
		pivot.position = center
		copy.transform = Transform3D(Basis(), -center) * copy.transform
		pivot.add_child(copy)
		root.add_child(pivot)
		if wheel_name.begins_with("wheel-front"):
			front += center
			fronts += 1
		else:
			back += center
			backs += 1
	if fronts == 0 or backs == 0:
		push_error("%s: wheels not found" % body_name)
		return root

	# Turn the vehicle so it drives toward +Z.
	var heading := front / fronts - back / backs
	var yaw := atan2(heading.x, heading.z)
	for child in root.get_children():
		(child as Node3D).transform = Transform3D(Basis(Vector3.UP, -yaw), Vector3.ZERO) * (child as Node3D).transform
	return _ground_children(root)


## Maps pack wheel node names to wheel-front-left / wheel-back-right(-2...).
static func _wheel_name(node_name: String, body_name: String, style: String) -> String:
	var n := node_name
	if style == "shtv":
		var key := body_name.replace("SHTV_Model_Car_", "SHTV_Model_Wheel_") + "_"
		if not n.begins_with(key) or n.contains("Material"):
			return ""
		var code := n.substr(key.length(), 2)
		var map := {"FL": "front-left", "FR": "front-right", "BL": "back-left", "BR": "back-right"}
		return "wheel-" + map[code] if map.has(code) else ""
	if not n.begins_with(body_name + " wheel "):
		return ""
	var rest := n.substr((body_name + " wheel ").length())
	var parts := rest.split(" ")
	if parts.size() < 2:
		return ""
	var pos := "front" if parts[0] == "front" else "back"
	var suffix := "-" + parts[2] if parts.size() > 2 else ""
	return "wheel-%s-%s%s" % [pos, parts[1], suffix]


static func _find(root: Node, prefix: String) -> Node3D:
	for node in root.find_children("*", "Node3D", true, false):
		if node.name == prefix:
			return node
	for node in root.find_children(prefix + "*", "Node3D", true, false):
		return node
	push_error("node %s not found" % prefix)
	return null


## Deep copy of `node` whose own transform is its global transform in the pack.
static func _copy_global(node: Node3D) -> Node3D:
	var xf := Transform3D()
	var n: Node = node
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var copy: Node3D = node.duplicate()
	copy.transform = xf
	return copy


## Moves the children of `root` so the model's lowest point sits at y = 0 and
## it is centered in XZ. Children stay direct children (wheels must).
static func _ground_children(root: Node3D) -> Node3D:
	var aabb := _subtree_aabb(root, Transform3D())
	var offset := Vector3(-aabb.get_center().x, -aabb.position.y, -aabb.get_center().z)
	for child in root.get_children():
		(child as Node3D).transform = Transform3D(Basis(), offset) * (child as Node3D).transform
	return root


## Wraps a single copied node in a fresh root and grounds it.
static func _grounded(content: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = content.name
	root.add_child(content)
	return _ground_children(root)


static func _subtree_aabb(node: Node, xf: Transform3D) -> AABB:
	var t: Transform3D = xf * ((node as Node3D).transform if node is Node3D else Transform3D())
	var result := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = t * (node as MeshInstance3D).get_aabb()
		has = true
	for child in node.get_children():
		var a := _subtree_aabb(child, t)
		if a.size != Vector3.ZERO:
			result = a if not has else result.merge(a)
			has = true
	return result


func _save(root: Node3D, path: String) -> void:
	_shrink_textures(root)
	root = _flatten(root)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(root, state)
	var err := doc.write_to_filesystem(state, ProjectSettings.globalize_path(path))
	print("%s %s (%s)" % ["saved" if err == OK else "FAILED", path, _subtree_aabb(root, Transform3D()).size])


## Merges every mesh under `root` into one MeshInstance3D, one surface per
## material, so each model costs as few draw calls as possible.
static func _flatten(root: Node3D) -> Node3D:
	var parts: Array = []
	_collect(root, Transform3D(), parts)
	var tools := {} ## Material -> SurfaceTool
	for part in parts:
		var mesh: Mesh = part[0]
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if not tools.has(mat):
				var st := SurfaceTool.new()
				tools[mat] = st
			(tools[mat] as SurfaceTool).append_from(mesh, s, part[1])
	var merged := ArrayMesh.new()
	for mat in tools:
		var st: SurfaceTool = tools[mat]
		st.commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, mat)
	var out := Node3D.new()
	out.name = root.name
	var mi := MeshInstance3D.new()
	mi.name = "body"
	mi.mesh = merged
	out.add_child(mi)
	return out


static func _collect(node: Node, xf: Transform3D, out: Array) -> void:
	var t: Transform3D = xf * ((node as Node3D).transform if node is Node3D else Transform3D())
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out.append([(node as MeshInstance3D).mesh, t])
	for child in node.get_children():
		_collect(child, t, out)


## Keeps only the base color texture, shrunk to MAX_TEXTURE: plenty for
## stylized props seen from above, and light on phones.
static func _shrink_textures(root: Node) -> void:
	var done := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null or done.has(mat):
				continue
			done[mat] = true
			if RECOLOR.has(mat.resource_name):
				mat.albedo_color = RECOLOR[mat.resource_name]
			mat.normal_enabled = false
			mat.normal_texture = null
			mat.roughness_texture = null
			mat.metallic_texture = null
			mat.ao_enabled = false
			mat.emission_texture = null
			mat.emission_enabled = false # A10 ships a full-white emissive map
			var tex := mat.albedo_texture
			if tex == null:
				continue
			var img := tex.get_image()
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			var longest := maxi(img.get_width(), img.get_height())
			if longest > MAX_TEXTURE:
				var k := float(MAX_TEXTURE) / longest
				img.resize(maxi(int(img.get_width() * k), 1), maxi(int(img.get_height() * k), 1), Image.INTERPOLATE_LANCZOS)
			mat.albedo_texture = ImageTexture.create_from_image(img)
