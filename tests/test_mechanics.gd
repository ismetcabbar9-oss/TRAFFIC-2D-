extends TestCase
## World mechanics: cargo, turn, lock and gate.


func test_cargo_pulls_forward_one_cell() -> void:
	var s := GameSession.new(make_level(5, 5, [["pickup", 0, 2, "right", {"cargo": true}]]))
	var r := s.tap(0)
	check_eq(r.action, BoardState.Action.ADVANCE, "first tap advances")
	check_eq(s.board.vehicles[0].cell, Vector2i(1, 2), "one cell further")
	check(s.board.at(Vector2i(0, 2)) == BoardState.EMPTY, "rear cell freed")
	check(s.tap(0).free, "second tap leaves")
	check_eq(s.state, GameSession.State.WON, "won")


func test_cargo_at_edge_leaves_at_once() -> void:
	var board := BoardState.from_level(make_level(4, 4, [["pickup", 2, 0, "right", {"cargo": true}]]))
	check(board.probe(0).free, "nose at the edge: out in one tap")
	check_eq(board.taps_to_leave(0), 1, "one tap")


func test_cargo_blocked_crashes() -> void:
	var board := BoardState.from_level(make_level(5, 5, [
		["pickup", 0, 0, "right", {"cargo": true}],
		["sedan", 2, 0, "down"],
	]))
	var r := board.probe(0)
	check_eq(r.action, BoardState.Action.CRASH, "nose against a car")
	check_eq(r.blocker, 1, "blocker")


func test_cargo_pull_forward_unblocks_another() -> void:
	# Car 1 needs the cargo's rear cell (0, 3); 3 waits for 1, 2 for 3 and the
	# cargo for 2. Only pulling the cargo forward first breaks the circle.
	var level := make_level(5, 5, [
		["pickup", 0, 2, "up", {"cargo": true}],
		["sedan", 2, 3, "left"],
		["sedan", 0, 0, "right"],
		["sedan", 3, 0, "down"],
	])
	var report := LevelSolver.solve(level)
	check(report.solvable, "solvable with a pull-forward")
	check_eq(report.order, [0, 1, 3, 2, 0] as Array[int], "pull forward, then the chain")
	check_eq(report.first_free, 0, "nothing can leave at the start")


func test_turn_swings_around_tail() -> void:
	# Facing right with the tail at (1, 1); turning clockwise faces down with
	# the nose at (1, 2).
	var s := GameSession.new(make_level(5, 5, [["sedan", 1, 1, "right", {"turn": "cw"}]]))
	var r := s.tap(0)
	check_eq(r.action, BoardState.Action.TURN, "first tap turns")
	var v: VehicleState = s.board.vehicles[0]
	check_eq(v.dir, GridDir.DOWN, "now faces down")
	check_eq(v.cells(), [Vector2i(1, 1), Vector2i(1, 2)] as Array[Vector2i], "new footprint")
	check(s.board.at(Vector2i(2, 1)) == BoardState.EMPTY, "old nose cell freed")
	check(s.tap(0).free, "then drives out downward")


func test_turn_counter_clockwise_from_left() -> void:
	# Facing left: head (1, 2), tail (2, 2). Counter-clockwise: faces down,
	# nose at (2, 3).
	var board := BoardState.from_level(make_level(5, 5, [["sedan", 1, 2, "left", {"turn": "ccw"}]]))
	board.apply(0, board.probe(0))
	var v: VehicleState = board.vehicles[0]
	check_eq(v.dir, GridDir.DOWN, "faces down")
	check_eq(v.cells(), [Vector2i(2, 2), Vector2i(2, 3)] as Array[Vector2i], "pivoted on the tail")


func test_turn_into_car_crashes() -> void:
	var board := BoardState.from_level(make_level(5, 5, [
		["sedan", 1, 1, "right", {"turn": "cw"}],
		["sedan", 0, 2, "right"],
	]))
	var r := board.probe(0)
	check_eq(r.action, BoardState.Action.CRASH, "nose would hit a car")
	check(r.turning, "crash while turning")
	check_eq(r.blocker, 1, "blocker")


func test_turn_out_of_board_is_a_layout_error() -> void:
	var report := LevelSolver.solve(make_level(5, 5, [["sedan", 0, 4, "right", {"turn": "cw"}]]))
	check(not report.errors.is_empty(), "nose cannot leave the board")


func test_lock_waits_for_key() -> void:
	var s := GameSession.new(make_level(5, 5, [
		["sedan", 0, 0, "right", {"lock": 0}],
		["sedan", 0, 3, "right", {"key": 0}],
	]))
	var r := s.tap(0)
	check_eq(r.action, BoardState.Action.LOCKED, "locked")
	check_eq(s.mistakes_left, 3, "a locked tap costs nothing")
	check(s.tap(1).free, "key leaves")
	check(s.tap(0).free, "lock opened")


func test_gate_opens_when_key_leaves() -> void:
	var level := make_level(5, 5, [
		["sedan", 0, 1, "right"],
		["sedan", 0, 4, "right", {"key": 1}],
	], [[3, 1, "gate", 1]])
	var s := GameSession.new(level)
	var r := s.tap(0)
	check_eq(r.blocker, BoardState.GATE, "gate blocks")
	r = s.tap(1)
	check_eq(r.opened, [Vector2i(3, 1)] as Array[Vector2i], "gate opened")
	check(s.tap(0).free, "road open")
	check(LevelSolver.solve(level).solvable, "solver agrees")


func test_group_needs_one_key() -> void:
	var level := make_level(5, 5, [["sedan", 0, 0, "right", {"lock": 2}]])
	check(not level.errors.is_empty(), "lock without key reported")


func test_player_can_deadlock_and_solver_sees_it() -> void:
	# Q, S, R and the cargo P leave in that order. Pulling P forward first puts
	# it in Q's way: P waits for R, R for S, S for Q, Q for P.
	var level := make_level(5, 5, [
		["pickup", 0, 1, "right", {"cargo": true}],
		["sedan", 2, 2, "up"],
		["sedan", 3, 1, "down"],
		["sedan", 3, 3, "left"],
	])
	var report := LevelSolver.solve(level)
	check(report.solvable, "solvable")
	check_eq(report.order, [1, 3, 2, 0, 0] as Array[int], "Q, S, R, then P twice")
	var s := GameSession.new(level)
	check(not s.is_deadlocked(), "fine at the start")
	s.tap(0)
	check(s.is_deadlocked(), "pulling P forward first boxes everyone in")


func test_next_tap_hint() -> void:
	var board := BoardState.from_level(make_level(6, 6, [
		["sedan", 0, 0, "right"],
		["sedan", 4, 0, "down"],
		["sedan", 3, 2, "right"],
	]))
	check_eq(LevelSolver.next_tap(board), 2, "hint starts the chain")
	check_eq(board.vehicles.size(), 3, "board untouched")
