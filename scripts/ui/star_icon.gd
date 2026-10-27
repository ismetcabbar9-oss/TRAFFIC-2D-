class_name StarIcon
extends Control
## Five-pointed star drawn in code (the UI font has no star glyph).
## `filled` false draws an empty slot.

@export var filled := true:
	set(value):
		filled = value
		queue_redraw()

const FILL := Color("ffc93c")
const EDGE := Color("e0961b")
const EMPTY := Color(0, 0, 0, 0.18)


func _init(size_px := 32.0, p_filled := true) -> void:
	custom_minimum_size = Vector2.ONE * size_px
	filled = p_filled
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var points := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * radius)
	if filled:
		draw_colored_polygon(points, FILL)
		points.append(points[0])
		draw_polyline(points, EDGE, maxf(r * 0.12, 1.5), true)
	else:
		draw_colored_polygon(points, EMPTY)
