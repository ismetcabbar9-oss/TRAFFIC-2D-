extends SceneTree
## Dev tool: generates the levels of every world (20 each) into the folders
## listed in data/worlds.json, using LevelGenerator.
## Usage: godot --headless --path . --script res://tools/generate_levels.gd [-- <world number>]


func _initialize() -> void:
	var only := -1
	if OS.get_cmdline_user_args().size() > 0:
		only = int(OS.get_cmdline_user_args()[0]) - 1
	for w in LevelCatalog.world_count():
		if only >= 0 and w != only:
			continue
		var info := LevelCatalog.world(w)
		DirAccess.make_dir_recursive_absolute(info.levels)
		for i in LevelGenerator.LEVELS_PER_WORLD:
			_generate(w, i, info)
	quit()


func _generate(w: int, i: int, info: Dictionary) -> void:
	var result := LevelGenerator.generate(LevelGenerator.spec(w, i, info.mechanic), [w, i])
	if result.is_empty():
		push_error("world %d level %d: no solvable layout" % [w + 1, i + 1])
		return
	var best: Dictionary = result.data
	var hard := i in LevelGenerator.HARD
	best["name"] = "Level %d" % (i + 1)
	if hard:
		best["hard"] = true
	var path: String = info.levels.path_join("level_%02d.json" % (i + 1))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(best, " ", false) + "\n")
	print("%s: %s%s" % [path, result.note, "  [hard]" if hard else ""])
