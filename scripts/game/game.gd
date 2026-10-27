extends Node3D
## Game scene root. Stage 1: shows a static demo layout to tune visuals.

## Temporary demo layout: [type, col, row, direction]. Replaced by level files later.
const DEMO_LAYOUT := [
	["sedan", 0, 0, GridDir.RIGHT],
	["garbage", 2, 0, GridDir.DOWN],
	["taxi", 3, 0, GridDir.UP],
	["suv", 4, 0, GridDir.LEFT],
	["police", 0, 1, GridDir.DOWN],
	["hatchback", 1, 1, GridDir.UP],
	["sedan_sports", 4, 1, GridDir.LEFT],
	["van", 3, 2, GridDir.RIGHT],
	["ambulance", 5, 2, GridDir.DOWN],
	["firetruck", 0, 3, GridDir.RIGHT],
	["pickup", 3, 3, GridDir.UP],
	["suv_luxury", 4, 3, GridDir.DOWN],
	["taxi", 0, 4, GridDir.DOWN],
	["sedan", 1, 4, GridDir.LEFT],
	["delivery", 1, 5, GridDir.RIGHT],
	["hatchback", 4, 5, GridDir.RIGHT],
]

@onready var board: BoardView = $Board
@onready var vehicles: Node3D = $Vehicles
@onready var camera: BoardCamera = $Camera


func _ready() -> void:
	board.build(6, 6)
	for entry in DEMO_LAYOUT:
		var v := VehicleView.new()
		vehicles.add_child(v)
		v.setup(board, entry[0], Vector2i(entry[1], entry[2]), entry[3])
	camera.frame_board(board.view_half_extents())
