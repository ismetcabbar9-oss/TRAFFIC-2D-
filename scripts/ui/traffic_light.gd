class_name TrafficLight
extends Control
## Little traffic light on the Play button: red and amber off, green lit.


func _init(height := 74.0) -> void:
	custom_minimum_size = Vector2(height * 0.42, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiStyle.INK
	box.set_corner_radius_all(int(size.x * 0.3))
	box.set_border_width_all(3)
	box.border_color = Color.WHITE
	box.anti_aliasing = true
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var r := size.x * 0.27
	var colors := [Color("6b2a2a"), Color("6b5a2a"), Color("5dff9a")]
	for i in 3:
		var c := Vector2(size.x * 0.5, size.y * (0.2 + i * 0.3))
		if i == 2:
			draw_circle(c, r * 1.6, Color(0.36, 1.0, 0.6, 0.25))
		draw_circle(c, r, colors[i])
