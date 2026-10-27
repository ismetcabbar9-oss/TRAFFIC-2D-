extends SceneTree
## Dev tool: generates the levels of every world (40 each) into the folders
## listed in data/worlds.json, using LevelGenerator. Existing level files are
## kept (players' stars stay with the levels they earned them on) unless
## --force is given.
## Usage: godot --headless --path . --script res://tools/generate_levels.gd [-- <world number>] [--force]


func _initialize() -> void:
	var only := -1
	var force := false
	for arg in OS.get_cmdline_user_args():
		if arg == "--force":
			force = true
		else:
			only = int(arg) - 1
	for w in LevelCatalog.world_count():
		if only >= 0 and w != only:
			continue
		var info := LevelCatalog.world(w)
		DirAccess.make_dir_recursive_absolute(info.levels)
		for i in LevelGenerator.LEVELS_PER_WORLD:
			var path: String = info.levels.path_join("level_%02d.json" % (i + 1))
			if force or not FileAccess.file_exists(path):
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
