extends TestCase
## Hazards: pits, tankers and bombs.


func test_pit_swallows_the_first_vehicle() -> void:
	var s := GameSession.new(make_level(5, 5, [["sedan", 0, 2, "right"], ["sedan", 3, 0, "down"]], [[3, 2, "pit", -1]]))
	var r := s.tap(0)
	check_eq(r.action, BoardState.Action.FALL, "drives into the pit")
	check(not s.board.vehicles.has(0), "the vehicle is gone")
	check_eq(s.mistakes_left, 2, "costs a wrong move")
	check_eq(s.falls, 1, "counted as a fall")
	check_eq(s.crashes, 0, "not a crash")
	check(s.board.at(Vector2i(3, 2)) == BoardState.EMPTY, "the pit is filled")
	check(s.tap(1).free, "the next car drives over it")
	check_eq(s.state, GameSession.State.WON, "won")


func test_last_vehicle_falling_still_wins() -> void:
	var s := GameSession.new(make_level(4, 4, [["sedan", 0, 1, "right"]], [[3, 1, "pit", -1]], 1))
	s.tap(0)
	check_eq(s.state, GameSession.State.WON, "board cleared")


func test_fall_opens_its_gate() -> void:
	var board := BoardState.from_level(make_level(5, 5, [
		["sedan", 0, 0, "right", {"key": 0}],
		["sedan", 4, 3, "up"],
	], [[2, 0, "pit", -1], [4, 2, "gate", 0]]))
	var r := board.probe(0)
	board.apply(0, r)
	check(r.opened.has(Vector2i(4, 2)), "a fallen key still opens its gate")


func test_tanker_crash_explodes() -> void:
	var s := GameSession.new(make_level(6, 6, [["sedan", 0, 0, "right"], ["tanker", 3, 0, "down"]]))
	var r := s.tap(0)
	check(r.explodes, "hitting a tanker")
	check_eq(s.state, GameSession.State.LOST, "lost at once")
	check_eq(s.lose_reason, "explosion", "reason")
	check(not s.can_undo(), "no undo after an explosion")
	s.add_mistakes(2)
	check_eq(s.state, GameSession.State.LOST, "extra moves do not help")


func test_tanker_hitting_something_explodes() -> void:
	var board := BoardState.from_level(make_level(6, 6, [["tanker", 0, 0, "right"], ["sedan", 4, 0, "down"]]))
	check(board.probe(0).explodes, "the tanker itself crashing")


func test_tanker_into_pit_explodes() -> void:
	var s := GameSession.new(make_level(6, 6, [["tanker", 0, 0, "right"]], [[4, 0, "pit", -1]]))
	s.tap(0)
	check_eq(s.lose_reason, "explosion", "tanker in a pit")


func test_bomb_counts_down_and_explodes() -> void:
	var s := GameSession.new(make_level(6, 6, [
		["sedan", 0, 0, "right", {"bomb": 2}],
		["sedan", 4, 0, "down"],
		["sedan", 0, 3, "left"],
		["sedan", 0, 4, "left"],
	]))
	s.tap(2)
	check_eq(s.board.vehicles[0].bomb, 1, "one tap: one down")
	s.tap(3)
	check_eq(s.state, GameSession.State.LOST, "zero while parked: boom")
	check_eq(s.lose_reason, "bomb", "reason")


func test_bomb_leaving_in_time_is_safe() -> void:
	var s := GameSession.new(make_level(6, 6, [
		["sedan", 0, 0, "right", {"bomb": 2}],
		["sedan", 4, 0, "down"],
	]))
	s.tap(1)
	s.tap(0)
	check_eq(s.state, GameSession.State.WON, "out on its last tap")


func test_locked_tap_does_not_tick() -> void:
	var s := GameSession.new(make_level(6, 6, [
		["sedan", 0, 0, "right", {"bomb": 3}],
		["sedan", 4, 0, "down", {"key": 0}],
		["sedan", 0, 3, "right", {"lock": 0}],
	]))
	s.tap(2)
	check_eq(s.board.vehicles[0].bomb, 3, "locked tap is free")


func test_undo_restores_bomb_counter() -> void:
	var s := GameSession.new(make_level(6, 6, [
		["sedan", 0, 0, "right", {"bomb": 5}],
		["sedan", 4, 0, "down"],
	]))
	s.tap(0) # crash into the sedan
	check_eq(s.board.vehicles[0].bomb, 4, "a crash is a tap")
	s.undo()
	check_eq(s.board.vehicles[0].bomb, 5, "undo gives the tap back")


func test_solver_uses_a_pit_only_when_needed() -> void:
	# The sedan at (1, 1) faces the pit; the car at (3, 0) can only leave once
	# the pit has been filled, and nothing else can fill it.
	var level := make_level(5, 4, [["sedan", 0, 1, "right"], ["sedan", 3, 2, "up"]], [[3, 1, "pit", -1]])
	var report := LevelSolver.solve(level)
	check(report.solvable, "solvable with a sacrifice")
	check_eq(report.falls, 1, "one fall")
	check(not LevelSolver.solve(level, 0).solvable, "not without one")


func test_solver_meets_bomb_deadline() -> void:
	# The bomb waits for car 1 only; cars 2-4 are free but would waste taps.
	var level := make_level(6, 6, [
		["sedan", 0, 0, "right", {"bomb": 2}],
		["sedan", 4, 0, "down"],
		["sedan", 1, 3, "left"],
		["sedan", 1, 4, "left"],
		["sedan", 1, 5, "left"],
	])
	var report := LevelSolver.solve(level)
	check(report.solvable, "solvable")
	check_eq(report.order.slice(0, 2), [1, 0], "clears the bomb first")


func test_solver_rejects_impossible_bomb() -> void:
	var level := make_level(6, 6, [
		["sedan", 0, 0, "right", {"bomb": 1}],
		["sedan", 4, 0, "down"],
	])
	check(not LevelSolver.solve(level).solvable, "needs two taps, has one")


func test_every_level_clears_within_its_moves() -> void:
	for w in LevelCatalog.world_count():
		for i in LevelCatalog.level_count(w):
			var level := LevelData.load_file(LevelCatalog.path(w, i))
			var pits := level.obstacles.filter(func(o): return o.type == "pit").size()
			var moves := Economy.mistakes_for(w, i, level.hard) + pits
			var report := LevelSolver.solve(level, moves - 1)
			check(level.is_valid() and report.solvable, "world %d level %d clears with %d moves" % [w + 1, i + 1, moves])
