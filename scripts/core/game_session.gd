class_name GameSession
extends RefCounted
## Rules of one play-through of a level: taps, wrong-move allowance, win/lose.
## Holds no visuals; the view listens to the signals and animates.

signal vehicle_exited(id: int, result: BoardState.MoveResult)
signal vehicle_crashed(id: int, result: BoardState.MoveResult)
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
	if result.free:
		board.remove_vehicle(id)
		vehicle_exited.emit(id, result)
		if board.is_cleared():
			state = State.WON
			won.emit()
	else:
		mistakes_left -= 1
		vehicle_crashed.emit(id, result)
		mistakes_changed.emit(mistakes_left)
		if mistakes_left <= 0:
			state = State.LOST
			lost.emit()
	return result


## Grants extra wrong moves (e.g. reward ad) and resumes a lost game.
func add_mistakes(amount: int) -> void:
	mistakes_left += amount
	if state == State.LOST and mistakes_left > 0:
		state = State.PLAYING
	mistakes_changed.emit(mistakes_left)
