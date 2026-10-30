class_name GameSession
extends RefCounted
## Rules of one play-through of a level: taps, wrong-move allowance, win/lose.
## Holds no visuals; the view listens to the signals and animates.

signal vehicle_exited(id: int, result: BoardState.MoveResult)
signal vehicle_crashed(id: int, result: BoardState.MoveResult)
signal vehicle_advanced(id: int, result: BoardState.MoveResult) ## cargo pulled forward
signal vehicle_turned(id: int, result: BoardState.MoveResult)
signal vehicle_locked(id: int) ## tapped while still locked; costs nothing
signal vehicle_lifted(id: int, result: BoardState.MoveResult) ## crane rescue
signal vehicle_restored(id: int) ## undo of a pull-forward or turn
signal vehicle_fell(id: int, result: BoardState.MoveResult) ## drove into a pit
signal exploded(id: int, cell: Vector2i) ## tanker crash or bomb at zero: the level is lost
signal bombs_ticked ## bomb counters changed (a tap, or an undo)
signal vehicle_added(id: int) ## endless mode: a new car arrived
signal rewound ## the board went back to before the fatal tap (rewind rescue)
signal mistakes_changed(left: int)
signal won
signal lost

enum State { PLAYING, WON, LOST }

var level: LevelData
var board: BoardState
var mistakes_left := 0
var state := State.PLAYING
var taps := 0
var crashes := 0 ## crashes that still count (undo takes one back)
var falls := 0 ## vehicles lost in pits
var lose_reason := "" ## "" (out of moves), "explosion" (tanker), "bomb" or "full" (endless)
var endless := false ## endless mode: an empty board is not a win, cars keep arriving

## Last tap that can be undone: {action, id, previous: VehicleState}, or empty.
var _undoable := {}
var _next_id := 0 ## endless mode: ids are never reused (views are keyed by id)
var _before := {} ## the game as it was before the last tap (see rewind)


func _init(p_level: LevelData) -> void:
	level = p_level
	board = BoardState.from_level(level)
	mistakes_left = level.mistakes
	_next_id = level.vehicles.size()


## Handles a tap on a vehicle. Returns the move result, or null if ignored.
func tap(id: int) -> BoardState.MoveResult:
	if state != State.PLAYING or not board.vehicles.has(id):
		return null
	taps += 1
	var result := board.probe(id)
	if result.action != BoardState.Action.LOCKED:
		_before = {"board": board.clone(), "mistakes": mistakes_left, "crashes": crashes, "falls": falls}
		_undoable = {}
		if result.action != BoardState.Action.EXIT and result.action != BoardState.Action.FALL and not result.explodes:
			_undoable = {"action": result.action, "id": id, "previous": (board.vehicles[id] as VehicleState).duplicate(),
				"bombs": board.bomb_counts()}
	board.apply(id, result)
	match result.action:
		BoardState.Action.EXIT:
			vehicle_exited.emit(id, result)
			_check_cleared()
		BoardState.Action.ADVANCE:
			vehicle_advanced.emit(id, result)
		BoardState.Action.TURN:
			vehicle_turned.emit(id, result)
		BoardState.Action.LOCKED:
			vehicle_locked.emit(id)
		BoardState.Action.FALL:
			if result.explodes:
				vehicle_fell.emit(id, result)
				_explode("explosion", id, result.contact_cell)
				return result
			mistakes_left -= 1
			falls += 1
			vehicle_fell.emit(id, result)
			mistakes_changed.emit(mistakes_left)
			if _check_cleared():
				pass
			elif mistakes_left <= 0:
				state = State.LOST
				lost.emit()
		BoardState.Action.CRASH:
			crashes += 1
			vehicle_crashed.emit(id, result)
			if result.explodes:
				_explode("explosion", id, result.contact_cell)
				return result
			mistakes_left -= 1
			mistakes_changed.emit(mistakes_left)
			if mistakes_left <= 0:
				state = State.LOST
				lost.emit()
	if result.action != BoardState.Action.LOCKED and state == State.PLAYING and board.has_bombs():
		var boom := board.tick_bombs()
		bombs_ticked.emit()
		if boom >= 0:
			var bomb: VehicleState = board.vehicles[boom]
			_explode("bomb", boom, bomb.cells()[bomb.length / 2])
	return result


## Wins when the board is empty (never in endless mode). True if it won.
func _check_cleared() -> bool:
	if endless or not board.is_cleared():
		return false
	state = State.WON
	won.emit()
	return true


## True after an explosion while the position before the fatal tap is known.
func can_rewind() -> bool:
	return state == State.LOST and lose_reason in ["explosion", "bomb"] and not _before.is_empty()


## Rewind rescue: back to just before the tap that blew up, and play on.
func rewind() -> bool:
	if not can_rewind():
		return false
	board = _before.board
	mistakes_left = _before.mistakes
	crashes = _before.crashes
	falls = _before.falls
	_before = {}
	_undoable = {}
	lose_reason = ""
	state = State.PLAYING
	rewound.emit()
	mistakes_changed.emit(mistakes_left)
	return true


## Adds `amount` taps to a parked bomb's countdown (bomb time rescue).
func add_bomb_time(id: int, amount: int) -> void:
	if not board.vehicles.has(id) or (board.vehicles[id] as VehicleState).bomb <= 0:
		return
	(board.vehicles[id] as VehicleState).bomb += amount
	bombs_ticked.emit()


## Endless mode: back to playing after a full lot (the rush continue).
func resume() -> void:
	if state != State.LOST or lose_reason in ["explosion", "bomb"]:
		return
	lose_reason = ""
	state = State.PLAYING


## Endless mode: a new vehicle drives onto the board. Returns its id, or -1
## if it does not fit.
func add_vehicle(entry: Dictionary) -> int:
	var id := 0
	for k in board.vehicles:
		id = maxi(id, k + 1)
	id = maxi(id, _next_id)
	var v := VehicleState.new(id, entry.type, entry.cell, entry.dir, VehicleCatalog.cells(entry.type))
	v.cargo = entry.get("cargo", false)
	v.bomb = entry.get("bomb", 0)
	if state != State.PLAYING or not board.add_vehicle(v):
		return -1
	_next_id = id + 1
	vehicle_added.emit(id)
	return id


## Ends the game from outside the rules (endless mode: the lot is full).
func end(reason: String) -> void:
	if state != State.PLAYING:
		return
	_undoable = {}
	lose_reason = reason
	state = State.LOST
	lost.emit()


func _explode(reason: String, id: int, cell: Vector2i) -> void:
	_undoable = {}
	lose_reason = reason
	state = State.LOST
	exploded.emit(id, cell)
	lost.emit()


## True when no order of taps can clear the board any more (a pull-forward or
## turn boxed something in). Only possible in levels with those mechanics.
func is_deadlocked() -> bool:
	return state == State.PLAYING and not LevelSolver.solve_board(board, fall_budget()).solvable


## Pits the player can still afford to drive into (keeping one move).
func fall_budget() -> int:
	return maxi(mistakes_left - 1, 0)


## True when the last tap was a crash, pull-forward or turn (see undo).
func can_undo() -> bool:
	return not _undoable.is_empty() and state != State.WON and lose_reason == ""


## Takes back the last crash (the wrong move is refunded, a lost game resumes)
## or the last pull-forward / turn (the vehicle goes back). Returns the
## undone action, or -1 if there was nothing to undo.
func undo() -> int:
	if not can_undo():
		return -1
	var entry := _undoable
	_undoable = {}
	if not entry.bombs.is_empty():
		board.set_bomb_counts(entry.bombs)
		bombs_ticked.emit()
	match entry.action:
		BoardState.Action.CRASH:
			crashes -= 1
			add_mistakes(1)
		_:
			board.restore_vehicle(entry.previous)
			vehicle_restored.emit(entry.id)
	return entry.action


## Crane rescue: lifts a vehicle straight out of the lot, whatever blocks it.
func lift(id: int) -> BoardState.MoveResult:
	if state != State.PLAYING or not board.vehicles.has(id):
		return null
	_undoable = {}
	var result := BoardState.MoveResult.new()
	result.action = BoardState.Action.EXIT
	result.free = true
	result.opened = board.remove_vehicle(id)
	vehicle_lifted.emit(id, result)
	_check_cleared()
	return result


## Like is_deadlocked, but also for a lost game: true when no order of taps
## can clear what is left, so extra moves would not help.
func is_deadlocked_ignoring_moves() -> bool:
	return lose_reason != "" or not LevelSolver.solve_board(board).solvable


## Grants extra wrong moves (e.g. reward ad) and resumes a lost game.
func add_mistakes(amount: int) -> void:
	mistakes_left += amount
	if state == State.LOST and mistakes_left > 0 and lose_reason == "":
		state = State.PLAYING
	mistakes_changed.emit(mistakes_left)
