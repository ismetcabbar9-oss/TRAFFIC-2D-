class_name GarageTile
extends Button
## One garage item: a preview drawn in its colors (cars seen from above for a
## paint job, roof arrow, smoke puffs or confetti), its name, and its price,
## "owned" or a check when equipped. Ad-unlocked items show their progress
## ("3/5 ads") with a play badge instead of a price.

var item := {}
var category := ""
var is_owned := false
var is_equipped := false
var ads_watched := 0 ## toward an ad-unlocked item


func setup(p_category: String, p_item: Dictionary, p_owned: bool, p_equipped: bool) -> void:
	category = p_category
	item = p_item
	is_owned = p_owned
	is_equipped = p_equipped
	custom_minimum_size = Vector2(196, 208)
	theme_type_variation = "IconButton"
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.38)
	var colors: Array = item.colors
	match category:
		"paint": _draw_paint(c, colors)
		"arrow": _draw_arrow(c, colors[0])
		"smoke": _draw_smoke(c, colors)
		"confetti": _draw_confetti(c, colors)
	var font := UiStyle.font(700)
	var name_text := tr("COS_" + str(item.id).to_upper())
	var w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.72), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
	var status := ""
	var status_color := UiStyle.INK.lerp(Color.WHITE, 0.35)
	if is_equipped:
		status = tr("GARAGE_EQUIPPED")
		status_color = UiStyle.GOOD_DARK
	elif is_owned:
		status = tr("GARAGE_OWNED")
	if status != "":
		var sw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, Vector2((size.x - sw) * 0.5, size.y * 0.88), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, status_color)
	elif int(item.get("ads", 0)) > 0:
		var progress := tr("GARAGE_ADS") % [ads_watched, int(item.ads)]
		var pw := font.get_string_size(progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var x := (size.x - pw - 30.0) * 0.5
		var badge_c := Vector2(x + 11.0, size.y * 0.86)
		draw_circle(badge_c, 12.0, UiStyle.GOOD)
		draw_colored_polygon(PackedVector2Array([badge_c + Vector2(-4, -6), badge_c + Vector2(-4, 6), badge_c + Vector2(6, 0)]), Color.WHITE)
		draw_string(font, Vector2(x + 28.0, size.y * 0.885), progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.GOOD_DARK)
	else:
		var price := str(item.price)
		var pw := font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var x := (size.x - pw - 26.0) * 0.5
		var coin_c := Vector2(x + 9.0, size.y * 0.86)
		draw_circle(coin_c, 10.0, Color("ffc93c"))
		draw_arc(coin_c, 6.5, 0.0, TAU, 16, Color("e0a326"), 1.5, true)
		draw_string(font, Vector2(x + 24.0, size.y * 0.885), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.ACCENT_DARK)
	if is_equipped:
		var box := StyleBoxFlat.new()
		box.draw_center = false
		box.border_color = UiStyle.GOOD
		box.set_border_width_all(5)
		box.set_corner_radius_all(22)
		draw_style_box(box, Rect2(Vector2.ZERO, size))


func _draw_arrow(c: Vector2, color: Color) -> void:
	# Car roof seen from above with the arrow on it.
	var roof := Rect2(c + Vector2(-34, -52), Vector2(68, 104))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("3e7bfa")
	box.set_corner_radius_all(16)
	draw_style_box(box, roof)
	var shape := PackedVector2Array()
	for p in DirectionArrow.STRAIGHT_SHAPE:
		shape.append(c + Vector2(p.x, -p.y) * 70.0)
	var outline := Geometry2D.offset_polygon(shape, 4.0, Geometry2D.JOIN_ROUND)
	if not outline.is_empty():
		draw_colored_polygon(outline[0], Color(0.12, 0.14, 0.2, 0.85))
	draw_colored_polygon(shape, color)


func _draw_smoke(c: Vector2, colors: Array) -> void:
	var puffs := [[Vector2(-30, 14), 22.0], [Vector2(0, -6), 28.0], [Vector2(30, 10), 20.0],
		[Vector2(-10, 26), 18.0], [Vector2(18, -26), 16.0]]
	for i in puffs.size():
		var col: Color = colors[i % colors.size()]
		draw_circle(c + puffs[i][0] + Vector2(0, 3), puffs[i][1], col.darkened(0.12))
		draw_circle(c + puffs[i][0], puffs[i][1], col)


## Three little cars from above in the paint's colors (metallic paints get
## a shine stripe, glowing ones a halo).
func _draw_paint(c: Vector2, colors: Array) -> void:
	var glow := float(item.get("glow", 0.0)) > 0.0
	var shiny := float(item.get("metallic", 0.0)) > 0.3
	for i in 3:
		var col: Color = colors[i % colors.size()]
		var center := c + Vector2((i - 1) * 50.0, (absf(i - 1.0) - 0.5) * 14.0)
		var body := Rect2(center + Vector2(-19, -34), Vector2(38, 68))
		if glow:
			var halo := StyleBoxFlat.new()
			halo.bg_color = Color(col, 0.35)
			halo.set_corner_radius_all(18)
			draw_style_box(halo, body.grow(7))
		var box := StyleBoxFlat.new()
		box.bg_color = col
		box.set_corner_radius_all(12)
		box.border_color = col.darkened(0.35)
		box.set_border_width_all(2)
		draw_style_box(box, body)
		draw_rect(Rect2(center + Vector2(-13, -16), Vector2(26, 12)), Color("2e3a4f")) # windscreen
		draw_rect(Rect2(center + Vector2(-13, 8), Vector2(26, 9)), Color("2e3a4f"))
		if shiny:
			draw_line(center + Vector2(-10, 28), center + Vector2(10, -30), Color(1, 1, 1, 0.55), 4.0, true)


func _draw_confetti(c: Vector2, colors: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item.id)
	for i in 16:
		var p := c + Vector2(rng.randf_range(-62, 62), rng.randf_range(-48, 48))
		var col: Color = colors[i % colors.size()]
		draw_set_transform(p, rng.randf() * TAU)
		draw_rect(Rect2(Vector2(-8, -4), Vector2(16, 8)), col)
	draw_set_transform(Vector2.ZERO)
