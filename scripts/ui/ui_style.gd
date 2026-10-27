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
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, 36, Color(0, 0, 0, 0.25), 18))
	return theme


static func _button_styles(theme: Theme, type: String, color: Color, edge: Color) -> void:
	var normal := _box(color, 26, edge, 0)
	normal.border_width_bottom = 8
	normal.border_color = edge
	normal.content_margin_left = 36
	normal.content_margin_right = 36
	normal.content_margin_top = 12
	normal.content_margin_bottom = 18
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_width_bottom = 2
	pressed.content_margin_top = 18
	pressed.content_margin_bottom = 12
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, normal)
	theme.set_stylebox("pressed", type, pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("dfe3ea")
	disabled.border_color = Color("c3c9d4")
	theme.set_stylebox("disabled", type, disabled)
	theme.set_color("font_disabled_color", type, Color("aab1bf"))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_color("font_color", type, Color.WHITE)
	theme.set_color("font_hover_color", type, Color.WHITE)
	theme.set_color("font_pressed_color", type, Color.WHITE)
	theme.set_font_size("font_size", type, 36)


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
