extends SceneTree
## Dev tool: adds the planned hazards (HazardPlacer.plan) to the existing level
## files, keeping their layouts. Levels that already have hazards are skipped.
## Usage: godot --headless --path . --script res://tools/add_hazards.gd [-- <world number>]


func _initialize() -> void:
	var only := int(OS.get_cmdline_user_args()[0]) - 1 if OS.get_cmdline_user_args().size() > 0 else -1
	for w in LevelCatalog.world_count():
		if only >= 0 and w != only:
			continue
		for i in LevelCatalog.level_count(w):
			var plan := HazardPlacer.plan(w, i)
			if plan.tanker == 0 and plan.pits == 0 and not plan.bomb:
				continue
			var path := LevelCatalog.path(w, i)
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var have := HazardPlacer.count(data)
			if have.tanker + have.pits + have.bomb > 0:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([w, i, "hazards"])
			var out := HazardPlacer.add(data, plan, i in LevelGenerator.HARD, rng)
			var report := LevelSolver.solve(LevelData.from_dict(out))
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(out, " ", false) + "\n")
			print("%s: planned %s, placed %s, waves %d, falls %d" % [path, plan, HazardPlacer.count(out), report.rounds, report.falls])
	quit()
