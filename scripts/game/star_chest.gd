class_name StarChest
## Star chest: every STARS stars earned (in total, over all levels) fills a
## chest with some coins and a rescue item; an ad doubles it. Chests that
## pile up wait to be opened one by one.

const STARS := 15
const ITEMS := ["hint", "undo", "crane"]


## Stars counted toward the next chest (0..STARS).
static func progress_stars(progress: Node) -> int:
	return mini(progress.total_stars() - opened(progress) * STARS, STARS)


static func opened(progress: Node) -> int:
	return int(progress.stats.get("star_chests", 0))


static func ready(progress: Node) -> bool:
	return progress.total_stars() >= (opened(progress) + 1) * STARS


## What the next chest holds: {coins, item}. Fixed per chest number, so
## reopening the menu never rerolls it.
static func contents(progress: Node) -> Dictionary:
	var n := opened(progress)
	return {"coins": 60 + (n * 37) % 61, "item": ITEMS[n % ITEMS.size()]}


## Opens the next chest (`times` 2 after an ad). Returns what was in it, or
## {} if no chest is ready.
static func open(progress: Node, times := 1) -> Dictionary:
	if not ready(progress):
		return {}
	var c := contents(progress)
	progress.stats["star_chests"] = opened(progress) + 1
	progress.add_coins(int(c.coins) * times, "star_chest")
	for k in times:
		progress.add_item(c.item)
	progress.save()
	return {"coins": int(c.coins) * times, "item": c.item, "count": times}
