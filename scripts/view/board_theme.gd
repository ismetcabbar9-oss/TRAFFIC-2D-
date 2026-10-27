class_name BoardTheme
extends Resource
## Colors and proportions of the board. Create alternative themes as .tres files.

@export_group("Colors")
@export var grass := Color("8fd072")
@export var sidewalk := Color("e8e2d4")
@export var curb := Color("c9c1b0")
@export var road := Color("525a6b")
@export var road_line := Color("f4f1e8")
@export var lot := Color("8b93a5")
@export var lot_line := Color(1, 1, 1, 0.55)
@export var sky := Color("bfe3f2")

@export_group("Sizes")
@export var cell_size := 1.7
@export var sidewalk_width := 0.45
@export var road_width := 2.3
@export var outer_sidewalk_width := 0.6
@export var lot_line_width := 0.06
