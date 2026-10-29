class_name RescueButton
extends Button
## Candy button of the in-level rescue bar (same style as the menu's bottom
## bar): a colored square with a white drawn icon (hint bulb, undo arrow, crane
## hook), its name underneath and a badge in the corner showing how many are
## owned / free, or the coin price.

const FACES := {"hint": Color("f5b700"), "undo": Color("ff8a3d"), "crane": Color("4aa3ff")}
const SIDE := 86.0 ## size of the candy square

var kind := "hint"
var badge := "" ## text in the corner badge; "" hides it
var badge_is_price := false ## coin price (gold) instead of a count (green)
var active := false: ## crane mode: drawn highlighted
	set(value):
		active = value
		queue_redraw()


func _init(p_kind: String) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(118, 134)
	flat = true
	focus_mode = Control.FOCUS_NONE
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func set_badge(text: String, is_price: bool) -> void:
	badge = text
	badge_is_price = is_price
	queue_redraw()


func _square() -> Rect2:
	return Rect2(Vector2((size.x - SIDE) * 0.5, 6.0), Vector2(SIDE, SIDE + UiStyle.CANDY_SLAB))


func _draw() -> void:
	var rect := _square()
	var down := is_pressed() and not disabled
	var face: Color = FACES[kind] if not disabled else Color("dfe3ea")
	if active: # crane mode: a glowing ring around the button
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(1.0, 0.8, 0.22, 0.45)
		glow.set_corner_radius_all(34)
		draw_style_box(glow, rect.grow(8.0))
	var box := StyleBoxTexture.new()
	box.texture = UiStyle.candy_texture(face, face.darkened(0.3), down)
	for m in ["texture_margin_left", "texture_margin_right", "texture_margin_top", "texture_margin_bottom"]:
		box.set(m, 30.0)
	draw_style_box(box, rect)
	var c := rect.position + Vector2(SIDE * 0.5, SIDE * 0.5 + (5.0 if down else 0.0))
	var s := SIDE * 0.25
	var ink := Color.WHITE if not disabled else Color("b9c0cc")
	match kind:
		"hint": _draw_bulb(c, s, ink)
		"undo": _draw_undo(c, s, ink)
		"crane": _draw_hook(c, s, ink)
	var font := UiStyle.font(700)
	var label := tr("RESCUE_" + kind.to_upper())
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y - 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
			UiStyle.INK if not disabled else UiStyle.MUTED)
	if badge != "":
		_draw_badge()


func _draw_badge() -> void:
	var font := UiStyle.font(800)
	var text_size := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var h := 34.0
	var w := maxf(h, text_size.x + (34.0 if badge_is_price else 16.0))
	var square := _square()
	var rect := Rect2(Vector2(square.end.x - w + 14.0, square.position.y - 12.0), Vector2(w, h))
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
	for i in 5: # rays
		var a := PI + 0.35 + i * (PI - 0.7) / 4.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * s * 1.15, c + d * s * 1.45, ink, 3.0, true)
	draw_circle(c + Vector2(0, -s * 0.1), s * 0.8, ink)
	var base := Color(0, 0, 0, 0.28)
	draw_rect(Rect2(c + Vector2(-s * 0.36, s * 0.6), Vector2(s * 0.72, s * 0.4)), ink)
	draw_rect(Rect2(c + Vector2(-s * 0.36, s * 0.72), Vector2(s * 0.72, s * 0.08)), base)
	draw_rect(Rect2(c + Vector2(-s * 0.24, s * 1.04), Vector2(s * 0.48, s * 0.16)), ink)


func _draw_undo(c: Vector2, s: float, ink: Color) -> void:
	draw_arc(c + Vector2(0, s * 0.15), s * 0.85, -PI * 0.95, PI * 0.55, 24, ink, s * 0.32, true)
	var tip := c + Vector2(-s * 0.85, s * 0.15) + Vector2(0, -s * 0.05)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.45, -s * 0.1), tip + Vector2(s * 0.45, -s * 0.1),
			tip + Vector2(0, s * 0.55)]), ink)


func _draw_hook(c: Vector2, s: float, ink: Color) -> void:
	draw_line(c + Vector2(0, -s * 1.3), c + Vector2(0, -s * 0.2), ink, 3.5, true)
	draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.38), Vector2(s * 0.64, s * 0.36)), ink)
	draw_arc(c + Vector2(0, s * 0.45), s * 0.45, -PI * 0.5, PI * 1.15, 20, ink, s * 0.24, true)
