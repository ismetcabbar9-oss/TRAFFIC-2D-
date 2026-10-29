class_name Economy
## Reward rules, read from res://data/economy.json so they can be tuned
## without code changes.

const PATH := "res://data/economy.json"

static var _data: Dictionary = {}


static func value(key: String) -> Variant:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data[key]


## Stars for a cleared level: 3 only for a clean solve (no crash and no
## rescue: hint, undo, crane or extra moves), 2 with at most one crash,
## otherwise 1.
static func stars_for(crashes: int, rescued := false) -> int:
	var table: Array = value("stars_by_mistakes_used")
	var stars := int(table[clampi(crashes, 0, table.size() - 1)])
	return mini(stars, 2) if rescued else stars


## Crashes allowed on a level: generous while World 1 teaches the rules,
## tighter afterwards and a single chance on hard levels.
static func mistakes_for(world: int, index: int, hard: bool, daily := false) -> int:
	var table: Dictionary = value("mistakes_per_level")
	if daily:
		return int(table.daily)
	if world == 0 and index < int(table.learning_levels):
		return int(table.learning)
	return int(table.hard) if hard else int(table.normal)


## Coins for a cleared level; hard levels pay more.
static func level_coins(stars: int, best_combo: int, hard: bool) -> int:
	var coins: int = int(value("level_coins")) + int(value("star_bonus")[stars])
	if best_combo >= 2:
		coins += mini((best_combo - 1) * int(value("combo_coins_per_step")), int(value("combo_coins_max")))
	if hard:
		coins *= int(value("hard_level_multiplier"))
	return coins


## Coin price of a rescue ("hint", "undo", "crane", "continue").
static func price(rescue: String) -> int:
	return int(value("rescue_prices")[rescue])
