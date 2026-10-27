class_name LevelSolver
extends RefCounted
## Checks that a level can be cleared and measures how hard it is.
##
## Letting a vehicle leave only ever frees cells (and opens gates and locks),
## so whenever a vehicle can leave it is safe to let it go at once. Only the
## cargo pull-forward and the turn put a vehicle on a new cell, which can block
## others; the search branches on those few moves and greedily clears the
## rest. Each such move happens at most once per vehicle, so it stays small.

class Report:
	var solvable := false
	var order: Array[int] = [] ## one winning sequence of taps (vehicle ids)
	var stuck: Array[int] = [] ## vehicles that can never leave
	var rounds := 0 ## waves of moves needed (depth)
	var first_free := 0 ## vehicles able to leave at the start
	var min_free := 0 ## fewest leaving choices seen at any wave
	var errors: PackedStringArray = []


static func solve(level: LevelData) -> Report:
	var report := Report.new()
	report.errors.append_array(level.errors)
	var board := BoardState.from_level(level)
	report.errors.append_array(board.errors)
	if not report.errors.is_empty():
		return report
	return solve_board(board)


## Solves from any position (the board is not changed).
static func solve_board(start: BoardState) -> Report:
	var report := Report.new()
	for id in start.vehicles:
		if start.taps_to_leave(id) > 0:
			report.first_free += 1
	var deepest := {"left": start.vehicles.size() + 1, "stuck": []}
	var plan: Variant = _search(start.clone(), {}, deepest)
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
	return report


## First tap of a winning line from this position, or -1 if none is left.
static func next_tap(board: BoardState) -> int:
	var report := solve_board(board)
	return report.order[0] if report.solvable and not report.order.is_empty() else -1


## Returns {taps, rounds, min_free} or null. `board` is consumed.
static func _search(board: BoardState, seen: Dictionary, deepest: Dictionary) -> Variant:
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
		wave.sort()
		rounds += 1
		min_free = mini(min_free, wave.size())
		for id in wave:
			while board.vehicles.has(id):
				board.apply(id, board.probe(id))
				taps.append(id)
	if board.is_cleared():
		return {"taps": taps, "rounds": rounds, "min_free": min_free}

	var key := board.state_key()
	if seen.has(key):
		return null
	seen[key] = true
	if board.vehicles.size() < deepest.left:
		deepest.left = board.vehicles.size()
		deepest.stuck = board.vehicles.keys()

	var ids := board.vehicles.keys()
	ids.sort()
	for id in ids:
		var result := board.probe(id)
		if result.action != BoardState.Action.ADVANCE and result.action != BoardState.Action.TURN:
			continue
		var next := board.clone()
		next.apply(id, result)
		var rest: Variant = _search(next, seen, deepest)
		if rest != null:
			var all_taps := taps.duplicate()
			all_taps.append(id)
			all_taps.append_array(rest.taps)
			return {"taps": all_taps, "rounds": rounds + 1 + rest.rounds,
				"min_free": mini(min_free, rest.min_free)}
	return null
