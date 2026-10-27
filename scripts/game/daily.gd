class_name Daily
## Daily puzzle and daily gift rules. The puzzle is generated from the date,
## so every player gets the same level on the same day; it is cached in
## user:// once built (generation runs on a worker thread).

const GIFT_REWARDS := [20, 30, 40, 50, 60, 80, 100] ## coins for day 1..7
const GIFT_BONUS_ITEM := "crane" ## extra on day 7
const PUZZLE_ATTEMPTS := 30
const PUZZLE_LEVEL := 11 ## difficulty of a mid-world level (not a hard one)
const MECHANICS := ["", "cargo", "turn", "lock", "gate"]

## Set while the daily puzzle is being played.
static var playing := false
static var level_data: Dictionary = {}
static var world_index := 0 ## world whose look the puzzle borrows

static var _task := -1
static var _result: Dictionary = {}


static func today() -> String:
	return Time.get_date_string_from_system()


static func day_before(day: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(day + "T12:00:00")
	return Time.get_date_string_from_unix_time(unix - 86400)


## Starts building today's puzzle in the background (or loads the cached one).
## Poll `ready()`, then call `start()`.
static func prepare() -> void:
	var day := today()
	var cache := _cache_path(day)
	if FileAccess.file_exists(cache):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache))
		if data is Dictionary and data.has("level"):
			_result = data
			return
	if _task >= 0:
		return
	_result = {}
	_task = WorkerThreadPool.add_task(_build.bind(day), false, "daily puzzle")


static func is_ready() -> bool:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _task < 0 and not _result.is_empty()


## Marks the prepared puzzle as the one to play.
static func start() -> void:
	playing = true
	level_data = _result.level
	world_index = int(_result.world)


static func stop() -> void:
	playing = false


static func _build(day: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["daily", day])
	var w := rng.randi() % MECHANICS.size()
	var spec := LevelGenerator.spec(w, PUZZLE_LEVEL, MECHANICS[w])
	var result := LevelGenerator.generate(spec, ["daily", day], PUZZLE_ATTEMPTS)
	if result.is_empty(): # extremely unlikely; fall back to the plain city rules
		w = 0
		result = LevelGenerator.generate(LevelGenerator.spec(0, PUZZLE_LEVEL, ""), ["daily", day, "city"], PUZZLE_ATTEMPTS)
	var data: Dictionary = result.data
	data["name"] = "Daily %s" % day
	_result = {"day": day, "world": w, "level": data}
	var f := FileAccess.open(_cache_path(day), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_result))


static func _cache_path(day: String) -> String:
	return "user://daily_%s.json" % day
