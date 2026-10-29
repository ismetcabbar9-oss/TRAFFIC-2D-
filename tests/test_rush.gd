extends TestCase
## Endless "rush hour" mode.


func test_start_level_is_clearable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var level := Rush.start_level(rng)
	check_eq(level.vehicles.size(), Rush.START_CARS, "opening cars")
	check_eq(level.cols * 10 + level.rows, Rush.COLS * 10 + Rush.ROWS, "7x8 lot")
	check(LevelSolver.solve(level).solvable, "clearable")


func test_arrivals_keep_lot_clearable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var s := GameSession.new(Rush.start_level(rng))
	s.endless = true
	for k in 12:
		var entry := Rush.pick(s.board, rng, 40)
		if entry.is_empty():
			break
		check(s.add_vehicle(entry) >= 0, "fits")
		check(LevelSolver.solve_board(s.board, 0).solvable, "still clearable after arrival %d" % k)


func test_endless_does_not_win_on_empty_lot() -> void:
	var s := GameSession.new(make_level(4, 4, [["sedan", 0, 0, "right"]]))
	s.endless = true
	s.tap(0)
	check_eq(s.state, GameSession.State.PLAYING, "keeps going")
	var id := s.add_vehicle({"type": "sedan", "cell": Vector2i(1, 2), "dir": GridDir.UP})
	check(id > 0, "new id, not reused")
	check(s.tap(id).free, "the new car can leave")


func test_full_lot_ends_run() -> void:
	var s := GameSession.new(make_level(4, 4, [["sedan", 0, 0, "right"]]))
	s.endless = true
	s.end("full")
	check_eq(s.state, GameSession.State.LOST, "over")
	check_eq(s.lose_reason, "full", "reason")
	s.add_mistakes(2)
	check_eq(s.state, GameSession.State.LOST, "no continuing a full lot")


func test_add_vehicle_rejects_overlap() -> void:
	var s := GameSession.new(make_level(4, 4, [["sedan", 0, 0, "right"]]))
	check_eq(s.add_vehicle({"type": "sedan", "cell": Vector2i(1, 0), "dir": GridDir.DOWN}), -1, "overlaps")


func test_pace_and_points() -> void:
	check_eq(Rush.interval(0), Rush.FIRST_INTERVAL, "slow start")
	check_eq(Rush.interval(1000), Rush.LAST_INTERVAL, "fastest later")
	check(Rush.interval(30) < Rush.interval(10), "speeds up")
	check_eq(Rush.points(1, false), 10, "a car")
	check_eq(Rush.points(3, true), 35, "combo and quick bonus")
