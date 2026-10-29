class_name HazardPlacer
extends RefCounted
## Adds hazards to a finished layout (see LevelGenerator.spec for which level
## gets which):
## - tanker: one of the big vehicles becomes a fuel tanker, preferably one that
##   cars which look free would drive into;
## - pit: an empty cell on the way out of two or more cars, so the player picks
##   which one to sacrifice (each pit comes with one extra move in game);
## - bomb: the vehicle that takes a while to free gets a countdown of the taps
##   the solver needs for it plus a little slack.
## Every placement is checked with the solver; a hazard that would make the
## level unsolvable is skipped.

const BOMB_SLACK := 2
const HARD_BOMB_SLACK := 1
const BOMB_NEED := [3, 10] ## taps before the bomb can leave: not trivial, not endless
const BOMB_TARGET := 6


## Which hazards a level gets: {"tanker": n, "pits": n, "bomb": bool}.
static func plan(w: int, i: int) -> Dictionary:
	var out := {"tanker": 0, "pits": 0, "bomb": false}
	if i < LevelGenerator.SHARP_FROM or i in LevelGenerator.BREATHERS:
		return out
	if i >= 20 and (i % 2 == 0 or i in LevelGenerator.HARD):
		out.tanker = 1
	if w >= 1 and i % 3 != 1:
		out.pits = 2 if i >= 30 and i % 3 == 0 else 1
	if w >= 2 and i % 3 != 2:
		out.bomb = true
	return out


## Returns a copy of `data` with the planned hazards added.
static func add(data: Dictionary, hazards: Dictionary, hard: bool, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	for k in hazards.tanker:
		_add_tanker(out, rng)
	for k in hazards.pits:
		_add_pit(out, rng)
	if hazards.bomb:
		_add_bomb(out, HARD_BOMB_SLACK if hard else BOMB_SLACK)
	return out


static func count(data: Dictionary) -> Dictionary:
	var out := {"tanker": 0, "pits": 0, "bomb": 0}
	for e in data.vehicles:
		if e.type == "tanker":
			out.tanker += 1
		if e.has("bomb"):
			out.bomb += 1
	for o in data.obstacles:
		if o.type == "pit":
			out.pits += 1
	return out


static func _solvable(data: Dictionary) -> bool:
	var level := LevelData.from_dict(data)
	return level.is_valid() and LevelSolver.solve(level).solvable


static func _board(data: Dictionary) -> BoardState:
	return BoardState.from_level(LevelData.from_dict(data))


## A big vehicle becomes a tanker; the one most cars would crash into wins.
static func _add_tanker(data: Dictionary, rng: RandomNumberGenerator) -> void:
	var board := _board(data)
	var best := -1
	var best_score := -1.0
	for idx in data.vehicles.size():
		var e: Dictionary = data.vehicles[idx]
		if VehicleCatalog.cells(e.type) != 3 or e.type == "tanker" or e.has("cargo") or e.has("bomb"):
			continue
		var danger := 0
		for id in board.vehicles:
			if id != idx and board.probe(id).blocker == idx:
				danger += 1
		var score := danger + rng.randf() * 0.5
		if score > best_score:
			best_score = score
			best = idx
	if best < 0:
		return
	var old: String = data.vehicles[best].type
	data.vehicles[best].type = "tanker"
	if not _solvable(data):
		data.vehicles[best].type = old


## A pit on the way of several cars, ideally one that looks free.
static func _add_pit(data: Dictionary, rng: RandomNumberGenerator) -> void:
	var board := _board(data)
	var crossers := {} # cell -> [vehicle ids whose way out crosses it]
	for id in board.vehicles:
		var v: VehicleState = board.vehicles[id]
		if v.type == "tanker" or v.turn != 0:
			continue
		var step := GridDir.to_vector(v.dir)
		var c := v.head() + step
		while board.in_bounds(c):
			if board.at(c) == BoardState.EMPTY:
				if not crossers.has(c):
					crossers[c] = []
				crossers[c].append(id)
			c += step
	var cells := crossers.keys()
	cells.sort()
	var ranked := []
	for c in cells:
		var ids: Array = crossers[c]
		var looks_free := ids.any(func(id): return board.probe(id).free)
		ranked.append([ids.size() * 3.0 + (4.0 if looks_free else 0.0) + rng.randf() * 2.0, c])
	ranked.sort_custom(func(a, b): return a[0] > b[0])
	for entry in ranked.slice(0, 8):
		var c: Vector2i = entry[1]
		data.obstacles.append({"type": "pit", "col": c.x, "row": c.y})
		if _solvable(data):
			return
		data.obstacles.pop_back()


## The vehicle whose way out takes closest to BOMB_TARGET taps gets the
## countdown: long enough to need a plan, short enough to feel the clock.
static func _add_bomb(data: Dictionary, slack: int) -> void:
	var best := -1
	var best_need := 0
	for idx in data.vehicles.size():
		var e: Dictionary = data.vehicles[idx]
		if e.type == "tanker":
			continue
		e["bomb"] = 99
		var report := LevelSolver.solve(LevelData.from_dict(data))
		e.erase("bomb")
		if not report.solvable:
			continue
		# A cargo or turning bomb is tapped twice; the last tap is the one out.
		var need := report.order.rfind(idx) + 1
		if need < BOMB_NEED[0] or need > BOMB_NEED[1]:
			continue
		if best < 0 or absi(need - BOMB_TARGET) < absi(best_need - BOMB_TARGET):
			best_need = need
			best = idx
	if best < 0:
		return
	data.vehicles[best]["bomb"] = best_need + slack
	if not _solvable(data):
		data.vehicles[best].erase("bomb")
