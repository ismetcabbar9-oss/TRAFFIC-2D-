extends Node
## Autoload "Progress": unlocked/completed levels and player settings, saved to
## user://progress.json. Also remembers which level the game scene should open.

const SAVE_PATH := "user://progress.json"
## Car speed settings: [label, multiplier].
const SPEEDS := [["Yavaş", 0.7], ["Normal", 1.0], ["Hızlı", 1.35], ["Çok Hızlı", 1.7]]

var unlocked := 1 ## number of levels the player may open
var completed := {} ## level index -> true
var sound_on := true
var vibration_on := true
var speed_level := 1 ## index into SPEEDS
var current_level := 0 ## index of the level to play next


func _ready() -> void:
	_load()
	_apply_settings()


func is_unlocked(index: int) -> bool:
	return index < unlocked


func is_completed(index: int) -> bool:
	return completed.has(index)


## Records a win and unlocks the following level.
func complete(index: int) -> void:
	completed[index] = true
	unlocked = clampi(maxi(unlocked, index + 2), 1, LevelCatalog.count())
	save()


func has_next(index: int) -> bool:
	return index + 1 < LevelCatalog.count()


func set_sound(on: bool) -> void:
	sound_on = on
	_apply_settings()
	save()


## Steps to the next speed setting (wraps around).
func cycle_speed() -> void:
	speed_level = (speed_level + 1) % SPEEDS.size()
	_apply_settings()
	save()


func speed_label() -> String:
	return SPEEDS[speed_level][0]


func set_vibration(on: bool) -> void:
	vibration_on = on
	_apply_settings()
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify({
		"unlocked": unlocked,
		"completed": completed.keys(),
		"sound": sound_on,
		"vibration": vibration_on,
		"speed": speed_level,
	}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	unlocked = clampi(int(data.get("unlocked", 1)), 1, maxi(LevelCatalog.count(), 1))
	completed.clear()
	for i in data.get("completed", []):
		completed[int(i)] = true
	sound_on = bool(data.get("sound", true))
	vibration_on = bool(data.get("vibration", true))
	speed_level = clampi(int(data.get("speed", 1)), 0, SPEEDS.size() - 1)
	current_level = mini(unlocked - 1, LevelCatalog.count() - 1)


func _apply_settings() -> void:
	Sfx.enabled = sound_on
	Haptics.enabled = vibration_on
	VehicleView.speed_scale = SPEEDS[speed_level][1]
