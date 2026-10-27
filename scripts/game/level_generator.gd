class_name LevelGenerator
extends RefCounted
## Builds levels: difficulty spec from world and level number, then many seeded
## attempts of dropping random vehicles on the board (keeping one only if the
## board stays clearable), scored by solver depth, how few cars are free at the
## start and how much the mechanic matters. Used by tools/generate_levels.gd
## for the worlds and at runtime for the daily puzzle.
##
## Difficulty follows a sawtooth inside each world: it climbs level by level,
## levels 5 and 15 are easy "breathers", levels 10 and 20 are marked hard.
## Each world adds its mechanic (cargo, turn, lock, gate); the first two
## levels of a world introduce it on a small board, and later worlds mix in
## the previous mechanic now and then. Same code + seeds give the same levels.

const LEVELS_PER_WORLD := 20
const ATTEMPTS := 90
const BREATHERS := [4, 14]
const HARD := [9, 19]
const SMALL := ["sedan", "sedan_sports", "hatchback", "suv", "suv_luxury", "taxi", "police", "van", "pickup"]
const LARGE := ["ambulance", "delivery", "firetruck", "bus"]
const CARGO_TYPES := ["pickup", "van", "delivery"]

## Per world: starting difficulty and an earlier mechanic mixed in later on.
const WORLD_TUNING := [
	{"base": 0.0, "extra": ""},
	{"base": 0.1, "extra": ""},
	{"base": 0.18, "extra": "cargo"},
	{"base": 0.26, "extra": "turn"},
	{"base": 0.34, "extra": "lock"},
]


## Best of `attempts` seeded layouts for `level_spec`, or {} if none worked.
## Returns {"data": level dictionary, "note": summary for logs}.
static func generate(level_spec: Dictionary, seed_parts: Array, attempts := ATTEMPTS) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	var best_note := ""
	for attempt in attempts:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(seed_parts + [attempt])
		var data := _build(level_spec, rng)
		if data.is_empty():
			continue
		var level := LevelData.from_dict(data)
		var report := LevelSolver.solve(level)
		if not report.solvable or data.vehicles.size() < level_spec.cars * 0.85:
			continue
		var score := _score(level_spec, data, level, report)
		if score > best_score:
			best_score = score
			best = data
			best_note = "%d cars, %d waves (target %d), %d free at start, %d traps, %s" % [
				data.vehicles.size(), report.rounds, level_spec.depth, report.first_free, _traps(level), _mechanic_summary(data)]
	if best.is_empty():
		return {}
	return {"data": best, "note": best_note}


## Board size, vehicle count, target depth and mechanic counts for a level.
static func spec(w: int, i: int, mechanic: String) -> Dictionary:
	var tuning: Dictionary = WORLD_TUNING[mini(w, WORLD_TUNING.size() - 1)]
	var p := float(i) / (LEVELS_PER_WORLD - 1)
	var d: float = tuning.base + p * 0.7
	if i in BREATHERS:
		d -= 0.22
	if i in HARD:
		d += 0.12
	var intro := mechanic != "" and i < 2
	if intro:
		d = minf(d, 0.08 + i * 0.08)
	d = clampf(d, 0.0, 1.0)
	var cols := clampi(4 + roundi(d * 3.4 + 0.25), 4, 7)
	var rows := clampi(cols + (1 if d > 0.35 else 0), 4, 8)
	var mechanic_count := 0
	if mechanic != "":
		mechanic_count = 1 if i == 0 else (2 if i == 1 else roundi(lerpf(2.0, 5.0, d)))
		if mechanic == "gate" or mechanic == "lock":
			mechanic_count = mini(mechanic_count, 4)
	var extra := ""
	var extra_count := 0
	if tuning.extra != "" and i >= 6 and not i in BREATHERS:
		extra = tuning.extra
		extra_count = 1 if p < 0.6 else 2
	return {
		"cols": cols, "rows": rows,
		"cars": roundi(cols * rows * lerpf(0.3, 0.44, d)),
		"depth": roundi(lerpf(2.0, 11.0, d)) + (1 if i in HARD else 0),
		"cones": roundi(d * (2.5 if mechanic == "" else 1.2)) if not intro else 0,
		"trucks": lerpf(0.0, 0.25, d),
		"breather": i in BREATHERS,
		"mechanic": mechanic, "count": mechanic_count,
		"extra": extra, "extra_count": extra_count,
	}


static func _build(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var data := {"cols": spec.cols, "rows": spec.rows, "mistakes": 3, "vehicles": [], "obstacles": []}
	var occupied := {}
	var want := _wanted(spec)
	# Cones and gate cells first, away from the border so they block inner lanes.
	var gate_cells: Array[Vector2i] = []
	var tries := 0
	while (data.obstacles.size() < spec.cones or gate_cells.size() < want.gate) and tries < 80:
		tries += 1
		var c := Vector2i(rng.randi_range(1, spec.cols - 2), rng.randi_range(1, spec.rows - 2))
		if occupied.has(c):
			continue
		occupied[c] = true
		if data.obstacles.size() < spec.cones:
			data.obstacles.append({"type": "cone", "col": c.x, "row": c.y})
		else:
			gate_cells.append(c)

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
		_maybe_add_mechanic(entry, want, rng, spec)
		data.vehicles.append(entry)
		if not LevelSolver.solve(LevelData.from_dict(data)).solvable:
			data.vehicles.pop_back()
			continue
		if entry.has("cargo"):
			want.cargo -= 1
		if entry.has("turn"):
			want.turn -= 1
		for c in cells:
			occupied[c] = true

	if want.lock > 0 and not _add_locks(data, want.lock, rng):
		return {}
	if not gate_cells.is_empty() and not _add_gates(data, gate_cells, rng):
		return {}
	return data


## How many of each mechanic this level should get.
static func _wanted(spec: Dictionary) -> Dictionary:
	var want := {"cargo": 0, "turn": 0, "lock": 0, "gate": 0}
	if spec.mechanic != "":
		want[spec.mechanic] += spec.count
	if spec.extra != "":
		want[spec.extra] += spec.extra_count
	return want


## Gives a new vehicle the cargo or turn mechanic while some are still wanted.
static func _maybe_add_mechanic(entry: Dictionary, want: Dictionary, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var chance := 0.45
	if want.cargo > 0 and entry.type in CARGO_TYPES and rng.randf() < chance + 0.3:
		entry["cargo"] = true
		return
	if want.turn > 0 and VehicleCatalog.cells(entry.type) == 2 and rng.randf() < chance:
		var turn := 1 if rng.randf() < 0.5 else -1
		var dir := GridDir.from_name(entry.dir)
		var v := VehicleState.new(0, entry.type, Vector2i(entry.col, entry.row), dir, 2)
		v.turn = turn
		var nose := v.turn_cell()
		if nose.x >= 0 and nose.y >= 0 and nose.x < spec.cols and nose.y < spec.rows:
			entry["turn"] = "cw" if turn > 0 else "ccw"


## Picks key cars and locked cars (about two locked per key) so the level stays
## clearable; prefers the choice that makes the solution deepest.
static func _add_locks(data: Dictionary, count: int, rng: RandomNumberGenerator) -> bool:
	var groups := clampi(ceili(count / 2.0), 1, 3)
	var free_ids := []
	for k in data.vehicles.size():
		if not data.vehicles[k].has("key") and not data.vehicles[k].has("lock"):
			free_ids.append(k)
	var locked_total := 0
	for g in groups:
		var best_rounds := -1
		var best_pick := []
		for t in 12:
			if free_ids.size() < 2:
				break
			var ids := free_ids.duplicate()
			_shuffle(ids, rng)
			var per_group := mini(2, count - locked_total) if g == groups - 1 else 1 + int(count - locked_total > groups - g)
			per_group = clampi(per_group, 1, mini(2, ids.size() - 1))
			var pick := ids.slice(0, per_group + 1) # first is the key
			var trial: Dictionary = data.duplicate(true)
			trial.vehicles[pick[0]]["key"] = g
			for k in pick.slice(1):
				trial.vehicles[k]["lock"] = g
			var report := LevelSolver.solve(LevelData.from_dict(trial))
			if report.solvable and report.rounds > best_rounds:
				best_rounds = report.rounds
				best_pick = pick
		if best_pick.is_empty():
			return g > 0
		data.vehicles[best_pick[0]]["key"] = g
		for k in best_pick.slice(1):
			data.vehicles[k]["lock"] = g
			locked_total += 1
		for k in best_pick:
			free_ids.erase(k)
	return true


## Turns reserved cells into gates, each with its own key car, keeping the
## level clearable and preferring gates that stand in some car's way.
static func _add_gates(data: Dictionary, cells: Array[Vector2i], rng: RandomNumberGenerator) -> bool:
	var used_groups := {}
	for e in data.vehicles:
		if e.has("key"):
			used_groups[e.key] = true
	var group := 0
	for c in cells:
		while used_groups.has(group):
			group += 1
		if group >= LevelData.MAX_GROUPS:
			break
		var candidates := []
		for k in data.vehicles.size():
			if not data.vehicles[k].has("key"):
				candidates.append(k)
		_shuffle(candidates, rng)
		var best_rounds := -1
		var best_key := -1
		for k in candidates.slice(0, 10):
			var trial: Dictionary = data.duplicate(true)
			trial.obstacles.append({"type": "gate", "col": c.x, "row": c.y, "group": group})
			trial.vehicles[k]["key"] = group
			var report := LevelSolver.solve(LevelData.from_dict(trial))
			if report.solvable and report.rounds > best_rounds:
				best_rounds = report.rounds
				best_key = k
		if best_key < 0:
			continue
		data.obstacles.append({"type": "gate", "col": c.x, "row": c.y, "group": group})
		data.vehicles[best_key]["key"] = group
		used_groups[group] = true
	return data.obstacles.any(func(o): return o.type == "gate")


static func _score(spec: Dictionary, data: Dictionary, level: LevelData, report: LevelSolver.Report) -> float:
	var score := -absf(report.rounds - spec.depth) * 10.0
	if spec.breather:
		score += report.first_free * 2.0 # many cars free at once: a combo feast
	else:
		score -= report.first_free * 2.0
		if report.rounds >= spec.depth:
			score += 5.0 # prefer reaching the target over falling short
	# Mechanics: missing ones cost a lot; ones that matter earn a bonus.
	var want := _wanted(spec)
	var have := _count_mechanics(data)
	for m in want:
		score -= maxi(want[m] - have[m], 0) * 12.0
	score += mini(_traps(level), 3) * 6.0
	score += _gates_in_the_way(data) * 5.0
	return score


static func _count_mechanics(data: Dictionary) -> Dictionary:
	var have := {"cargo": 0, "turn": 0, "lock": 0, "gate": 0}
	for e in data.vehicles:
		for m in ["cargo", "turn", "lock"]:
			if e.has(m):
				have[m] += 1
	for o in data.obstacles:
		if o.type == "gate":
			have.gate += 1
	return have


## Pull-forwards and turns that, made at the start, leave the board unsolvable:
## the moves a careless player can get wrong.
static func _traps(level: LevelData) -> int:
	var board := BoardState.from_level(level)
	var traps := 0
	for id in board.vehicles:
		var r := board.probe(id)
		if r.action != BoardState.Action.ADVANCE and r.action != BoardState.Action.TURN:
			continue
		var next := board.clone()
		next.apply(id, r)
		if not LevelSolver.solve_board(next).solvable:
			traps += 1
	return traps


## Gates some vehicle drives through on its way out (otherwise the gate is
## just decoration).
static func _gates_in_the_way(data: Dictionary) -> int:
	var count := 0
	for o in data.obstacles:
		if o.type != "gate":
			continue
		var c := Vector2i(o.col, o.row)
		for e in data.vehicles:
			var v := VehicleState.new(0, e.type, Vector2i(e.col, e.row), GridDir.from_name(e.dir), VehicleCatalog.cells(e.type))
			var step := GridDir.to_vector(v.dir)
			var p := v.head() + step
			var hit := false
			while p.x >= 0 and p.y >= 0 and p.x < data.cols and p.y < data.rows:
				if p == c:
					hit = true
					break
				p += step
			if hit:
				count += 1
				break
	return count


static func _mechanic_summary(data: Dictionary) -> String:
	var have := _count_mechanics(data)
	var parts := PackedStringArray()
	for m in have:
		if have[m] > 0:
			parts.append("%s %d" % [m, have[m]])
	return ", ".join(parts) if not parts.is_empty() else "no mechanics"


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for k in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = list[k]
		list[k] = list[j]
		list[j] = tmp
