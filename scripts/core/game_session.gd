class_name GameSession
extends RefCounted
## Rules of one play-through of a level: taps, wrong-move allowance, win/lose.
## Holds no visuals; the view listens to the signals and animates.

signal vehicle_exited(id: int, result: BoardState.MoveResult)
signal vehicle_crashed(id: int, result: BoardState.MoveResult)
signal vehicle_advanced(id: int, result: BoardState.MoveResult) ## cargo pulled forward
signal vehicle_turned(id: int, result: BoardState.MoveResult)
signal vehicle_locked(id: int) ## tapped while still locked; costs nothing
signal mistakes_changed(left: int)
signal won
signal lost

enum State { PLAYING, WON, LOST }

var level: LevelData
var board: BoardState
var mistakes_left := 0
var state := State.PLAYING
var taps := 0


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


## Grants extra wrong moves (e.g. reward ad) and resumes a lost game.
func add_mistakes(amount: int) -> void:
	mistakes_left += amount
	if state == State.LOST and mistakes_left > 0:
		state = State.PLAYING
	mistakes_changed.emit(mistakes_left)
