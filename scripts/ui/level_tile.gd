class_name LevelTile
extends Button
## Button for one level on a world page: number, earned stars underneath,
## a lock when not yet available.

var index := 0
var locked := false
var stars := 0


func setup(p_index: int, p_locked: bool, p_stars: int) -> void:
	index = p_index
	locked = p_locked
	stars = p_stars
	text = "" if locked else str(index + 1)
	disabled = locked
	theme_type_variation = "GoodButton" if stars > 0 else ""
	add_theme_font_size_override("font_size", 44)
	queue_redraw()


func _draw() -> void:
	if locked:
		_draw_lock(size * 0.5 + Vector2(0, -4), size.x * 0.16)
		return
	# Three small stars along the bottom edge (empty slots when not earned).
	var r := size.x * 0.085
	var y := size.y - r * 1.6
	for i in 3:
		var c := Vector2(size.x * 0.5 + (i - 1) * r * 2.4, y)
		_draw_star(c, r, i < stars)


func _draw_star(c: Vector2, r: float, filled: bool) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var radius := r if i % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		points.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, StarIcon.FILL if filled else Color(1, 1, 1, 0.35))


func _draw_lock(center: Vector2, s: float) -> void:
	var color := Color("aab1bf")
	draw_arc(center + Vector2(0, -s * 0.35), s * 0.62, PI, TAU, 16, color, s * 0.28, true)
	var body := Rect2(center + Vector2(-s, -s * 0.3), Vector2(s * 2.0, s * 1.6))
	draw_rect(body, color)
	draw_circle(body.get_center() + Vector2(0, -s * 0.1), s * 0.22, Color("dfe3ea"))
