class_name CoinIcon
extends Control
## Gold coin drawn in code.


func _init(size_px := 32.0) -> void:
	custom_minimum_size = Vector2.ONE * size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c + Vector2(0, r * 0.08), r, Color("d48a12"))
	draw_circle(c, r, Color("ffc93c"))
	draw_arc(c, r * 0.68, 0.0, TAU, 32, Color("e0a326"), maxf(r * 0.14, 1.5), true)
	draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.55))
