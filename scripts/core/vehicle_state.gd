class_name VehicleState
extends RefCounted
## One vehicle on the grid: identity, footprint, the direction it drives and
## the world mechanics it carries (cargo, turn, key, lock).

var id := -1
var type := ""
var cell := Vector2i.ZERO ## top-left cell of the footprint
var dir := GridDir.UP
var length := 2
var cargo := false ## loaded: a tap only pulls it forward one cell, then it drives normally
var turn := 0 ## turn still to make: 1 = clockwise, -1 = counter-clockwise, 0 = none
var key := -1 ## group it unlocks (locked cars, gates) once it has left
var lock := -1 ## group whose key vehicle has to leave before this one can move


func _init(p_id: int, p_type: String, p_cell: Vector2i, p_dir: int, p_length: int) -> void:
	id = p_id
	type = p_type
	cell = p_cell
	dir = p_dir
	length = p_length


func duplicate() -> VehicleState:
	var v := VehicleState.new(id, type, cell, dir, length)
	v.cargo = cargo
	v.turn = turn
	v.key = key
	v.lock = lock
	return v


## All cells covered by the vehicle.
func cells() -> Array[Vector2i]:
	var step := Vector2i(1, 0) if GridDir.is_horizontal(dir) else Vector2i(0, 1)
	var result: Array[Vector2i] = []
	for i in length:
		result.append(cell + step * i)
	return result


## Cell at the front bumper.
func head() -> Vector2i:
	var forward := GridDir.to_vector(dir)
	if forward.x > 0 or forward.y > 0:
		return cells()[length - 1]
	return cell


## Cell at the rear bumper (the pivot when turning).
func tail() -> Vector2i:
	return head() - GridDir.to_vector(dir) * (length - 1)


## Direction after the pending turn (the current one if there is none).
func turned_dir() -> int:
	return (dir + turn + 4) % 4


## Cell the nose swings into when turning: next to the tail, in the new direction.
func turn_cell() -> Vector2i:
	return tail() + GridDir.to_vector(turned_dir())
