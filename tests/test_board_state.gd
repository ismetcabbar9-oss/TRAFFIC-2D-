extends TestCase


func test_vehicle_cells_and_head() -> void:
	var right := VehicleState.new(0, "sedan", Vector2i(1, 2), GridDir.RIGHT, 2)
	check_eq(right.cells(), [Vector2i(1, 2), Vector2i(2, 2)] as Array[Vector2i], "right cells")
	check_eq(right.head(), Vector2i(2, 2), "right head")
	var up := VehicleState.new(1, "garbage", Vector2i(3, 1), GridDir.UP, 3)
	check_eq(up.head(), Vector2i(3, 1), "up head")
	var down := VehicleState.new(2, "garbage", Vector2i(3, 1), GridDir.DOWN, 3)
	check_eq(down.head(), Vector2i(3, 3), "down head")


func test_free_vehicle_drives_out() -> void:
	var board := BoardState.from_level(make_level(4, 4, [["sedan", 0, 0, "right"]]))
	var r := board.probe(0)
	check(r.free, "empty row should be free")
	check_eq(r.steps, 2, "cells driven to the edge")


func test_blocked_by_vehicle() -> void:
	var board := BoardState.from_level(make_level(6, 6, [
		["sedan", 0, 0, "right"],
		["sedan", 4, 0, "down"],
	]))
	var r := board.probe(0)
	check(not r.free, "should be blocked")
	check_eq(r.blocker, 1, "blocker id")
	check_eq(r.steps, 2, "steps before contact")
	check_eq(r.contact_cell, Vector2i(4, 0), "contact cell")


func test_blocked_by_obstacle() -> void:
	var board := BoardState.from_level(make_level(5, 5, [["sedan", 0, 2, "down"]], [[0, 4]]))
	var r := board.probe(0)
	check_eq(r.blocker, BoardState.OBSTACLE, "obstacle blocks")
	check_eq(r.steps, 0, "obstacle right in front")


func test_removing_frees_path() -> void:
	var board := BoardState.from_level(make_level(6, 6, [
		["sedan", 0, 0, "right"],
		["sedan", 4, 0, "up"],
	]))
	check(not board.probe(0).free, "blocked at first")
	check(board.probe(1).free, "upward car exits immediately")
	board.remove_vehicle(1)
	check(board.probe(0).free, "free after blocker left")
	board.remove_vehicle(0)
	check(board.is_cleared(), "board cleared")


func test_layout_errors() -> void:
	var overlap := BoardState.from_level(make_level(6, 6, [["sedan", 0, 0, "right"], ["sedan", 1, 0, "down"]]))
	check(not overlap.errors.is_empty(), "overlap reported")
	var outside := BoardState.from_level(make_level(6, 6, [["garbage", 4, 0, "right"]]))
	check(not outside.errors.is_empty(), "out of bounds reported")
	var bad := make_level(6, 6, [["spaceship", 0, 0, "right"], ["sedan", 0, 1, "sideways"]])
	check_eq(bad.errors.size(), 2, "unknown type and dir reported")
