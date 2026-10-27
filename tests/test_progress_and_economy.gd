extends TestCase

const ProgressScript := preload("res://scripts/game/progress.gd")


func test_migrates_v1_save() -> void:
	var v1 := {"unlocked": 3, "completed": [0, 1], "sound": false, "music": true,
			"vibration": false, "speed": 2, "tutorial": true}
	var v2: Dictionary = ProgressScript._migrate_v1(v1)
	check_eq(v2.version, 2, "version bumped")
	check_eq(v2.levels.size(), 2, "both completed levels kept")
	check_eq(v2.levels["0:1"].stars, 1, "completed level gets one star")
	check_eq(v2.settings.sound, false, "sound setting kept")
	check_eq(v2.settings.speed, 2, "speed setting kept")
	check_eq(v2.tutorial, true, "tutorial flag kept")


func test_stars_by_mistakes() -> void:
	check_eq(Economy.stars_for(0), 3, "no crash")
	check_eq(Economy.stars_for(1), 2, "one crash")
	check_eq(Economy.stars_for(2), 1, "two crashes")
	check_eq(Economy.stars_for(7), 1, "never below one")


func test_level_coins() -> void:
	check_eq(Economy.level_coins(3, 0, false), 20, "3 stars, no combo")
	check_eq(Economy.level_coins(1, 0, false), 10, "1 star")
	check_eq(Economy.level_coins(3, 3, false), 24, "combo x3 adds 4")
	check_eq(Economy.level_coins(3, 20, false), 30, "combo bonus capped at 10")
	check_eq(Economy.level_coins(2, 0, true), 30, "hard level doubles")


func test_worlds_config() -> void:
	check_eq(LevelCatalog.world_count(), 5, "five worlds")
	check_eq(int(LevelCatalog.world(0).stars_required), 0, "first world open")
	check(LevelCatalog.level_count(0) >= 10, "world 1 has its levels")


func test_day_before() -> void:
	check_eq(Daily.day_before("2026-03-01"), "2026-02-28", "month boundary")
	check_eq(Daily.day_before("2027-01-01"), "2026-12-31", "year boundary")


func test_daily_puzzle_is_the_same_for_everyone() -> void:
	var w := 2
	var spec := LevelGenerator.spec(w, Daily.PUZZLE_LEVEL, Daily.MECHANICS[w])
	var a := LevelGenerator.generate(spec, ["daily", "2026-10-27"], 4)
	var b := LevelGenerator.generate(spec, ["daily", "2026-10-27"], 4)
	check(not a.is_empty(), "a puzzle was built")
	check_eq(a.data, b.data, "same day, same puzzle")
	check(LevelSolver.solve(LevelData.from_dict(a.data)).solvable, "solvable")


func test_gift_calendar_days() -> void:
	var p: Node = ProgressScript.new()
	var today := Daily.today()
	check_eq(p.gift_day(), 0, "first gift is day 1")
	p.gift = {"last_day": Daily.day_before(today), "index": 2}
	check_eq(p.gift_day(), 3, "next day continues the week")
	p.gift = {"last_day": Daily.day_before(Daily.day_before(today)), "index": 4}
	check_eq(p.gift_day(), 0, "a missed day starts over")
	p.gift = {"last_day": Daily.day_before(today), "index": 6}
	check_eq(p.gift_day(), 0, "after day 7 a new week starts")
	p.gift = {"last_day": today, "index": 1}
	check_eq(p.gift_day(), -1, "already claimed today")
	p.free()


func test_daily_streak() -> void:
	var p: Node = ProgressScript.new()
	p.daily_puzzle = {"last_day": Daily.day_before(Daily.today()), "streak": 4}
	check_eq(p.daily_streak(), 4, "streak alive until today is played")
	p.daily_puzzle = {"last_day": "2001-01-01", "streak": 9}
	check_eq(p.daily_streak(), 0, "missed days reset the streak")
	p.free()
