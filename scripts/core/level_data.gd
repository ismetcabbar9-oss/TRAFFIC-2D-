class_name LevelData
extends RefCounted
## A level as authored in a JSON file under res://levels/.
##
## {
##   "name": "Level 1",
##   "cols": 6, "rows": 6,
##   "mistakes": 3,                                   // wrong taps until the level is lost
##   "hard": false,                                   // optional: marked hard, pays more
##   "vehicles": [{"type": "sedan", "col": 0, "row": 0, "dir": "right"}],
##   "obstacles": [{"type": "cone", "col": 2, "row": 3}]
## }

const OBSTACLE_TYPES: Array[String] = ["cone", "box"]

var name := ""
var cols := 6
var rows := 6
var mistakes := 3
var hard := false
var vehicles: Array[Dictionary] = [] ## {type, cell: Vector2i, dir: int}
var obstacles: Array[Dictionary] = [] ## {type, cell: Vector2i}
var errors: PackedStringArray = [] ## problems found while parsing


static func load_file(path: String) -> LevelData:
	var level := LevelData.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		level.errors.append("cannot read %s" % path)
		return level
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		level.errors.append("%s is not a JSON object" % path)
		return level
	level._parse(parsed)
	return level


static func from_dict(data: Dictionary) -> LevelData:
	var level := LevelData.new()
	level._parse(data)
	return level


func to_dict() -> Dictionary:
	var v := []
	for e in vehicles:
		v.append({"type": e.type, "col": e.cell.x, "row": e.cell.y, "dir": GridDir.to_name(e.dir)})
	var o := []
	for e in obstacles:
		o.append({"type": e.type, "col": e.cell.x, "row": e.cell.y})
	return {"name": name, "cols": cols, "rows": rows, "mistakes": mistakes, "hard": hard, "vehicles": v, "obstacles": o}


func is_valid() -> bool:
	return errors.is_empty()


func _parse(data: Dictionary) -> void:
	name = str(data.get("name", ""))
	cols = int(data.get("cols", 6))
	rows = int(data.get("rows", 6))
	mistakes = int(data.get("mistakes", 3))
	hard = bool(data.get("hard", false))
	if cols < 2 or rows < 2 or cols > 12 or rows > 12:
		errors.append("board size %dx%d out of range" % [cols, rows])
	if mistakes < 1:
		errors.append("mistakes must be >= 1")

	for i in data.get("vehicles", []).size():
		var e: Dictionary = data["vehicles"][i]
		var type := str(e.get("type", ""))
		var dir := GridDir.from_name(str(e.get("dir", "")))
		if not VehicleCatalog.has_type(type):
			errors.append("vehicle %d: unknown type '%s'" % [i, type])
			continue
		if dir < 0:
			errors.append("vehicle %d: unknown dir '%s'" % [i, e.get("dir")])
			continue
		vehicles.append({"type": type, "cell": Vector2i(int(e.get("col", 0)), int(e.get("row", 0))), "dir": dir})

	for i in data.get("obstacles", []).size():
		var e: Dictionary = data["obstacles"][i]
		var type := str(e.get("type", "cone"))
		if not type in OBSTACLE_TYPES:
			errors.append("obstacle %d: unknown type '%s'" % [i, type])
			continue
		obstacles.append({"type": type, "cell": Vector2i(int(e.get("col", 0)), int(e.get("row", 0)))})

	if vehicles.is_empty() and errors.is_empty():
		errors.append("level has no vehicles")
