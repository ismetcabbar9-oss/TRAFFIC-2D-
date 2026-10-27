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
var inventory := {} ## rescue name ("hint", "undo", "crane") -> count owned
## Counters that reset every day: {"day": "YYYY-MM-DD", "free_hints": used,
## "ads": {placement: count, "total": count}}.
var daily := {}
var flags := {} ## one-time events, e.g. "crane_gift"
var owned: Array = [] ## bought garage items (see Cosmetics)
var equipped_items := {} ## garage category -> item id
var stats := {} ## lifetime counters: cars, best_combo, cranes, daily_best
var claimed: Array = [] ## collected achievement ids
var gift := {} ## daily gift: {"last_day", "index" (0..6) of the last claim}
var daily_puzzle := {} ## {"last_day", "streak"}
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


## Takes `amount` coins if the player has them.
func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	add_coins(-amount)
	return true


func item_count(item: String) -> int:
	return int(inventory.get(item, 0))


func add_item(item: String, amount := 1) -> void:
	inventory[item] = item_count(item) + amount
	save()


## Uses one owned rescue; false if none is left.
func use_item(item: String) -> bool:
	if item_count(item) <= 0:
		return false
	inventory[item] = item_count(item) - 1
	save()
	return true


func free_hints_left() -> int:
	return maxi(int(Economy.value("free_hints_per_day")) - int(_today().get("free_hints", 0)), 0)


func use_free_hint() -> bool:
	if free_hints_left() <= 0:
		return false
	var today := _today()
	today["free_hints"] = int(today.get("free_hints", 0)) + 1
	save()
	return true


## Rewarded ads watched today for `placement` (and in total).
func ads_watched(placement: String) -> int:
	return int(_today().get("ads", {}).get(placement, 0))


func count_ad(placement: String) -> void:
	var ads: Dictionary = _today().get_or_add("ads", {})
	ads[placement] = int(ads.get(placement, 0)) + 1
	ads["total"] = int(ads.get("total", 0)) + 1
	save()


# --- Stats, achievements, daily gift and puzzle ------------------------------------

## Adds to a lifetime counter (saved with the next save).
func add_stat(name: String, amount := 1) -> void:
	stats[name] = int(stats.get(name, 0)) + amount


## Keeps the highest value seen.
func max_stat(name: String, value: int) -> void:
	stats[name] = maxi(int(stats.get(name, 0)), value)


func claim_achievement(id: String) -> int:
	for entry in Achievements.LIST:
		if entry.id == id and Achievements.claimable(self, entry):
			claimed.append(id)
			add_coins(int(entry.coins))
			return int(entry.coins)
	return 0


## Day (0..6) of the gift that can be claimed today, or -1 if already claimed.
## Missing a day starts the week over.
func gift_day() -> int:
	var today := Daily.today()
	var last: String = gift.get("last_day", "")
	if last == today:
		return -1
	if last == Daily.day_before(today):
		return (int(gift.get("index", -1)) + 1) % Daily.GIFT_REWARDS.size()
	return 0


## Day the calendar shows as current (today's, or the one claimed today).
func gift_display_day() -> int:
	var day := gift_day()
	return int(gift.get("index", 0)) if day < 0 else day


## Claims today's gift (`times` = 2 after a rewarded ad). Returns the coins.
func claim_gift(times := 1) -> int:
	var day := gift_day()
	if day < 0:
		return 0
	var coins: int = Daily.GIFT_REWARDS[day] * times
	gift = {"last_day": Daily.today(), "index": day}
	if day == Daily.GIFT_REWARDS.size() - 1:
		add_item(Daily.GIFT_BONUS_ITEM)
	add_coins(coins)
	return coins


func daily_done_today() -> bool:
	return daily_puzzle.get("last_day", "") == Daily.today()


## Current streak (0 once a day was missed).
func daily_streak() -> int:
	var last: String = daily_puzzle.get("last_day", "")
	if last == Daily.today() or last == Daily.day_before(Daily.today()):
		return int(daily_puzzle.get("streak", 0))
	return 0


## Records today's puzzle as solved; returns {coins, streak}.
func record_daily_win() -> Dictionary:
	if daily_done_today():
		return {"coins": 0, "streak": daily_streak()}
	var streak := daily_streak() + 1
	daily_puzzle = {"last_day": Daily.today(), "streak": streak}
	max_stat("daily_best", streak)
	var coins := int(Economy.value("daily_puzzle_coins")) + mini(streak - 1, 7) * int(Economy.value("daily_streak_bonus"))
	add_coins(coins)
	return {"coins": coins, "streak": streak}


# --- Garage ----------------------------------------------------------------------

func owns(id: String) -> bool:
	return id in owned or int(Cosmetics.find(id).get("price", -1)) == 0


## Buys a garage item with coins; false if not affordable.
func buy_cosmetic(id: String) -> bool:
	if owns(id) or not spend_coins(int(Cosmetics.find(id).price)):
		return false
	owned.append(id)
	save()
	return true


func equip(id: String) -> void:
	if owns(id):
		equipped_items[Cosmetics.category_of(id)] = id
		save()


func equipped(category: String) -> String:
	return equipped_items.get(category, "")


func flag(name: String) -> bool:
	return bool(flags.get(name, false))


func set_flag(name: String) -> void:
	flags[name] = true
	save()


## Today's counters, starting fresh on a new day.
func _today() -> Dictionary:
	var day := Time.get_date_string_from_system()
	if daily.get("day", "") != day:
		daily = {"day": day}
	return daily


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
		"daily": daily,
		"flags": flags,
		"garage": {"owned": owned, "equipped": equipped_items},
		"stats": stats,
		"claimed": claimed,
		"gift": gift,
		"daily_puzzle": daily_puzzle,
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
	daily = data.get("daily", {})
	flags = data.get("flags", {})
	var garage: Dictionary = data.get("garage", {})
	owned = garage.get("owned", [])
	equipped_items = garage.get("equipped", {})
	stats = data.get("stats", {})
	claimed = data.get("claimed", [])
	gift = data.get("gift", {})
	daily_puzzle = data.get("daily_puzzle", {})
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
