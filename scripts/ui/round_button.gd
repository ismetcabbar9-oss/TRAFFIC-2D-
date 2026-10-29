class_name RoundButton
extends Button
## Round "candy" button with a drawn icon (pause, retry, gear...): colored
## face, white rim, glossy top half and a darker base that sinks when pressed.
## An optional red dot marks something new behind it.

var icon_name := "pause"
var face := Color("4aa3ff")
var icon_color := Color.WHITE
var show_dot := false:
	set(value):
		show_dot = value
		queue_redraw()


func _init(p_icon := "pause", p_face := Color("4aa3ff"), size_px := 58.0, p_icon_color := Color.WHITE) -> void:
	icon_name = p_icon
	face = p_face
	icon_color = p_icon_color
	custom_minimum_size = Vector2.ONE * size_px
	flat = true
	focus_mode = Control.FOCUS_NONE
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 3.0
	var down := is_pressed() and not disabled
	var c := Vector2(size.x * 0.5, r + 2.0 + (4.0 if down else 0.0))
	var col := face if not disabled else UiStyle.MUTED
	if not down:
		draw_circle(c + Vector2(0, 5), r, col.darkened(0.3))
	draw_circle(c, r, Color.WHITE)
	draw_circle(c, r - 3.5, col)
	# Gloss: a lighter cap over the upper half.
	var cap := PackedVector2Array()
	for k in 17:
		var a := PI + PI * k / 16.0
		cap.append(c + Vector2(cos(a) * (r - 6.0), sin(a) * (r - 6.0) * 0.9))
	draw_colored_polygon(cap, Color(1, 1, 1, 0.22))
	UiIcons.draw(self, icon_name, c, r * 1.15, icon_color)
	if show_dot:
		var d := Vector2(size.x - 8.0, 8.0)
		draw_circle(d, 9.0, Color.WHITE)
		draw_circle(d, 6.5, UiStyle.DANGER)
