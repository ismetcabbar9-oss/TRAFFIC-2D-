class_name BoardState
extends RefCounted
## Occupancy of the grid and the movement rule: a tapped vehicle drives straight
## ahead; it leaves the lot if every cell in front of it is empty, otherwise it
## hits the first thing in its way.

const EMPTY := -1
const OBSTACLE := -2

## Outcome of trying to move one vehicle.
class MoveResult:
	var free := false
	var blocker := EMPTY ## vehicle id, or OBSTACLE, when blocked
	var steps := 0 ## empty cells driven before contact (or before the lot edge)
	var contact_cell := Vector2i.ZERO ## cell of the blocker when blocked

var cols := 0
var rows := 0
var vehicles := {} ## id -> VehicleState
var errors: PackedStringArray = [] ## layout problems (overlap, out of bounds)

var _grid := PackedInt32Array()


static func from_level(level: LevelData) -> BoardState:
	var board := BoardState.new()
	board.cols = level.cols
	board.rows = level.rows
	board._grid.resize(level.cols * level.rows)
	board._grid.fill(EMPTY)
	for e in level.obstacles:
		board._place(e.cell, OBSTACLE, "obstacle at %s" % e.cell)
	for i in level.vehicles.size():
		var e: Dictionary = level.vehicles[i]
		var v := VehicleState.new(i, e.type, e.cell, e.dir, VehicleCatalog.cells(e.type))
		board.vehicles[i] = v
		for c in v.cells():
			board._place(c, i, "vehicle %d (%s) at %s" % [i, v.type, c])
	return board


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func at(c: Vector2i) -> int:
	return _grid[c.y * cols + c.x] if in_bounds(c) else EMPTY


func probe(id: int) -> MoveResult:
	var v: VehicleState = vehicles[id]
	var forward := GridDir.to_vector(v.dir)
	var result := MoveResult.new()
	var c := v.head() + forward
	while in_bounds(c):
		var occupant := at(c)
		if occupant != EMPTY:
			result.blocker = occupant
			result.contact_cell = c
			return result
		result.steps += 1
		c += forward
	result.free = true
	return result


## Removes a vehicle that has driven out of the lot.
func remove_vehicle(id: int) -> void:
	var v: VehicleState = vehicles[id]
	for c in v.cells():
		if at(c) == id:
			_grid[c.y * cols + c.x] = EMPTY
	vehicles.erase(id)


func free_vehicles() -> Array[int]:
	var result: Array[int] = []
	for id in vehicles:
		if probe(id).free:
			result.append(id)
	result.sort()
	return result


func is_cleared() -> bool:
	return vehicles.is_empty()


func _place(c: Vector2i, value: int, what: String) -> void:
	if not in_bounds(c):
		errors.append("%s is outside the %dx%d board" % [what, cols, rows])
		return
	var i := c.y * cols + c.x
	if _grid[i] != EMPTY:
		errors.append("%s overlaps another piece" % what)
		return
	_grid[i] = value
