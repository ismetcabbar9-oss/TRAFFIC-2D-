class_name TestCase
extends RefCounted
## Minimal assertion helpers for tests/run_tests.gd.

var failures: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, expected, actual])


## Builds a level from compact rows: vehicles [type, col, row, dir, {extras}],
## obstacles [col, row] (cones) or [col, row, "gate", group].
static func make_level(cols: int, rows: int, vehicles: Array, obstacles: Array = [], mistakes := 3) -> LevelData:
	var v := []
	for e in vehicles:
		var d := {"type": e[0], "col": e[1], "row": e[2], "dir": e[3]}
		if e.size() > 4:
			d.merge(e[4])
		v.append(d)
	var o := []
	for e in obstacles:
		if e.size() > 2:
			o.append({"type": e[2], "col": e[0], "row": e[1], "group": e[3]})
		else:
			o.append({"type": "cone", "col": e[0], "row": e[1]})
	return LevelData.from_dict({"cols": cols, "rows": rows, "mistakes": mistakes, "vehicles": v, "obstacles": o})
