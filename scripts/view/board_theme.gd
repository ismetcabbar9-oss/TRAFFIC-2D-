class_name BoardTheme
extends Resource
## Colors and proportions of the board. Create alternative themes as .tres files.

@export_group("Colors")
@export var grass := Color("74a95c")
@export var sidewalk := Color("d9d3c4")
@export var curb := Color("b4ac9c")
@export var road := Color("434956")
@export var road_line := Color("eeebe2")
@export var lot := Color("5a6170")
@export var lot_line := Color(1, 1, 1, 0.75)
@export var lot_border := Color("e9b949")

@export_group("Sizes")
@export var cell_size := 1.7
@export var sidewalk_width := 0.45
@export var road_width := 2.3
@export var outer_sidewalk_width := 0.6
@export var lot_line_width := 0.07
@export var curb_width := 0.14
