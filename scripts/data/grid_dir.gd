class_name GridDir
## Four movement directions on the grid. Rows grow toward the camera (+Z).

enum { UP, RIGHT, DOWN, LEFT }

const VECTORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]


static func to_vector(dir: int) -> Vector2i:
	return VECTORS[dir]


static func is_horizontal(dir: int) -> bool:
	return dir == RIGHT or dir == LEFT


## Yaw (radians) that turns a +Z-facing model to face `dir` on the XZ plane.
static func to_yaw(dir: int) -> float:
	var v := VECTORS[dir]
	return atan2(float(v.x), float(v.y))
