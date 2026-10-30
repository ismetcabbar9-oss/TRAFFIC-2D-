class_name UiIcons
## Simple vector icons drawn in code (the UI font has no symbols), all in a
## box of `s` pixels centered on `c`: pause, retry, back, gear, trophy, cart,
## car, calendar, gift, wheel, sound, music, home, lock and the "no entry" sign.


static func draw(item: CanvasItem, icon: String, c: Vector2, s: float, color: Color) -> void:
	match icon:
		"pause":
			for dx in [-0.2, 0.2]:
				_rounded(item, Rect2(c + Vector2(dx - 0.1, -0.34) * s, Vector2(0.2, 0.68) * s), s * 0.06, color)
		"retry":
			item.draw_arc(c, s * 0.3, -PI * 0.25, PI * 1.45, 28, color, s * 0.13, true)
			var tip := c + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * s * 0.3
			item.draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.2, -0.13) * s,
					tip + Vector2(0.12, -0.2) * s, tip + Vector2(0.06, 0.14) * s]), color)
		"back":
			item.draw_line(c + Vector2(0.3, 0) * s, c + Vector2(-0.22, 0) * s, color, s * 0.13, true)
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.36, 0) * s,
					c + Vector2(-0.08, -0.27) * s, c + Vector2(-0.08, 0.27) * s]), color)
		"gear":
			for k in 8:
				var a := k * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				item.draw_line(c + d * s * 0.2, c + d * s * 0.42, color, s * 0.16, false)
			item.draw_circle(c, s * 0.3, color)
			item.draw_circle(c, s * 0.12, Color(0, 0, 0, 0.25))
		"trophy":
			item.draw_colored_polygon(_cup(c, s), color)
			item.draw_arc(c + Vector2(-0.26, -0.16) * s, s * 0.12, PI * 0.5, PI * 1.5, 12, color, s * 0.07, true)
			item.draw_arc(c + Vector2(0.26, -0.16) * s, s * 0.12, -PI * 0.5, PI * 0.5, 12, color, s * 0.07, true)
			item.draw_rect(Rect2(c + Vector2(-0.06, 0.08) * s, Vector2(0.12, 0.16) * s), color)
			_rounded(item, Rect2(c + Vector2(-0.22, 0.22) * s, Vector2(0.44, 0.13) * s), s * 0.04, color)
		"cart":
			item.draw_polyline(PackedVector2Array([c + Vector2(-0.42, -0.3) * s, c + Vector2(-0.28, -0.3) * s,
					c + Vector2(-0.18, 0.14) * s, c + Vector2(0.3, 0.14) * s, c + Vector2(0.38, -0.18) * s,
					c + Vector2(-0.24, -0.18) * s]), color, s * 0.1, true)
			for x in [-0.12, 0.24]:
				item.draw_circle(c + Vector2(x, 0.3) * s, s * 0.08, color)
		"car":
			_rounded(item, Rect2(c + Vector2(-0.42, -0.06) * s, Vector2(0.84, 0.26) * s), s * 0.08, color)
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.26, -0.06) * s, c + Vector2(-0.16, -0.3) * s,
					c + Vector2(0.16, -0.3) * s, c + Vector2(0.26, -0.06) * s]), color)
			for x in [-0.22, 0.22]:
				item.draw_circle(c + Vector2(x, 0.22) * s, s * 0.1, Color(0.17, 0.19, 0.28))
		"calendar":
			_rounded(item, Rect2(c + Vector2(-0.36, -0.28) * s, Vector2(0.72, 0.64) * s), s * 0.1, color)
			item.draw_rect(Rect2(c + Vector2(-0.36, -0.2) * s, Vector2(0.72, 0.14) * s), Color(0, 0, 0, 0.22))
			for x in [-0.18, 0.18]:
				_rounded(item, Rect2(c + Vector2(x - 0.05, -0.42) * s, Vector2(0.1, 0.2) * s), s * 0.03, color)
			for k in 4:
				item.draw_circle(c + Vector2(-0.18 + (k % 2) * 0.36, 0.06 + (k / 2) * 0.16) * s, s * 0.05, Color(0, 0, 0, 0.25))
		"wheel":
			item.draw_arc(c, s * 0.36, 0.0, TAU, 32, color, s * 0.08, true)
			for k in 8:
				var d := Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0))
				item.draw_line(c + d * s * 0.08, c + d * s * 0.34, color, s * 0.06, true)
			item.draw_circle(c, s * 0.1, color)
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.1, -0.5) * s, c + Vector2(0.1, -0.5) * s,
					c + Vector2(0, -0.32) * s]), color)
		"gift":
			_rounded(item, Rect2(c + Vector2(-0.34, -0.08) * s, Vector2(0.68, 0.44) * s), s * 0.06, color)
			_rounded(item, Rect2(c + Vector2(-0.4, -0.22) * s, Vector2(0.8, 0.16) * s), s * 0.05, color)
			item.draw_rect(Rect2(c + Vector2(-0.06, -0.22) * s, Vector2(0.12, 0.58) * s), Color(0, 0, 0, 0.22))
			for side in [-1.0, 1.0]:
				item.draw_arc(c + Vector2(side * 0.12, -0.3) * s, s * 0.1, 0.0, TAU, 14, color, s * 0.07, true)
		"sound", "sound_off":
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.36, -0.12) * s, c + Vector2(-0.18, -0.12) * s,
					c + Vector2(0.04, -0.32) * s, c + Vector2(0.04, 0.32) * s, c + Vector2(-0.18, 0.12) * s,
					c + Vector2(-0.36, 0.12) * s]), color)
			if icon == "sound":
				item.draw_arc(c + Vector2(0.06, 0) * s, s * 0.18, -0.9, 0.9, 10, color, s * 0.07, true)
				item.draw_arc(c + Vector2(0.06, 0) * s, s * 0.32, -0.9, 0.9, 12, color, s * 0.07, true)
			else:
				item.draw_line(c + Vector2(0.14, -0.14) * s, c + Vector2(0.38, 0.14) * s, color, s * 0.09, true)
				item.draw_line(c + Vector2(0.14, 0.14) * s, c + Vector2(0.38, -0.14) * s, color, s * 0.09, true)
		"music", "music_off":
			item.draw_line(c + Vector2(-0.1, 0.22) * s, c + Vector2(-0.1, -0.3) * s, color, s * 0.08, true)
			item.draw_line(c + Vector2(0.24, 0.12) * s, c + Vector2(0.24, -0.38) * s, color, s * 0.08, true)
			item.draw_line(c + Vector2(-0.1, -0.3) * s, c + Vector2(0.24, -0.38) * s, color, s * 0.12, true)
			item.draw_circle(c + Vector2(-0.18, 0.24) * s, s * 0.11, color)
			item.draw_circle(c + Vector2(0.16, 0.14) * s, s * 0.11, color)
			if icon == "music_off":
				item.draw_line(c + Vector2(-0.38, -0.38) * s, c + Vector2(0.38, 0.38) * s, Color.WHITE, s * 0.16, true)
				item.draw_line(c + Vector2(-0.38, -0.38) * s, c + Vector2(0.38, 0.38) * s, color, s * 0.08, true)
		"home":
			item.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.38, -0.02) * s, c + Vector2(0, -0.36) * s,
					c + Vector2(0.38, -0.02) * s, c + Vector2(0.28, -0.02) * s, c + Vector2(0.28, 0.34) * s,
					c + Vector2(0.08, 0.34) * s, c + Vector2(0.08, 0.12) * s, c + Vector2(-0.08, 0.12) * s,
					c + Vector2(-0.08, 0.34) * s, c + Vector2(-0.28, 0.34) * s, c + Vector2(-0.28, -0.02) * s]), color)
		"lock":
			item.draw_arc(c + Vector2(0, -0.08) * s, s * 0.2, PI, TAU, 14, color, s * 0.09, true)
			_rounded(item, Rect2(c + Vector2(-0.3, -0.08) * s, Vector2(0.6, 0.44) * s), s * 0.08, color)
		"no_entry":
			item.draw_circle(c, s * 0.48, Color.WHITE)
			item.draw_circle(c, s * 0.42, Color("e5484d"))
			_rounded(item, Rect2(c + Vector2(-0.28, -0.08) * s, Vector2(0.56, 0.16) * s), s * 0.03, Color.WHITE)


static func _cup(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array([c + Vector2(-0.24, -0.36) * s, c + Vector2(0.24, -0.36) * s])
	for k in 9:
		var a := float(k) / 8.0 * PI
		pts.append(c + Vector2(cos(a) * 0.24, -0.14 + sin(a) * 0.24) * s)
	return pts


static func _rounded(item: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(maxf(radius, 1.0)))
	box.anti_aliasing = true
	item.draw_style_box(box, rect)
