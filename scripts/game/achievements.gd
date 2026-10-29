class_name Achievements
## Goals with coin rewards. Progress is computed from the save (levels, stats,
## garage); a reached goal waits in the achievements page to be collected.
## Later mirrored to Google Play Games.

## {id, stat, goal, coins}
const LIST := [
	{"id": "first_win", "stat": "levels", "goal": 1, "coins": 20},
	{"id": "levels_10", "stat": "levels", "goal": 10, "coins": 50},
	{"id": "levels_50", "stat": "levels", "goal": 50, "coins": 150},
	{"id": "levels_100", "stat": "levels", "goal": 100, "coins": 300},
	{"id": "levels_200", "stat": "levels", "goal": 200, "coins": 500},
	{"id": "perfect_10", "stat": "perfect", "goal": 10, "coins": 100},
	{"id": "perfect_50", "stat": "perfect", "goal": 50, "coins": 250},
	{"id": "perfect_150", "stat": "perfect", "goal": 150, "coins": 500},
	{"id": "combo_5", "stat": "best_combo", "goal": 5, "coins": 60},
	{"id": "combo_8", "stat": "best_combo", "goal": 8, "coins": 150},
	{"id": "cars_100", "stat": "cars", "goal": 100, "coins": 50},
	{"id": "cars_500", "stat": "cars", "goal": 500, "coins": 150},
	{"id": "cars_1000", "stat": "cars", "goal": 1000, "coins": 300},
	{"id": "crane_1", "stat": "cranes", "goal": 1, "coins": 30},
	{"id": "daily_3", "stat": "daily_best", "goal": 3, "coins": 80},
	{"id": "daily_7", "stat": "daily_best", "goal": 7, "coins": 200},
	{"id": "worlds_1", "stat": "worlds", "goal": 1, "coins": 100},
	{"id": "worlds_3", "stat": "worlds", "goal": 3, "coins": 200},
	{"id": "worlds_5", "stat": "worlds", "goal": 5, "coins": 400},
	{"id": "garage_1", "stat": "cosmetics", "goal": 1, "coins": 40},
	{"id": "rush_300", "stat": "rush_best", "goal": 300, "coins": 60},
	{"id": "rush_1000", "stat": "rush_best", "goal": 1000, "coins": 150},
	{"id": "rush_2500", "stat": "rush_best", "goal": 2500, "coins": 400},
]


## Current value of a stat.
static func stat(progress: Node, name: String) -> int:
	match name:
		"levels":
			return progress.levels.size()
		"perfect":
			return progress.levels.values().filter(func(r): return int(r.get("stars", 0)) >= 3).size()
		"worlds":
			var done := 0
			for w in LevelCatalog.world_count():
				var count := LevelCatalog.level_count(w)
				if count > 0 and range(count).all(func(i): return progress.level_stars(w, i) > 0):
					done += 1
			return done
		"cosmetics":
			return progress.owned.size()
	return int(progress.stats.get(name, 0))


static func is_done(progress: Node, entry: Dictionary) -> bool:
	return stat(progress, entry.stat) >= int(entry.goal)


static func claimable(progress: Node, entry: Dictionary) -> bool:
	return is_done(progress, entry) and not entry.id in progress.claimed


static func any_claimable(progress: Node) -> bool:
	return LIST.any(func(e): return claimable(progress, e))


## Ids of goals reached right now (to spot new ones during play).
static func done_ids(progress: Node) -> Array:
	return LIST.filter(func(e): return is_done(progress, e)).map(func(e): return e.id)
