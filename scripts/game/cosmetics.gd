class_name Cosmetics
## Garage catalog: purely visual unlocks bought with coins (they never change
## the gameplay). Each category has a free default; Progress keeps what is
## owned and equipped.

const CATEGORIES := ["arrow", "smoke", "confetti"]

## category -> list of {id, price, colors}
const ITEMS := {
	"arrow": [
		{"id": "arrow_white", "price": 0, "colors": [Color("e6e8ec")]},
		{"id": "arrow_gold", "price": 150, "colors": [Color("ffd166")]},
		{"id": "arrow_mint", "price": 150, "colors": [Color("7ee0c3")]},
		{"id": "arrow_sky", "price": 150, "colors": [Color("8fd3ff")]},
		{"id": "arrow_pink", "price": 200, "colors": [Color("ffb3d1")]},
		{"id": "arrow_lime", "price": 250, "colors": [Color("c6f36b")]},
	],
	"smoke": [
		{"id": "smoke_white", "price": 0, "colors": [Color("f7f7fa")]},
		{"id": "smoke_pink", "price": 200, "colors": [Color("ffc2dc")]},
		{"id": "smoke_blue", "price": 200, "colors": [Color("bde3ff")]},
		{"id": "smoke_mint", "price": 200, "colors": [Color("c3f5de")]},
		{"id": "smoke_rainbow", "price": 500,
			"colors": [Color("ff9aa2"), Color("ffdac1"), Color("fff3b0"), Color("b5ead7"), Color("c7ceea")]},
	],
	"confetti": [
		{"id": "confetti_party", "price": 0,
			"colors": [Color("ff5a5f"), Color("ffb23e"), Color("37c47a"), Color("4aa3ff"), Color("b07cff"), Color("ffe066")]},
		{"id": "confetti_gold", "price": 300, "colors": [Color("ffd166"), Color("f4a261"), Color("ffe8a3"), Color("e9c46a")]},
		{"id": "confetti_ocean", "price": 300, "colors": [Color("4aa3ff"), Color("48cae4"), Color("90e0ef"), Color("0077b6")]},
		{"id": "confetti_candy", "price": 300, "colors": [Color("ff8fab"), Color("ffc6ff"), Color("bde0fe"), Color("caffbf")]},
	],
}


static func items(category: String) -> Array:
	return ITEMS[category]


static func find(id: String) -> Dictionary:
	for category in ITEMS:
		for item in ITEMS[category]:
			if item.id == id:
				return item
	return {}


static func category_of(id: String) -> String:
	for category in ITEMS:
		for item in ITEMS[category]:
			if item.id == id:
				return category
	return ""


## Colors of the equipped item in `category` (the default if none is saved).
static func colors(category: String) -> Array:
	var progress := _progress()
	var id: String = progress.equipped(category) if progress else ""
	var item := find(id)
	if item.is_empty():
		item = ITEMS[category][0]
	return item.colors


static func color(category: String) -> Color:
	return colors(category).pick_random()


static func _progress() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Progress") if tree else null
