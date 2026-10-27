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
##
## World mechanics (all optional, see BoardState):
##   vehicle "cargo": true           first tap pulls forward one cell
##   vehicle "turn": "cw" | "ccw"    first tap turns 90 degrees (2-cell vehicles)
##   vehicle "key": 0                unlocks group 0 when it leaves
##   vehicle "lock": 0               waits for the key of group 0
##   obstacle {"type": "gate", "group": 0, ...}  opens with the key of group 0

const OBSTACLE_TYPES: Array[String] = ["cone", "box", "gate"]
const TURNS := {"cw": 1, "ccw": -1}
const MAX_GROUPS := 4

var name := ""
var cols := 6
var rows := 6
var mistakes := 3
var hard := false
var vehicles: Array[Dictionary] = [] ## {type, cell: Vector2i, dir: int, [cargo, turn, key, lock]}
var obstacles: Array[Dictionary] = [] ## {type, cell: Vector2i, [group]}
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
		var d := {"type": e.type, "col": e.cell.x, "row": e.cell.y, "dir": GridDir.to_name(e.dir)}
		if e.get("cargo", false):
			d["cargo"] = true
		if e.get("turn", 0) != 0:
			d["turn"] = "cw" if e.turn > 0 else "ccw"
		for field in ["key", "lock"]:
			if e.get(field, -1) >= 0:
				d[field] = e[field]
		v.append(d)
	var o := []
	for e in obstacles:
		var d := {"type": e.type, "col": e.cell.x, "row": e.cell.y}
		if e.has("group"):
			d["group"] = e.group
		o.append(d)
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
		var entry := {"type": type, "cell": Vector2i(int(e.get("col", 0)), int(e.get("row", 0))), "dir": dir}
		if e.get("cargo", false):
			entry["cargo"] = true
		if e.has("turn"):
			if not TURNS.has(e.turn):
				errors.append("vehicle %d: unknown turn '%s'" % [i, e.turn])
			elif VehicleCatalog.cells(type) != 2:
				errors.append("vehicle %d: only 2-cell vehicles can turn" % i)
			else:
				entry["turn"] = TURNS[e.turn]
		for field in ["key", "lock"]:
			if e.has(field):
				entry[field] = _group(e[field], "vehicle %d %s" % [i, field])
		vehicles.append(entry)

	for i in data.get("obstacles", []).size():
		var e: Dictionary = data["obstacles"][i]
		var type := str(e.get("type", "cone"))
		if not type in OBSTACLE_TYPES:
			errors.append("obstacle %d: unknown type '%s'" % [i, type])
			continue
		var entry := {"type": type, "cell": Vector2i(int(e.get("col", 0)), int(e.get("row", 0)))}
		if type == "gate":
			entry["group"] = _group(e.get("group", -1), "gate %d" % i)
		obstacles.append(entry)

	if vehicles.is_empty() and errors.is_empty():
		errors.append("level has no vehicles")
	_check_groups()


func _group(value: Variant, what: String) -> int:
	var g := int(value)
	if g < 0 or g >= MAX_GROUPS:
		errors.append("%s: group must be 0..%d" % [what, MAX_GROUPS - 1])
		return -1
	return g


## Every lock and gate needs exactly one key vehicle, which must not wait for
## its own group.
func _check_groups() -> void:
	var key_count := {}
	for e in vehicles:
		if e.get("key", -1) >= 0:
			key_count[e.key] = key_count.get(e.key, 0) + 1
			if e.get("lock", -1) == e.key:
				errors.append("key vehicle of group %d is locked by its own group" % e.key)
	var used := {}
	for e in vehicles:
		if e.get("lock", -1) >= 0:
			used[e.lock] = true
	for e in obstacles:
		if e.get("group", -1) >= 0:
			used[e.group] = true
	for g in used:
		if key_count.get(g, 0) != 1:
			errors.append("group %d needs exactly one key vehicle, has %d" % [g, key_count.get(g, 0)])
