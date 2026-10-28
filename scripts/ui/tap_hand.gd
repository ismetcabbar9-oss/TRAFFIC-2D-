class_name TapHand
extends Control
## Pointing hand that taps a spot over and over (first-time guidance): the
## fingertip sits on `target`, presses down and a ring ripples out.

const PERIOD := 1.1 ## seconds per tap

var target := Vector2.ZERO:
	set(value):
		target = value
		queue_redraw()

var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var t := fmod(_time, PERIOD) / PERIOD
	var press := sin(clampf(t / 0.35, 0.0, 1.0) * PI) # down and up in the first third
	# Ripple ring after each press.
	if t > 0.2:
		var k := (t - 0.2) / 0.8
		draw_arc(target, 18.0 + k * 46.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - k)), 5.0, true)
	var tip := target + Vector2(10, 14) * (1.0 - press) + Vector2(4, 6)
	_draw_hand(tip, 1.0 - press * 0.08)


## Hand seen from above, index finger pointing up-left to `tip`.
func _draw_hand(tip: Vector2, s: float) -> void:
	var ink := Color(0.12, 0.14, 0.2, 0.9)
	var skin := Color("fff4e6")
	draw_set_transform(tip, -0.45, Vector2.ONE * s)
	var finger := Rect2(Vector2(-13, 0), Vector2(26, 62))
	var palm := Rect2(Vector2(-22, 44), Vector2(66, 62))
	var thumb := Rect2(Vector2(-36, 58), Vector2(24, 40))
	for rect in [finger, palm, thumb]:
		_rounded(rect.grow(4.0), ink, 16)
	for rect in [finger, palm, thumb]:
		_rounded(rect, skin, 13)
	# Knuckles of the folded fingers.
	for i in 3:
		draw_line(Vector2(6 + i * 13, 50), Vector2(6 + i * 13, 64), Color(ink, 0.35), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _rounded(rect: Rect2, color: Color, radius: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)
