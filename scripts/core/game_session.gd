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

## Last tap that can be undone: {action, id, previous: VehicleState}, or empty.
var _undoable := {}


func _init(p_level: LevelData) -> void:
	level = p_level
	board = BoardState.from_level(level)
	mistakes_left = level.mistakes


## Handles a tap on a vehicle. Returns the move result, or null if ignored.
func tap(id: int) -> BoardState.MoveResult:
	if state != State.PLAYING or not board.vehicles.has(id):
		return null
	taps += 1
	var result := board.probe(id)
	if result.action != BoardState.Action.LOCKED:
		_undoable = {}
		if result.action != BoardState.Action.EXIT:
			_undoable = {"action": result.action, "id": id, "previous": (board.vehicles[id] as VehicleState).duplicate()}
	board.apply(id, result)
	match result.action:
		BoardState.Action.EXIT:
			vehicle_exited.emit(id, result)
			if board.is_cleared():
				state = State.WON
				won.emit()
		BoardState.Action.ADVANCE:
			vehicle_advanced.emit(id, result)
		BoardState.Action.TURN:
			vehicle_turned.emit(id, result)
		BoardState.Action.LOCKED:
			vehicle_locked.emit(id)
		BoardState.Action.CRASH:
			mistakes_left -= 1
			crashes += 1
			vehicle_crashed.emit(id, result)
			mistakes_changed.emit(mistakes_left)
			if mistakes_left <= 0:
				state = State.LOST
				lost.emit()
	return result


## True when no order of taps can clear the board any more (a pull-forward or
## turn boxed something in). Only possible in levels with those mechanics.
func is_deadlocked() -> bool:
	return state == State.PLAYING and not LevelSolver.solve_board(board).solvable


## True when the last tap was a crash, pull-forward or turn (see undo).
func can_undo() -> bool:
	return not _undoable.is_empty() and state != State.WON


## Takes back the last crash (the wrong move is refunded, a lost game resumes)
## or the last pull-forward / turn (the vehicle goes back). Returns the
## undone action, or -1 if there was nothing to undo.
func undo() -> int:
	if not can_undo():
		return -1
	var entry := _undoable
	_undoable = {}
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
	if board.is_cleared():
		state = State.WON
		won.emit()
	return result


## Like is_deadlocked, but also for a lost game: true when no order of taps
## can clear what is left, so extra moves would not help.
func is_deadlocked_ignoring_moves() -> bool:
	return not LevelSolver.solve_board(board).solvable


## Grants extra wrong moves (e.g. reward ad) and resumes a lost game.
func add_mistakes(amount: int) -> void:
	mistakes_left += amount
	if state == State.LOST and mistakes_left > 0:
		state = State.PLAYING
	mistakes_changed.emit(mistakes_left)
