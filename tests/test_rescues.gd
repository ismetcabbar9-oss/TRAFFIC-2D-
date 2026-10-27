extends TestCase
## Undo, crane and continue.


func test_undo_crash_refunds_move() -> void:
	var s := GameSession.new(make_level(6, 6, [["sedan", 0, 0, "right"], ["sedan", 4, 0, "up"]], [], 2))
	s.tap(0)
	check_eq(s.crashes, 1, "one crash")
	check(s.can_undo(), "crash can be undone")
	check_eq(s.undo(), BoardState.Action.CRASH, "undid a crash")
	check_eq(s.mistakes_left, 2, "move refunded")
	check_eq(s.crashes, 0, "crash no longer counts")
	check(not s.can_undo(), "only once")


func test_undo_after_loss_resumes() -> void:
	var s := GameSession.new(make_level(6, 6, [["sedan", 0, 0, "right"], ["sedan", 4, 0, "up"]], [], 1))
	s.tap(0)
	check_eq(s.state, GameSession.State.LOST, "lost")
	s.undo()
	check_eq(s.state, GameSession.State.PLAYING, "playing again")


func test_undo_pull_forward_restores_cells() -> void:
	var s := GameSession.new(make_level(5, 5, [["pickup", 0, 2, "right", {"cargo": true}]]))
	s.tap(0)
	check_eq(s.board.vehicles[0].cell, Vector2i(1, 2), "moved")
	s.undo()
	var v: VehicleState = s.board.vehicles[0]
	check_eq(v.cell, Vector2i(0, 2), "back in place")
	check(v.cargo, "still loaded")
	check_eq(s.board.at(Vector2i(0, 2)), 0, "rear cell occupied again")
	check_eq(s.board.at(Vector2i(2, 2)), BoardState.EMPTY, "front cell free again")


func test_undo_turn() -> void:
	var s := GameSession.new(make_level(5, 5, [["sedan", 1, 1, "right", {"turn": "cw"}]]))
	s.tap(0)
	s.undo()
	var v: VehicleState = s.board.vehicles[0]
	check_eq(v.dir, GridDir.RIGHT, "faces right again")
	check_eq(v.turn, 1, "turn pending again")
	check_eq(s.board.at(Vector2i(1, 2)), BoardState.EMPTY, "nose cell free")


func test_exit_cannot_be_undone() -> void:
	var s := GameSession.new(make_level(5, 5, [["sedan", 0, 0, "right"], ["sedan", 0, 3, "right"]]))
	s.tap(0)
	check(not s.can_undo(), "exits are final")


func test_crane_lifts_blocked_car_and_opens_gate() -> void:
	var level := make_level(5, 5, [
		["sedan", 0, 1, "right"],
		["sedan", 0, 4, "up", {"key": 0}],
	], [[3, 1, "gate", 0]])
	var s := GameSession.new(level)
	var r := s.lift(1)
	check(r.free, "lifted out")
	check_eq(r.opened, [Vector2i(3, 1)] as Array[Vector2i], "gate opened")
	check(s.tap(0).free, "road open")
	check_eq(s.state, GameSession.State.WON, "won")
