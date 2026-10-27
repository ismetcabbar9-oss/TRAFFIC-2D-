class_name VehicleState
extends RefCounted
## One vehicle on the grid: identity, footprint and the direction it drives.

var id := -1
var type := ""
var cell := Vector2i.ZERO ## top-left cell of the footprint
var dir := GridDir.UP
var length := 2


func _init(p_id: int, p_type: String, p_cell: Vector2i, p_dir: int, p_length: int) -> void:
	id = p_id
	type = p_type
	cell = p_cell
	dir = p_dir
	length = p_length


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
