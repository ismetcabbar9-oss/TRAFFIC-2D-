extends "res://tools/extract_models.gd"
## Dev tool: extracts the themed scenery of worlds 2-5 from their Sketchfab
## downloads into res://assets/models/hq/worlds/, using the same processing as
## extract_models.gd (grounded, merged per material, small textures) and
## scaled to a real-world size.
##
## Usage (under xvfb-run, not --headless, or textures are lost):
##   godot --path . --script res://tools/extract_world_models.gd -- <packs_dir>
## <packs_dir> holds B2, B3, B6, B7, B8, S1, S4, S5, A2, A3, A5, A8 .glb files.

const WORLD_OUT := "res://assets/models/hq/worlds/"

## out name -> [pack, node name ("" = whole scene), size kind, meters]
## size kind: "h" scales to that height, "max" to that longest side.
const MODELS := {
	"palm_tall": ["B2", "PalmTreeSet_LP_011", "h", 5.2],
	"palm_bent": ["B2", "PalmTreeSet_LP_026", "h", 4.6],
	"coconut_palm": ["B3", "coconut_tree", "h", 4.2],
	"umbrella": ["B6", "", "h", 2.3],
	"lifeguard_chair": ["B7", "", "h", 2.8],
	"deckchair": ["B8", "", "max", 2.0],
	"snow_tree_1": ["S1", "Tree 1", "h", 4.4],
	"snow_tree_2": ["S1", "Tree 2", "h", 4.0],
	"snow_tree_3": ["S1", "Tree 3", "h", 3.8],
	"snow_tree_4": ["S1", "Tree 4", "h", 4.2],
	"snow_tree_5": ["S1", "Tree 5", "h", 4.6],
	"snow_tree_6": ["S1", "Tree 6", "h", 4.0],
	"snowman": ["S4", "", "h", 1.6],
	"snow_hut": ["S5", "hut_39", "max", 6.0],
	"hangar": ["A2", "04_Hangar", "max", 16.0],
	"control_tower": ["A3", "02_ControlTower", "h", 13.0],
	"plane": ["A5", "Plane", "max", 9.0],
	"baggage_truck": ["A8", "21_1_BaggageTruck", "max", 3.0],
	"baggage_cart": ["A8", "21_2_BaggageTruck", "max", 2.8],
}


func _initialize() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_OUT))
	var packs := {}
	for out_name in MODELS:
		var spec: Array = MODELS[out_name]
		if not packs.has(spec[0]):
			var state := GLTFState.new()
			var doc := GLTFDocument.new()
			if doc.append_from_file(dir.path_join(spec[0] + ".glb"), state) != OK:
				push_error("cannot read %s" % spec[0])
				continue
			packs[spec[0]] = doc.generate_scene(state)
		var pack: Node = packs[spec[0]]
		var node: Node3D = pack.get_child(0) if spec[1] == "" else _find(pack, spec[1])
		var copy := _copy_global(node)
		# Drop helper geometry some packs carry (colliders, sky rigs).
		for helper in copy.find_children("*", "Node3D", true, false):
			if helper.name.contains("Collider") or helper.name.contains("Physical_Sky"):
				helper.get_parent().remove_child(helper)
				helper.free()
		var root := _grounded(copy)
		_scale_to(root, spec[2], spec[3])
		_save(root, WORLD_OUT + out_name + ".glb")
	quit()


static func _scale_to(root: Node3D, kind: String, meters: float) -> void:
	var size := _subtree_aabb(root, Transform3D()).size
	var current := size.y if kind == "h" else maxf(size.x, maxf(size.y, size.z))
	if current <= 0.0:
		return
	var k := meters / current
	for child in root.get_children():
		(child as Node3D).transform = Transform3D(Basis().scaled(Vector3.ONE * k), Vector3.ZERO) * (child as Node3D).transform
