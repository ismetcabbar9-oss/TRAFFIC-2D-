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


## Stars for a cleared level: 3 without a crash, then one less per crash (min 1).
static func stars_for(mistakes_used: int) -> int:
	var table: Array = value("stars_by_mistakes_used")
	return int(table[clampi(mistakes_used, 0, table.size() - 1)])


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
