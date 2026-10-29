class_name Rush
## "Rush hour" endless mode rules: a 7x8 lot starts with a few cars and new
## ones keep arriving, faster and faster. A new car only lands where the lot
## stays clearable; when there is no such place the lot is full and the run is
## over (as it is after the last life or an explosion). Every car out scores,
## more in a combo and a bonus when it leaves soon after arriving. Cargo
## vans, fuel tankers and bombs join in as the run goes on.

const COLS := 7
const ROWS := 8
const START_CARS := 8
const LIVES := 3
const FIRST_INTERVAL := 6.0 ## seconds between arrivals at the start
const LAST_INTERVAL := 2.0 ## ... and once the run is in full swing
const RAMP := 60 ## arrivals until the fastest pace
const WARNING := 1.0 ## seconds the landing spot is marked before a car drops
const CAR_POINTS := 10
const FAST_BONUS := 5
const FAST_TIME := 4.0 ## a car out within this many seconds of landing earns the bonus
const CARGO_FROM := 10 ## arrivals before the first cargo van can come
const TANKER_FROM := 20
const BOMB_FROM := 35
const BOMB_SLACK := 4
const UNLOCK := [0, 9] ## clear City level 10 to unlock the mode
const TRIES := 40
const SMALL := ["sedan", "sedan_sports", "hatchback", "suv", "suv_luxury", "taxi", "police", "van", "pickup"]
const LARGE := ["ambulance", "delivery", "firetruck", "bus"]

## Set while a run is being played.
static var playing := false
static var world_index := 0 ## world whose look the run borrows


static func unlocked(progress: Node) -> bool:
	return progress.level_stars(UNLOCK[0], UNLOCK[1]) > 0


static func start(world: int) -> void:
	playing = true
	world_index = world


static func stop() -> void:
	playing = false


## Seconds until the next car after `arrived` cars.
static func interval(arrived: int) -> float:
	return lerpf(FIRST_INTERVAL, LAST_INTERVAL, clampf(float(arrived) / RAMP, 0.0, 1.0))


## Points for a car out: 10 per car times the combo, plus the quick bonus.
static func points(combo: int, quick: bool) -> int:
	return CAR_POINTS * maxi(combo, 1) + (FAST_BONUS if quick else 0)


## The opening lot: an empty 7x8 board with START_CARS placed.
static func start_level(rng: RandomNumberGenerator) -> LevelData:
	var level := LevelData.from_dict({"cols": COLS, "rows": ROWS, "mistakes": LIVES,
		"vehicles": [{"type": "sedan", "col": 0, "row": 0, "dir": "up"}]})
	level.vehicles.clear()
	var board := BoardState.from_level(level)
	for k in START_CARS:
		var entry := pick(board, rng, 0)
		if entry.is_empty():
			break
		var v := VehicleState.new(level.vehicles.size(), entry.type, entry.cell, entry.dir, VehicleCatalog.cells(entry.type))
		v.cargo = entry.get("cargo", false)
		board.add_vehicle(v)
		level.vehicles.append(entry)
	return level


## A new car for `board` after `arrived` arrivals: {type, cell, dir, [cargo],
## [bomb]}, or {} when the lot is full (nowhere it fits and keeps the lot
## clearable). If the board is already stuck, any spot that fits will do.
static func pick(board: BoardState, rng: RandomNumberGenerator, arrived: int) -> Dictionary:
	var solvable_now := LevelSolver.solve_board(board, 0).solvable
	var fallback := {}
	var next_id := 0
	for id in board.vehicles:
		next_id = maxi(next_id, id + 1)
	for attempt in TRIES:
		var entry := _random_entry(rng, arrived)
		var v := VehicleState.new(next_id, entry.type, entry.cell, entry.dir, VehicleCatalog.cells(entry.type))
		v.cargo = entry.get("cargo", false)
		if not board.fits(v):
			continue
		var trial := board.clone()
		trial.add_vehicle(v)
		if fallback.is_empty():
			fallback = entry
		if entry.has("bomb"):
			v.bomb = 99
			var report := LevelSolver.solve_board(trial, 0)
			if not report.solvable:
				continue
			v.bomb = report.order.rfind(next_id) + 1 + BOMB_SLACK
			entry.bomb = v.bomb
		if LevelSolver.solve_board(trial, 0).solvable:
			return entry
	return fallback if not solvable_now else {}


static func _random_entry(rng: RandomNumberGenerator, arrived: int) -> Dictionary:
	var type: String = SMALL[rng.randi() % SMALL.size()]
	var roll := rng.randf()
	if arrived >= TANKER_FROM and roll < 0.1:
		type = "tanker"
	elif roll < 0.25:
		type = LARGE[rng.randi() % LARGE.size()]
	var dir := rng.randi() % 4
	var length := VehicleCatalog.cells(type)
	var span := Vector2i(length - 1, 0) if GridDir.is_horizontal(dir) else Vector2i(0, length - 1)
	var cell := Vector2i(rng.randi_range(0, COLS - 1 - span.x), rng.randi_range(0, ROWS - 1 - span.y))
	var entry := {"type": type, "cell": cell, "dir": dir}
	if arrived >= CARGO_FROM and type in ["pickup", "van", "delivery"] and rng.randf() < 0.35:
		entry["cargo"] = true
	elif arrived >= BOMB_FROM and type != "tanker" and rng.randf() < 0.08:
		entry["bomb"] = 1
	return entry
