class_name LevelSolver
extends RefCounted
## Checks that a level can be cleared and measures how hard it is.
##
## Letting a vehicle leave only ever frees cells (and opens gates and locks),
## so whenever a vehicle can leave it is safe to let it go at once. Only the
## cargo pull-forward and the turn put a vehicle on a new cell, which can block
## others; the search branches on those few moves and greedily clears the
## rest. Each such move happens at most once per vehicle, so it stays small.
##
## Hazards: driving into a pit also only frees cells, but costs a wrong move,
## so falls are searched last and within a budget (fewest falls first). Bombs
## make time count: while one is parked, only the vehicles in its way (and
## their keys) are let out, bombs first, and a line fails if a bomb reaches
## zero. Tankers need nothing: a winning line never crashes.

class Report:
	var solvable := false
	var order: Array[int] = [] ## one winning sequence of taps (vehicle ids)
	var stuck: Array[int] = [] ## vehicles that can never leave
	var rounds := 0 ## waves of moves needed (depth)
	var first_free := 0 ## vehicles able to leave at the start
	var min_free := 0 ## fewest leaving choices seen at any wave
	var falls := 0 ## vehicles the line drives into pits
	var errors: PackedStringArray = []


static func solve(level: LevelData, max_falls := -1) -> Report:
	var report := Report.new()
	report.errors.append_array(level.errors)
	var board := BoardState.from_level(level)
	report.errors.append_array(board.errors)
	if not report.errors.is_empty():
		return report
	return solve_board(board, max_falls)


## Solves from any position (the board is not changed). `max_falls` limits
## how many vehicles may be driven into pits (-1: as many as there are pits).
static func solve_board(start: BoardState, max_falls := -1) -> Report:
	var report := Report.new()
	for id in start.vehicles:
		if start.taps_to_leave(id) > 0:
			report.first_free += 1
	var most := start.pits.size() if max_falls < 0 else mini(max_falls, start.pits.size())
	var deepest := {"left": start.vehicles.size() + 1, "stuck": []}
	var plan: Variant = null
	for budget in most + 1:
		plan = _search(start.clone(), {}, deepest, budget)
		if plan != null:
			break
	if plan == null:
		var stuck: Array[int] = []
		stuck.assign(deepest.stuck)
		stuck.sort()
		report.stuck = stuck
		return report
	report.solvable = true
	report.order.assign(plan.taps)
	report.rounds = plan.rounds
	report.min_free = plan.min_free
	report.falls = plan.falls
	return report


## First tap of a winning line from this position, or -1 if none is left.
static func next_tap(board: BoardState, max_falls := -1) -> int:
	var report := solve_board(board, max_falls)
	return report.order[0] if report.solvable and not report.order.is_empty() else -1


## Vehicles a parked bomb is waiting on: the bombs, whatever stands in their
## way, and so on, plus the keys of locks and gates on the way.
static func bomb_focus(board: BoardState) -> Dictionary:
	var focus := {}
	var queue: Array[int] = []
	for id in board.vehicles:
		if (board.vehicles[id] as VehicleState).bomb > 0:
			queue.append(id)
	while not queue.is_empty():
		var id: int = queue.pop_back()
		if focus.has(id) or not board.vehicles.has(id):
			continue
		focus[id] = true
		var v: VehicleState = board.vehicles[id]
		if v.lock >= 0 and board.keys.has(v.lock):
			queue.append(board.keys[v.lock])
		var from := v.head()
		var dir := v.dir
		if v.turn != 0:
			from = v.turn_cell()
			dir = v.turned_dir()
			_blocking(board, from, queue)
		var c := from + GridDir.to_vector(dir)
		while board.in_bounds(c):
			_blocking(board, c, queue)
			c += GridDir.to_vector(dir)
	return focus


static func _blocking(board: BoardState, c: Vector2i, queue: Array[int]) -> void:
	var occupant := board.at(c)
	if occupant >= 0:
		queue.append(occupant)
	elif occupant == BoardState.GATE and board.keys.has(board.gates[c]):
		queue.append(board.keys[board.gates[c]])


## Taps a vehicle; false if a bomb went off.
static func _tap(board: BoardState, id: int) -> bool:
	board.apply(id, board.probe(id))
	return board.tick_bombs() < 0


## Returns {taps, rounds, min_free, falls} or null. `board` is consumed.
static func _search(board: BoardState, seen: Dictionary, deepest: Dictionary, budget: int) -> Variant:
	var taps: Array[int] = []
	var rounds := 0
	var min_free := 1 << 30
	while true:
		var wave: Array[int] = []
		for id in board.vehicles:
			if board.taps_to_leave(id) > 0:
				wave.append(id)
		if wave.is_empty():
			break
		if board.has_bombs():
			var focus := bomb_focus(board)
			var urgent := wave.filter(func(id: int) -> bool: return focus.has(id))
			if not urgent.is_empty():
				wave.assign(urgent)
		wave.sort_custom(func(a: int, b: int) -> bool:
			var ba: bool = (board.vehicles[a] as VehicleState).bomb > 0
			var bb: bool = (board.vehicles[b] as VehicleState).bomb > 0
			return ba and not bb or ba == bb and a < b)
		rounds += 1
		min_free = mini(min_free, wave.size())
		for id in wave:
			while board.vehicles.has(id):
				taps.append(id)
				if not _tap(board, id):
					return null
	if board.is_cleared():
		return {"taps": taps, "rounds": rounds, "min_free": min_free, "falls": 0}

	var key := "%s|%d" % [board.state_key(), budget]
	if seen.has(key):
		return null
	seen[key] = true
	if board.vehicles.size() < deepest.left:
		deepest.left = board.vehicles.size()
		deepest.stuck = board.vehicles.keys()

	var ids := board.vehicles.keys()
	ids.sort()
	for pass_falls in [false, true]:
		if pass_falls and budget <= 0:
			break
		for id in ids:
			var result := board.probe(id)
			var is_fall := result.action == BoardState.Action.FALL
			if is_fall != pass_falls or result.explodes:
				continue
			if not is_fall and result.action != BoardState.Action.ADVANCE and result.action != BoardState.Action.TURN:
				continue
			var next := board.clone()
			if not _tap(next, id):
				continue
			var rest: Variant = _search(next, seen, deepest, budget - (1 if is_fall else 0))
			if rest != null:
				var all_taps := taps.duplicate()
				all_taps.append(id)
				all_taps.append_array(rest.taps)
				return {"taps": all_taps, "rounds": rounds + 1 + rest.rounds,
					"min_free": mini(min_free, rest.min_free), "falls": rest.falls + (1 if is_fall else 0)}
	return null
