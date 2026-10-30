class_name Wheel
## Daily lucky wheel: one free spin a day, a few more for watching ads. The
## slices (in order around the wheel) and their odds; the jackpot is rare.

const PRIZES := [
	{"kind": "coins", "amount": 20, "weight": 22},
	{"kind": "hint", "amount": 1, "weight": 18},
	{"kind": "coins", "amount": 40, "weight": 20},
	{"kind": "undo", "amount": 1, "weight": 10},
	{"kind": "coins", "amount": 80, "weight": 12},
	{"kind": "crane", "amount": 1, "weight": 10},
	{"kind": "coins", "amount": 150, "weight": 6},
	{"kind": "coins", "amount": 500, "weight": 2, "jackpot": true},
]


## Index of a prize drawn by its weight.
static func pick(rng: RandomNumberGenerator) -> int:
	var total := 0
	for p in PRIZES:
		total += int(p.weight)
	var roll := rng.randi_range(0, total - 1)
	for i in PRIZES.size():
		roll -= int(PRIZES[i].weight)
		if roll < 0:
			return i
	return 0


static func grant(progress: Node, index: int) -> void:
	var prize: Dictionary = PRIZES[index]
	if prize.kind == "coins":
		progress.add_coins(int(prize.amount), "wheel")
	else:
		for k in int(prize.amount):
			progress.add_item(prize.kind)
	progress.save()
