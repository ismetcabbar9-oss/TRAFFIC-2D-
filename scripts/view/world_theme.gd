class_name WorldTheme
extends RefCounted
## Look of one world: board colors, sky and light, the scenery around the lot
## (trees, street furniture, buildings, landmarks, ground patches such as the
## sea or an apron) and its music. Built in code from the world id in
## data/worlds.json.

const PROPS := "res://assets/models/hq/props/"
const TREES := "res://assets/models/hq/trees/"
const WORLD := "res://assets/models/hq/worlds/"

var id := "city"
var board := BoardTheme.new()
var sky := Color("bfe3f2")
var night := false
var snow := false ## gentle snowfall
var music := "game"

var lamp := [PROPS + "street_light.glb", 0.65]
var trees: Array = [] ## [model path, scale]
var bushes: Array = []
var furniture: Array = [] ## small props on the grass beside the pavement
var low_buildings: Array = [] ## model paths; may stand in front of the camera
var tall_buildings: Array = []
var building_scale := 0.7
var building_radius := 3.6 ## footprint radius used when spacing buildings
## Big models placed first, behind the lot or at its sides:
## [model path, scale, footprint radius, count, "back" | "sides" | "front"].
## "front" means beside the exit road, near the camera.
var landmarks: Array = []
## Flat colored areas on the ground: [side ("back"), start distance from the
## pavement, depth, color, kind ("water" | "flat")].
var patches: Array = []

static var _cache := {}


static func for_world(world_index: int) -> WorldTheme:
	var world_id := str(LevelCatalog.world(world_index).get("id", "city"))
	if not _cache.has(world_id):
		_cache[world_id] = _build(world_id)
	return _cache[world_id]


static func _build(world_id: String) -> WorldTheme:
	var t := WorldTheme.new()
	t.id = world_id
	t._city_defaults()
	match world_id:
		"beach": t._beach()
		"snow": t._snow()
		"night": t._night()
		"airport": t._airport()
	return t


func _city_defaults() -> void:
	trees = [
		[TREES + "tree_02.glb", 1.7], [TREES + "tree_04.glb", 1.6], [TREES + "tree_06.glb", 1.8],
		[TREES + "tree_11.glb", 1.8], [TREES + "tree_15.glb", 1.7], [TREES + "tree_16.glb", 1.7],
		[TREES + "tree_17.glb", 1.6], [TREES + "tree_21.glb", 1.7], [TREES + "tree_23.glb", 1.4],
		[TREES + "tree_26.glb", 1.6], [TREES + "tree_28.glb", 1.7],
	]
	bushes = [
		[TREES + "tree_38.glb", 1.1], [TREES + "tree_39.glb", 1.0], [TREES + "tree_43.glb", 1.2],
		[TREES + "tree_44.glb", 1.0], [TREES + "tree_45.glb", 1.2], [TREES + "tree_50.glb", 1.1],
	]
	furniture = [
		[PROPS + "bench.glb", 0.55], [PROPS + "trash_can.glb", 0.6], [PROPS + "hydrant.glb", 0.6],
		[PROPS + "post_box.glb", 0.6], [PROPS + "bench_short.glb", 0.55],
	]
	low_buildings = _props(["bakery", "coffee_shop", "market", "pizzeria", "police_station", "blue_house"])
	tall_buildings = _props(["hotel", "hospital", "cinema", "green_house", "fire_station", "yellow_house"])
	landmarks = [[PROPS + "bus_stop.glb", 0.5, 1.6, 1, "back"]]


## Sand, palms, umbrellas and the sea behind the lot.
func _beach() -> void:
	board.grass = Color("e6d3a3")
	board.sidewalk = Color("f3ead6")
	board.curb = Color("cdb98f")
	board.lot_border = Color("f39c4a")
	sky = Color("a9e4f5")
	music = "beach"
	trees = [[WORLD + "coconut_palm.glb", 1.0], [WORLD + "palm_tall.glb", 1.0], [WORLD + "palm_bent.glb", 1.0],
		[WORLD + "coconut_palm.glb", 1.15]]
	bushes = [[WORLD + "coconut_palm.glb", 0.6], [TREES + "tree_43.glb", 0.9], [TREES + "tree_39.glb", 0.8]]
	furniture = [[WORLD + "umbrella.glb", 1.0], [WORLD + "deckchair.glb", 1.0], [WORLD + "umbrella.glb", 0.9],
		[PROPS + "trash_can.glb", 0.6]]
	low_buildings = _props(["coffee_shop", "market", "pizzeria", "blue_house", "yellow_house"])
	tall_buildings = _props(["hotel", "green_house"])
	landmarks = [[WORLD + "lifeguard_chair.glb", 1.0, 1.2, 2, "back"]]
	patches = [["back", 1.9, 200.0, Color("3fb8d6"), "water"]]


## Snow on the ground, snowy pines, a hut or two and falling snow.
func _snow() -> void:
	board.grass = Color("d3dde9") # shaded snow, so white trees and snowmen stand out
	board.sidewalk = Color("eef2f6")
	board.curb = Color("97a3b2")
	board.road = Color("4a505e")
	board.lot_border = Color("6fb7e8")
	sky = Color("dde8f1")
	snow = true
	music = "snow"
	trees = []
	for k in 5:
		trees.append([WORLD + "snow_tree_%d.glb" % (k + 1), 1.0])
	bushes = [[WORLD + "snow_tree_2.glb", 0.55], [WORLD + "snow_tree_3.glb", 0.6], [WORLD + "snow_tree_6.glb", 0.7]]
	furniture = [[WORLD + "snowman.glb", 1.0], [PROPS + "bench.glb", 0.55], [WORLD + "snowman.glb", 0.85]]
	low_buildings = [WORLD + "snow_hut.glb"]
	tall_buildings = [WORLD + "snow_hut.glb"] + _props(["blue_house", "green_house"])
	building_scale = 1.0


## The city after dark: moonlight, glowing street lamps and headlights.
func _night() -> void:
	board.grass = Color("5f8a55")
	board.lot_border = Color("f2c14e")
	sky = Color("131a33")
	night = true
	music = "night"


## Tarmac, yellow taxi lines, hangars, a control tower and parked planes.
func _airport() -> void:
	board.grass = Color("8fbb6c")
	board.road = Color("575c66")
	board.road_line = Color("f5d33f")
	board.lot = Color("646a74")
	board.lot_border = Color("f5d33f")
	sky = Color("c4e6f5")
	music = "airport"
	trees = [[TREES + "tree_23.glb", 1.3], [TREES + "tree_26.glb", 1.4]]
	furniture = [[WORLD + "baggage_truck.glb", 1.0], [WORLD + "baggage_cart.glb", 1.0], [WORLD + "baggage_cart.glb", 1.0]]
	low_buildings = []
	tall_buildings = [WORLD + "hangar.glb"]
	building_scale = 1.0
	building_radius = 8.5
	landmarks = [[WORLD + "control_tower.glb", 1.0, 2.0, 1, "back"], [WORLD + "plane.glb", 0.75, 3.6, 2, "front"],
		[WORLD + "plane.glb", 1.0, 4.2, 2, "back"]]
	patches = [["back", 0.9, 26.0, Color("6c7079"), "flat"]]


static func _props(names: Array) -> Array:
	var out := []
	for n in names:
		out.append(PROPS + n + ".glb")
	return out
