extends Node
## Autoload "Progress": everything the player keeps between sessions (coins,
## stars and records per level, rescue inventory, purchases, settings), saved
## to user://progress.json. Also remembers which level the game should open.

const SAVE_PATH := "user://progress.json"
const SAVE_VERSION := 2
## Car speed settings: [translation key, multiplier].
const SPEEDS := [["SPEED_SLOW", 0.7], ["SPEED_NORMAL", 1.0], ["SPEED_FAST", 1.35], ["SPEED_VERY_FAST", 1.7]]
const LANGUAGES := ["auto", "en", "tr"]

signal coins_changed(total: int)

var coins := 0
var levels := {} ## "world:level" -> {stars, time (s, -1 = unknown), combo}
var inventory := {} ## rescue name -> count (used from phase 3)
var ad_free := false ## lifetime ad-free purchase (phase 4)
var tutorial_seen := false
var tips_seen: Array = [] ## mechanic tip cards already shown

var sound_on := true
var music_on := true
var vibration_on := true
var speed_level := 1 ## index into SPEEDS
var language := "auto" ## one of LANGUAGES

var current_world := 0
var current_level := 0


func _ready() -> void:
	_load()
	_apply_settings()


# --- Levels and worlds -------------------------------------------------------

func level_stars(world: int, level: int) -> int:
	return int(levels.get(_key(world, level), {}).get("stars", 0))


func level_record(world: int, level: int) -> Dictionary:
	return levels.get(_key(world, level), {})


func is_level_unlocked(world: int, level: int) -> bool:
	return is_world_unlocked(world) and (level == 0 or level_stars(world, level - 1) > 0)


func is_world_unlocked(world: int) -> bool:
	return LevelCatalog.level_count(world) > 0 \
			and total_stars() >= int(LevelCatalog.world(world).stars_required)


func world_stars(world: int) -> int:
	var sum := 0
	for i in LevelCatalog.level_count(world):
		sum += level_stars(world, i)
	return sum


func total_stars() -> int:
	var sum := 0
	for record in levels.values():
		sum += int(record.get("stars", 0))
	return sum


## First level of `world` the player has not cleared yet (or the last one).
func next_open_level(world: int) -> int:
	for i in LevelCatalog.level_count(world):
		if level_stars(world, i) == 0:
			return i
	return maxi(LevelCatalog.level_count(world) - 1, 0)


func has_next_level(world: int, level: int) -> bool:
	return level + 1 < LevelCatalog.level_count(world)


## Stores a win, keeping the best stars / time / combo, and pays the coins.
## Returns {coins: earned, best_time: true when an earlier time was beaten}.
func record_win(world: int, level: int, stars: int, time: float, combo: int, hard: bool) -> Dictionary:
	var key := _key(world, level)
	var old: Dictionary = levels.get(key, {})
	var old_time := float(old.get("time", -1.0))
	levels[key] = {
		"stars": maxi(stars, int(old.get("stars", 0))),
		"time": time if old_time < 0.0 else minf(time, old_time),
		"combo": maxi(combo, int(old.get("combo", 0))),
	}
	var earned := Economy.level_coins(stars, combo, hard)
	add_coins(earned)
	return {"coins": earned, "best_time": old_time >= 0.0 and time < old_time}


func add_coins(amount: int) -> void:
	coins = maxi(coins + amount, 0)
	coins_changed.emit(coins)
	save()


func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save()


func mark_tip_seen(tip: String) -> void:
	if not tip in tips_seen:
		tips_seen.append(tip)
		save()


# --- Settings ------------------------------------------------------------------

func set_sound(on: bool) -> void:
	sound_on = on
	_settings_changed()


func set_music(on: bool) -> void:
	music_on = on
	_settings_changed()


func set_vibration(on: bool) -> void:
	vibration_on = on
	_settings_changed()


## Steps to the next speed setting (wraps around).
func cycle_speed() -> void:
	speed_level = (speed_level + 1) % SPEEDS.size()
	_settings_changed()


func speed_label() -> String:
	return tr(SPEEDS[speed_level][0])


## Steps auto -> English -> Türkçe -> auto.
func cycle_language() -> void:
	language = LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]
	_settings_changed()


func _settings_changed() -> void:
	_apply_settings()
	save()


func _apply_settings() -> void:
	Sfx.enabled = sound_on
	Sfx.music_enabled = music_on
	Haptics.enabled = vibration_on
	VehicleView.speed_scale = SPEEDS[speed_level][1]
	# English is the main language; Turkish devices start in Turkish.
	var locale := language
	if locale == "auto":
		locale = "tr" if OS.get_locale_language() == "tr" else "en"
	TranslationServer.set_locale(locale)


# --- Save file -----------------------------------------------------------------

func save() -> void:
	var data := {
		"version": SAVE_VERSION,
		"coins": coins,
		"levels": levels,
		"inventory": inventory,
		"ad_free": ad_free,
		"tutorial": tutorial_seen,
		"tips": tips_seen,
		"settings": {
			"sound": sound_on, "music": music_on, "vibration": vibration_on,
			"speed": speed_level, "language": language,
		},
	}
	# Write to a temp file first so a crash mid-write never corrupts the save.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write %s" % tmp)
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		push_warning("Save file unreadable; starting fresh")
		return
	if int(data.get("version", 1)) < 2:
		data = _migrate_v1(data)
	coins = int(data.get("coins", 0))
	levels = data.get("levels", {})
	inventory = data.get("inventory", {})
	ad_free = bool(data.get("ad_free", false))
	tutorial_seen = bool(data.get("tutorial", false))
	tips_seen = data.get("tips", [])
	var s: Dictionary = data.get("settings", {})
	sound_on = bool(s.get("sound", true))
	music_on = bool(s.get("music", true))
	vibration_on = bool(s.get("vibration", true))
	speed_level = clampi(int(s.get("speed", 1)), 0, SPEEDS.size() - 1)
	language = s.get("language", "auto") if s.get("language", "auto") in LANGUAGES else "auto"
	current_world = 0
	current_level = next_open_level(0)


## Version 1 kept a flat list of completed level indices (all in world 1) and
## settings at the top level. Completed levels carry over with one star.
static func _migrate_v1(old: Dictionary) -> Dictionary:
	var migrated_levels := {}
	for i in old.get("completed", []):
		migrated_levels[_key(0, int(i))] = {"stars": 1, "time": -1.0, "combo": 0}
	return {
		"version": SAVE_VERSION,
		"levels": migrated_levels,
		"tutorial": old.get("tutorial", false),
		"settings": {
			"sound": old.get("sound", true), "music": old.get("music", true),
			"vibration": old.get("vibration", true), "speed": old.get("speed", 1),
		},
	}


static func _key(world: int, level: int) -> String:
	return "%d:%d" % [world, level]
