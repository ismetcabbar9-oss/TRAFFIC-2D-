class_name UiStyle
## Shared look of the 2D interface: fonts, colors and button/panel styles.

const FONT_PATH := "res://assets/fonts/Baloo2.ttf"

const INK := Color("2b3148")
const ACCENT := Color("ff8a3d")
const ACCENT_DARK := Color("e0661b")
const GOOD := Color("37c47a")
const GOOD_DARK := Color("249a5a")
const DANGER := Color("ff5a5f")
const MUTED := Color("c7ccd8")
const PANEL := Color("fffaf2")
const BLUE := Color("4aa3ff")
const BLUE_DARK := Color("2f7fd0")
const CANDY_RADIUS := 26
const CANDY_SLAB := 7 ## height of the darker base under a candy button

static var _candy_cache := {}


static func font(weight := 700) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(FONT_PATH)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font(700)
	theme.default_font_size = 34
	theme.set_color("font_color", "Label", INK)
	_button_styles(theme, "Button", ACCENT, ACCENT_DARK)
	theme.set_type_variation("GoodButton", "Button")
	_button_styles(theme, "GoodButton", GOOD, GOOD_DARK)
	theme.set_type_variation("IconButton", "Button")
	_button_styles(theme, "IconButton", Color.WHITE, MUTED)
	theme.set_color("font_color", "IconButton", INK)
	theme.set_color("font_hover_color", "IconButton", INK)
	theme.set_color("font_pressed_color", "IconButton", INK)
	theme.set_constant("outline_size", "IconButton", 0)
	theme.set_type_variation("BlueButton", "Button")
	_button_styles(theme, "BlueButton", BLUE, BLUE_DARK)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 36, Color(0, 0, 0, 0.25), 18))
	return theme


## "Candy" buttons: colored face with a white rim, a glossy upper half and a
## darker base that disappears when pressed (the button sinks).
static func _button_styles(theme: Theme, type: String, color: Color, edge: Color) -> void:
	theme.set_stylebox("normal", type, _candy(color, edge, false))
	theme.set_stylebox("hover", type, _candy(color, edge, false))
	theme.set_stylebox("pressed", type, _candy(color, edge, true))
	theme.set_stylebox("disabled", type, _candy(Color("dfe3ea"), Color("c3c9d4"), false))
	theme.set_color("font_disabled_color", type, Color("aab1bf"))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_color("font_color", type, Color.WHITE)
	theme.set_color("font_hover_color", type, Color.WHITE)
	theme.set_color("font_pressed_color", type, Color.WHITE)
	theme.set_color("font_outline_color", type, edge.darkened(0.1))
	theme.set_constant("outline_size", type, 7)
	theme.set_font_size("font_size", type, 36)


static func _candy(color: Color, edge: Color, pressed: bool) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = candy_texture(color, edge, pressed)
	var m := CANDY_RADIUS + 6
	box.texture_margin_left = m
	box.texture_margin_right = m
	box.texture_margin_top = m
	box.texture_margin_bottom = m
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 14 + (5 if pressed else 0)
	box.content_margin_bottom = 18 - (5 if pressed else 0)
	return box


## Nine-patch texture of a candy button (drawn once per color and state).
static func candy_texture(color: Color, edge: Color, pressed: bool) -> ImageTexture:
	var key := "%s/%s/%s" % [color.to_html(), edge.to_html(), pressed]
	if _candy_cache.has(key):
		return _candy_cache[key]
	const W := 96
	const H := 96
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var drop := 5 if pressed else 0 # a pressed button sits lower, on its base
	var face := Rect2(0.5, 0.5 + drop, W - 1.0, H - 1.0 - CANDY_SLAB)
	var base := Rect2(face.position + Vector2(0, CANDY_SLAB - drop), face.size)
	var r := float(CANDY_RADIUS)
	var gloss := color.lerp(Color.WHITE, 0.22)
	var gloss_line := face.position.y + face.size.y * 0.47
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5)
			var out := Color(0, 0, 0, 0)
			var a_base := _coverage(p, base, r)
			if a_base > 0.0:
				out = Color(edge, a_base)
			var a_rim := _coverage(p, face, r)
			if a_rim > 0.0:
				out = out.blend(Color(1, 1, 1, a_rim))
			var a_fill := _coverage(p, face.grow(-4.0), r - 4.0)
			if a_fill > 0.0:
				var fill := gloss if p.y < gloss_line else color
				out = out.blend(Color(fill, a_fill))
			img.set_pixel(x, y, out)
	var tex := ImageTexture.create_from_image(img)
	_candy_cache[key] = tex
	return tex


## Antialiased coverage of point `p` by a rounded rectangle.
static func _coverage(p: Vector2, rect: Rect2, radius: float) -> float:
	var half := rect.size * 0.5
	var q := (p - rect.get_center()).abs() - (half - Vector2.ONE * radius)
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
	return clampf(0.5 - d, 0.0, 1.0)


## Big outlined title (white letters, dark outline and drop).
static func style_title(label: Label, size: int) -> void:
	label.add_theme_font_override("font", font(800))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(size / 5, 6))
	label.add_theme_color_override("font_shadow_color", INK)
	label.add_theme_constant_override("shadow_offset_y", maxi(size / 14, 3))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_outline_size", maxi(size / 5, 6))


static func _box(color: Color, radius: int, shadow: Color, shadow_size: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0, shadow_size * 0.4)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 32
	box.content_margin_bottom = 32
	box.anti_aliasing = true
	return box
