class_name GridDir
## Four movement directions on the grid. Rows grow toward the camera (+Z).

enum { UP, RIGHT, DOWN, LEFT }

const VECTORS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

const NAMES: Array[String] = ["up", "right", "down", "left"]


static func to_vector(dir: int) -> Vector2i:
	return VECTORS[dir]


static func is_horizontal(dir: int) -> bool:
	return dir == RIGHT or dir == LEFT


static func opposite(dir: int) -> int:
	return (dir + 2) % 4


## Returns -1 for an unknown name.
static func from_name(dir_name: String) -> int:
	return NAMES.find(dir_name.to_lower())


static func to_name(dir: int) -> String:
	return NAMES[dir]


## Yaw (radians) that turns a +Z-facing model to face `dir` on the XZ plane.
static func to_yaw(dir: int) -> float:
	var v := VECTORS[dir]
	return atan2(float(v.x), float(v.y))
