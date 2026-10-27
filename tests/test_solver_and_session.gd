extends TestCase


func test_solvable_chain() -> void:
	# 0 waits for 1, which waits for 2.
	var level := make_level(6, 6, [
		["sedan", 0, 0, "right"],
		["sedan", 4, 0, "down"],
		["sedan", 3, 2, "right"],
	])
	var report := LevelSolver.solve(level)
	check(report.solvable, "chain is solvable")
	check_eq(report.first_free, 1, "one free at start")
	check_eq(report.rounds, 3, "three waves")
	check_eq(report.order, [2, 1, 0] as Array[int], "exit order")


func test_head_on_deadlock() -> void:
	var level := make_level(6, 6, [
		["sedan", 0, 0, "right"],
		["sedan", 3, 0, "left"],
		["sedan", 5, 3, "up"],
	])
	var report := LevelSolver.solve(level)
	check(not report.solvable, "facing cars can never leave")
	check_eq(report.stuck, [0, 1] as Array[int], "stuck vehicles")


func test_session_win() -> void:
	var s := GameSession.new(make_level(6, 6, [["sedan", 0, 0, "right"], ["sedan", 4, 0, "up"]]))
	check(not s.tap(0).free, "first tap crashes")
	check_eq(s.mistakes_left, 2, "one mistake used")
	check(s.tap(1).free, "blocker leaves")
	check(s.tap(0).free, "now free")
	check_eq(s.state, GameSession.State.WON, "won")
	check(s.tap(0) == null, "taps ignored after win")


func test_session_lose_and_continue() -> void:
	var s := GameSession.new(make_level(6, 6, [["sedan", 0, 0, "right"], ["sedan", 4, 0, "up"]], [], 2))
	s.tap(0)
	check_eq(s.state, GameSession.State.PLAYING, "still playing with 1 left")
	s.tap(0)
	check_eq(s.state, GameSession.State.LOST, "lost at 0")
	check(s.tap(1) == null, "taps ignored after loss")
	s.add_mistakes(1)
	check_eq(s.state, GameSession.State.PLAYING, "resumed after extra move")
	check(s.tap(1).free, "can keep playing")


func test_all_level_files_are_solvable() -> void:
	for w in LevelCatalog.world_count():
		for file in LevelCatalog.paths(w):
			var report := LevelSolver.solve(LevelData.load_file(file))
			check(report.errors.is_empty(), "%s errors: %s" % [file, report.errors])
			check(report.solvable, "%s unsolvable, stuck: %s" % [file, report.stuck])
	check(LevelCatalog.level_count(0) > 0, "world 1 has levels")
