class_name RescueButton
extends Button
## Round button of the in-level rescue bar: a drawn icon (hint bulb, undo
## arrow, crane hook), its name underneath and a badge in the corner showing
## how many are owned / free, or the coin price.

var kind := "hint"
var badge := "" ## text in the corner badge; "" hides it
var badge_is_price := false ## coin price (gold) instead of a count (green)
var active := false: ## crane mode: drawn highlighted
	set(value):
		active = value
		queue_redraw()


func _init(p_kind: String) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(118, 118)
	theme_type_variation = "IconButton"
	focus_mode = Control.FOCUS_NONE


func set_badge(text: String, is_price: bool) -> void:
	badge = text
	badge_is_price = is_price
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.4)
	var s := size.x * 0.2
	var ink := UiStyle.INK if not disabled else UiStyle.MUTED
	if active:
		draw_circle(c, s * 1.55, Color(UiStyle.ACCENT, 0.25))
	match kind:
		"hint": _draw_bulb(c, s, ink)
		"undo": _draw_undo(c, s, ink)
		"crane": _draw_hook(c, s, ink)
	var font := UiStyle.font(700)
	var label := tr("RESCUE_" + kind.to_upper())
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.86), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink)
	if badge != "":
		_draw_badge()


func _draw_badge() -> void:
	var font := UiStyle.font(800)
	var text_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var h := 34.0
	var w := maxf(h, text_size.x + (34.0 if badge_is_price else 16.0))
	var rect := Rect2(Vector2(size.x - w + 8.0, -8.0), Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("fff4d6") if badge_is_price else UiStyle.GOOD
	box.set_corner_radius_all(int(h * 0.5))
	box.border_color = Color("e0a326") if badge_is_price else UiStyle.GOOD_DARK
	box.set_border_width_all(2)
	draw_style_box(box, rect)
	var x := rect.position.x + 8.0
	if badge_is_price:
		var coin_c := Vector2(x + 9.0, rect.get_center().y)
		draw_circle(coin_c, 9.0, Color("ffc93c"))
		draw_arc(coin_c, 6.0, 0.0, TAU, 16, Color("e0a326"), 1.5, true)
		x += 22.0
	else:
		x = rect.get_center().x - text_size.x * 0.5
	var color := UiStyle.INK if badge_is_price else Color.WHITE
	draw_string(font, Vector2(x, rect.get_center().y + 8.0), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)


func _draw_bulb(c: Vector2, s: float, ink: Color) -> void:
	var glass := Color("ffc93c") if not disabled else UiStyle.MUTED
	for i in 5: # rays
		var a := PI + 0.35 + i * (PI - 0.7) / 4.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * s * 1.15, c + d * s * 1.45, glass, 3.0, true)
	draw_circle(c, s * 0.85, glass)
	draw_circle(c + Vector2(-s * 0.3, -s * 0.3), s * 0.2, Color(1, 1, 1, 0.6))
	draw_rect(Rect2(c + Vector2(-s * 0.38, s * 0.7), Vector2(s * 0.76, s * 0.45)), ink)
	draw_rect(Rect2(c + Vector2(-s * 0.26, s * 1.18), Vector2(s * 0.52, s * 0.16)), ink)


func _draw_undo(c: Vector2, s: float, _ink: Color) -> void:
	var color := UiStyle.ACCENT if not disabled else UiStyle.MUTED
	draw_arc(c + Vector2(0, s * 0.15), s * 0.85, -PI * 0.95, PI * 0.55, 24, color, s * 0.32, true)
	var tip := c + Vector2(-s * 0.85, s * 0.15) + Vector2(0, -s * 0.05)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.1), tip + Vector2(s * 0.45, -s * 0.1),
			tip + Vector2(0, s * 0.55)]), color)


func _draw_hook(c: Vector2, s: float, ink: Color) -> void:
	var steel := Color("4a6fa5") if not disabled else UiStyle.MUTED
	draw_line(c + Vector2(0, -s * 1.4), c + Vector2(0, -s * 0.2), ink, 3.5, true)
	draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.35), Vector2(s * 0.6, s * 0.35)), steel)
	draw_arc(c + Vector2(0, s * 0.45), s * 0.45, -PI * 0.5, PI * 1.15, 20, steel, s * 0.22, true)
