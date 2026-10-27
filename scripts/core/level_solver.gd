class_name LevelSolver
extends RefCounted
## Checks that a level can be cleared and measures how hard it is.
##
## Removing a vehicle only ever frees cells, so if some vehicle is free now it
## stays free. Greedily removing free vehicles therefore clears the board
## whenever any order can; vehicles left over can never get out.

class Report:
	var solvable := false
	var order: Array[int] = [] ## one valid exit order
	var stuck: Array[int] = [] ## vehicles that can never leave
	var rounds := 0 ## waves of simultaneously free vehicles (depth)
	var first_free := 0 ## vehicles free at the start
	var min_free := 0 ## fewest free choices seen at any wave
	var errors: PackedStringArray = []


static func solve(level: LevelData) -> Report:
	var report := Report.new()
	report.errors.append_array(level.errors)
	var board := BoardState.from_level(level)
	report.errors.append_array(board.errors)
	if not report.errors.is_empty():
		return report

	report.min_free = board.vehicles.size()
	while not board.is_cleared():
		var wave := board.free_vehicles()
		if report.rounds == 0:
			report.first_free = wave.size()
		if wave.is_empty():
			break
		report.min_free = mini(report.min_free, wave.size())
		report.rounds += 1
		for id in wave:
			board.remove_vehicle(id)
			report.order.append(id)

	for id in board.vehicles:
		report.stuck.append(id)
	report.stuck.sort()
	report.solvable = report.stuck.is_empty()
	return report
