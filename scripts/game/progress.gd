extends Node
## Autoload "Progress": unlocked/completed levels and player settings, saved to
## user://progress.json. Also remembers which level the game scene should open.

const SAVE_PATH := "user://progress.json"

var unlocked := 1 ## number of levels the player may open
var completed := {} ## level index -> true
var sound_on := true
var vibration_on := true
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
	current_level = mini(unlocked - 1, LevelCatalog.count() - 1)


func _apply_settings() -> void:
	Sfx.enabled = sound_on
	Haptics.enabled = vibration_on
