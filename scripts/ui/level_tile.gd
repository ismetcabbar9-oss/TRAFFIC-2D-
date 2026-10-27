class_name LevelTile
extends Button
## Square button for one level on the level select screen: number, a check
## badge when completed, a lock when not yet available.

var index := 0
var locked := false
var done := false


func setup(p_index: int, p_locked: bool, p_done: bool) -> void:
	index = p_index
	locked = p_locked
	done = p_done
	text = "" if locked else str(index + 1)
	disabled = locked
	theme_type_variation = "GoodButton" if done else ""
	add_theme_font_size_override("font_size", 46)
	queue_redraw()


func _draw() -> void:
	if locked:
		_draw_lock(size * 0.5 + Vector2(0, -2), size.x * 0.16)
	elif done:
		var c := Vector2(size.x - 18, 18)
		draw_circle(c + Vector2(0, 2), 15, Color(0, 0, 0, 0.15))
		draw_circle(c, 15, Color.WHITE)
		draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 5), c + Vector2(7, -5)]),
				UiStyle.GOOD_DARK, 4.0, true)


func _draw_lock(center: Vector2, s: float) -> void:
	var color := Color("aab1bf")
	draw_arc(center + Vector2(0, -s * 0.35), s * 0.62, PI, TAU, 16, color, s * 0.28, true)
	var body := Rect2(center + Vector2(-s, -s * 0.3), Vector2(s * 2.0, s * 1.6))
	draw_rect(body, color)
	draw_circle(body.get_center() + Vector2(0, -s * 0.1), s * 0.22, Color("dfe3ea"))
