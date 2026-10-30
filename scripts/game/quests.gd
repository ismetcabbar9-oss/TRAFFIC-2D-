class_name Quests
## Daily quests: three goals a day picked from a pool (only ones the player
## can reach: no Rush Hour quest before it is unlocked and so on). Play
## reports events; a finished quest's coins are collected by hand and can be
## doubled with an ad; all three collected opens a bonus chest.
## Kept in Progress.daily, so they start fresh every day.

## {id, event, goal, coins, [needs]}; "max" events keep the best value seen
## (a combo, a Rush score) instead of adding up.
const POOL := [
	{"id": "levels_3", "event": "level_won", "goal": 3, "coins": 40},
	{"id": "perfect_2", "event": "perfect", "goal": 2, "coins": 60},
	{"id": "cars_40", "event": "cars", "goal": 40, "coins": 40},
	{"id": "combo_5", "event": "combo", "goal": 5, "coins": 50, "max": true},
	{"id": "daily_1", "event": "daily", "goal": 1, "coins": 50},
	{"id": "rush_300", "event": "rush_score", "goal": 300, "coins": 60, "max": true, "needs": "rush"},
	{"id": "tanker_1", "event": "tanker_level", "goal": 1, "coins": 50, "needs": "tanker"},
	{"id": "bomb_1", "event": "bomb_level", "goal": 1, "coins": 60, "needs": "bomb"},
]
const PER_DAY := 3
const CHEST_COINS := 100


## Today's quests: [{id, progress, claimed}], picked on first use each day.
static func today(progress: Node) -> Array:
	var day: Dictionary = progress._today()
	if not day.has("quests"):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["quests", day.day])
		var pool := POOL.filter(func(q): return _reachable(progress, q))
		for k in range(pool.size() - 1, 0, -1): # shuffle
			var j := rng.randi_range(0, k)
			var tmp = pool[k]
			pool[k] = pool[j]
			pool[j] = tmp
		day["quests"] = pool.slice(0, PER_DAY).map(func(q): return {"id": q.id, "progress": 0, "claimed": false})
	return day.quests


static func info(id: String) -> Dictionary:
	for q in POOL:
		if q.id == id:
			return q
	return {}


static func done(entry: Dictionary) -> bool:
	return int(entry.progress) >= int(info(entry.id).goal)


## Something happened in play: every quest of today waiting for `event` moves on.
static func report(progress: Node, event: String, value := 1) -> void:
	var changed := false
	for entry in today(progress):
		var q := info(entry.id)
		if q.event != event or done(entry):
			continue
		entry.progress = maxi(int(entry.progress), value) if q.get("max", false) else int(entry.progress) + value
		changed = true
	if changed:
		progress.save()


## Collects a finished quest's coins (`times` 2 after an ad). False if not ready.
static func claim(progress: Node, index: int, times := 1) -> bool:
	var entry: Dictionary = today(progress)[index]
	if entry.claimed or not done(entry):
		return false
	entry.claimed = true
	progress.add_coins(int(info(entry.id).coins) * times, "quest")
	progress.save()
	return true


static func claimable(progress: Node) -> bool:
	return today(progress).any(func(e): return done(e) and not e.claimed) or chest_ready(progress)


static func chest_ready(progress: Node) -> bool:
	return today(progress).all(func(e): return e.claimed) and not progress._today().get("quest_chest", false)


static func open_chest(progress: Node) -> bool:
	if not chest_ready(progress):
		return false
	progress._today()["quest_chest"] = true
	progress.add_coins(CHEST_COINS, "quest_chest")
	progress.save()
	return true


static func _reachable(progress: Node, q: Dictionary) -> bool:
	match q.get("needs", ""):
		"rush":
			return Rush.unlocked(progress)
		"tanker":
			return progress.levels.size() >= 20
		"bomb":
			return progress.is_world_unlocked(2)
	return true
