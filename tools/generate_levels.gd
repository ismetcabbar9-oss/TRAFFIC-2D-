extends SceneTree
## Dev tool: generates res://levels/level_XX.json from the specs below.
## Usage: godot --headless --path . --script res://tools/generate_levels.gd
##
## Each level is built by dropping random vehicles on an empty board, keeping a
## vehicle only if the board stays clearable. Many seeded attempts are scored
## by how close the solver depth (waves needed) is to the target and how few
## cars are free at the start; the best one is written. Same specs + seeds
## always give the same levels.

const SPECS := [
	# board size, vehicle count, cones, share of 3-cell trucks, allowed wrong
	# moves, target solver depth (waves of moves needed)
	{"cols": 4, "rows": 4, "cars": 4, "cones": 0, "trucks": 0.0, "mistakes": 3, "depth": 2},
	{"cols": 5, "rows": 5, "cars": 7, "cones": 0, "trucks": 0.1, "mistakes": 3, "depth": 3},
	{"cols": 5, "rows": 6, "cars": 9, "cones": 0, "trucks": 0.15, "mistakes": 3, "depth": 4},
	{"cols": 6, "rows": 6, "cars": 12, "cones": 0, "trucks": 0.15, "mistakes": 3, "depth": 5},
	{"cols": 6, "rows": 6, "cars": 13, "cones": 1, "trucks": 0.2, "mistakes": 3, "depth": 6},
	{"cols": 6, "rows": 7, "cars": 15, "cones": 1, "trucks": 0.2, "mistakes": 3, "depth": 7},
	{"cols": 6, "rows": 7, "cars": 17, "cones": 1, "trucks": 0.2, "mistakes": 3, "depth": 8},
	{"cols": 7, "rows": 7, "cars": 19, "cones": 2, "trucks": 0.2, "mistakes": 3, "depth": 9},
	{"cols": 7, "rows": 8, "cars": 22, "cones": 2, "trucks": 0.25, "mistakes": 3, "depth": 10},
	{"cols": 7, "rows": 8, "cars": 24, "cones": 2, "trucks": 0.25, "mistakes": 3, "depth": 11},
]
const ATTEMPTS := 400
const SMALL := ["sedan", "sedan_sports", "hatchback", "suv", "suv_luxury", "taxi", "police", "van", "pickup"]
const LARGE := ["ambulance", "delivery", "firetruck", "bus"]


func _initialize() -> void:
	for i in SPECS.size():
		var spec: Dictionary = SPECS[i]
		var best: Dictionary = {}
		var best_score := -INF
		for attempt in ATTEMPTS:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([i, attempt])
			var data: Dictionary = _build(spec, rng)
			var report := LevelSolver.solve(LevelData.from_dict(data))
			if not report.solvable or data.vehicles.size() < spec.cars:
				continue
			var score: float = -absf(report.rounds - spec.depth) * 10.0 - report.first_free * 2.0
			if report.rounds >= spec.depth:
				score += 5.0 # prefer reaching the target over falling short
			if score > best_score:
				best_score = score
				best = data
				best["_report"] = "%d cars, %d waves, %d free at start" % [data.vehicles.size(), report.rounds, report.first_free]
		var report_text: String = best["_report"]
		best.erase("_report")
		best["name"] = "Level %d" % (i + 1)
		var path := "res://levels/world_1/level_%02d.json" % (i + 1)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(best, " ", false) + "\n")
		print("%s: %s" % [path, report_text])
	quit()


func _build(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var data := {"cols": spec.cols, "rows": spec.rows, "mistakes": spec.mistakes, "vehicles": [], "obstacles": []}
	var occupied := {}
	# Cones first, away from the border so they block inner lanes.
	var tries := 0
	while data.obstacles.size() < spec.cones and tries < 50:
		tries += 1
		var c := Vector2i(rng.randi_range(1, spec.cols - 2), rng.randi_range(1, spec.rows - 2))
		if not occupied.has(c):
			occupied[c] = true
			data.obstacles.append({"type": "cone", "col": c.x, "row": c.y})

	tries = 0
	while data.vehicles.size() < spec.cars and tries < 400:
		tries += 1
		var large: bool = rng.randf() < spec.trucks
		var type: String = (LARGE if large else SMALL)[rng.randi() % (LARGE.size() if large else SMALL.size())]
		var dir := rng.randi_range(0, 3)
		var length := VehicleCatalog.cells(type)
		var horizontal := GridDir.is_horizontal(dir)
		var max_col: int = spec.cols - (length if horizontal else 1)
		var max_row: int = spec.rows - (1 if horizontal else length)
		if max_col < 0 or max_row < 0:
			continue
		var cell := Vector2i(rng.randi_range(0, max_col), rng.randi_range(0, max_row))
		var cells: Array[Vector2i] = []
		for k in length:
			cells.append(cell + (Vector2i(k, 0) if horizontal else Vector2i(0, k)))
		if cells.any(func(c): return occupied.has(c)):
			continue
		var entry := {"type": type, "col": cell.x, "row": cell.y, "dir": GridDir.to_name(dir)}
		data.vehicles.append(entry)
		if not LevelSolver.solve(LevelData.from_dict(data)).solvable:
			data.vehicles.pop_back()
			continue
		for c in cells:
			occupied[c] = true
	return data
