class_name BoardState
extends RefCounted
## Occupancy of the grid and the movement rules.
##
## A tapped vehicle drives straight ahead; it leaves the lot if every cell in
## front of it is empty, otherwise it hits the first thing in its way. World
## mechanics change what a tap does:
## - cargo: the first tap only pulls forward one cell (or out, at the edge);
## - turn: the first tap swings the nose 90 degrees around the rear cell;
## - lock: nothing happens until the key vehicle of its group has left;
## - gate: a barrier cell that opens when the key vehicle of its group leaves.

const EMPTY := -1
const OBSTACLE := -2
const GATE := -3

enum Action { EXIT, CRASH, ADVANCE, TURN, LOCKED }

## What one tap does (see probe) and, after apply, what changed.
class MoveResult:
	var action := Action.CRASH
	var free := false ## true when the vehicle leaves the lot
	var blocker := EMPTY ## vehicle id, OBSTACLE or GATE, when it crashes
	var steps := 0 ## empty cells driven before contact (or before the lot edge)
	var contact_cell := Vector2i.ZERO ## cell of the blocker when it crashes
	var turning := false ## the crash happened while swinging round
	var opened: Array[Vector2i] = [] ## gate cells opened by this exit

var cols := 0
var rows := 0
var vehicles := {} ## id -> VehicleState
var gates := {} ## cell -> group of a closed gate
var keys := {} ## group -> id of the vehicle that unlocks it
var errors: PackedStringArray = [] ## layout problems (overlap, out of bounds)

var _grid := PackedInt32Array()


static func from_level(level: LevelData) -> BoardState:
	var board := BoardState.new()
	board.cols = level.cols
	board.rows = level.rows
	board._grid.resize(level.cols * level.rows)
	board._grid.fill(EMPTY)
	for e in level.obstacles:
		if e.type == "gate":
			board._place(e.cell, GATE, "gate at %s" % e.cell)
			board.gates[e.cell] = e.group
		else:
			board._place(e.cell, OBSTACLE, "obstacle at %s" % e.cell)
	for i in level.vehicles.size():
		var e: Dictionary = level.vehicles[i]
		var v := VehicleState.new(i, e.type, e.cell, e.dir, VehicleCatalog.cells(e.type))
		v.cargo = e.get("cargo", false)
		v.turn = e.get("turn", 0)
		v.key = e.get("key", -1)
		v.lock = e.get("lock", -1)
		board.vehicles[i] = v
		if v.key >= 0:
			board.keys[v.key] = i
		for c in v.cells():
			board._place(c, i, "vehicle %d (%s) at %s" % [i, v.type, c])
		if v.turn != 0 and not board.in_bounds(v.turn_cell()):
			board.errors.append("vehicle %d cannot turn: its nose would leave the board" % i)
	return board


func clone() -> BoardState:
	var b := BoardState.new()
	b.cols = cols
	b.rows = rows
	for id in vehicles:
		b.vehicles[id] = (vehicles[id] as VehicleState).duplicate()
	b.gates = gates.duplicate()
	b.keys = keys.duplicate()
	b._grid = _grid.duplicate()
	return b


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func at(c: Vector2i) -> int:
	return _grid[c.y * cols + c.x] if in_bounds(c) else EMPTY


## True while the key vehicle of this vehicle's lock group is still parked.
func is_locked(id: int) -> bool:
	var v: VehicleState = vehicles[id]
	return v.lock >= 0 and vehicles.has(keys.get(v.lock, -1))


## What tapping `id` would do now. Does not change the board (see apply).
func probe(id: int) -> MoveResult:
	var v: VehicleState = vehicles[id]
	var result := MoveResult.new()
	if is_locked(id):
		result.action = Action.LOCKED
		return result
	if v.turn != 0:
		var nose := v.turn_cell()
		if at(nose) == EMPTY:
			result.action = Action.TURN
		else:
			result.blocker = at(nose)
			result.contact_cell = nose
			result.turning = true
		return result
	var forward := GridDir.to_vector(v.dir)
	var c := v.head() + forward
	while in_bounds(c):
		var occupant := at(c)
		if occupant != EMPTY:
			result.blocker = occupant
			result.contact_cell = c
			return result
		result.steps += 1
		if v.cargo:
			result.action = Action.ADVANCE
			return result
		c += forward
	result.action = Action.EXIT
	result.free = true
	return result


## Carries out a probed move (crashes and locked taps change nothing).
func apply(id: int, result: MoveResult) -> void:
	var v: VehicleState = vehicles[id]
	match result.action:
		Action.EXIT:
			result.opened = remove_vehicle(id)
		Action.ADVANCE:
			_set_cells(v, EMPTY)
			v.cell += GridDir.to_vector(v.dir)
			v.cargo = false
			_set_cells(v, id)
		Action.TURN:
			var tail := v.tail()
			var nose := v.turn_cell()
			_set_cells(v, EMPTY)
			v.dir = v.turned_dir()
			v.turn = 0
			v.cell = Vector2i(mini(tail.x, nose.x), mini(tail.y, nose.y))
			_set_cells(v, id)


## Puts a vehicle back as it was before a pull-forward or turn (undo).
func restore_vehicle(previous: VehicleState) -> void:
	_set_cells(vehicles[previous.id], EMPTY)
	var v := previous.duplicate()
	vehicles[v.id] = v
	_set_cells(v, v.id)


## Removes a vehicle that has driven out of the lot and opens the gates it
## holds the key to. Returns the opened gate cells.
func remove_vehicle(id: int) -> Array[Vector2i]:
	var v: VehicleState = vehicles[id]
	for c in v.cells():
		if at(c) == id:
			_grid[c.y * cols + c.x] = EMPTY
	vehicles.erase(id)
	var opened: Array[Vector2i] = []
	if v.key >= 0:
		for c in gates.keys():
			if gates[c] == v.key:
				opened.append(c)
				gates.erase(c)
				_grid[c.y * cols + c.x] = EMPTY
	return opened


## Taps needed for `id` to leave right now without any other vehicle moving
## (0 if it cannot). Cargo and turning vehicles need two.
func taps_to_leave(id: int) -> int:
	var v: VehicleState = vehicles[id]
	if is_locked(id):
		return 0
	if v.turn != 0:
		var nose := v.turn_cell()
		return 2 if at(nose) == EMPTY and _clear_ahead(nose, v.turned_dir()) else 0
	if not _clear_ahead(v.head(), v.dir):
		return 0
	return 2 if v.cargo and in_bounds(v.head() + GridDir.to_vector(v.dir)) else 1


## Vehicles a single tap sends out of the lot.
func free_vehicles() -> Array[int]:
	var result: Array[int] = []
	for id in vehicles:
		if probe(id).free:
			result.append(id)
	result.sort()
	return result


func is_cleared() -> bool:
	return vehicles.is_empty()


## Compact description of the position, for the solver's memo.
func state_key() -> String:
	var ids := vehicles.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var v: VehicleState = vehicles[id]
		parts.append("%d:%d,%d,%d%s%d" % [id, v.cell.x, v.cell.y, v.dir, "c" if v.cargo else "", v.turn])
	return " ".join(parts)


func _clear_ahead(from: Vector2i, dir: int) -> bool:
	var forward := GridDir.to_vector(dir)
	var c := from + forward
	while in_bounds(c):
		if at(c) != EMPTY:
			return false
		c += forward
	return true


func _set_cells(v: VehicleState, value: int) -> void:
	for c in v.cells():
		_grid[c.y * cols + c.x] = value


func _place(c: Vector2i, value: int, what: String) -> void:
	if not in_bounds(c):
		errors.append("%s is outside the %dx%d board" % [what, cols, rows])
		return
	var i := c.y * cols + c.x
	if _grid[i] != EMPTY:
		errors.append("%s overlaps another piece" % what)
		return
	_grid[i] = value
