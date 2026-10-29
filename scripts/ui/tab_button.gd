class_name TabButton
extends Button
## Item of the menu's bottom bar: a rounded candy square with an icon, its
## name underneath and an optional red dot.

var icon_name := "cart"
var face := Color("ff8a3d")
var caption := ""
var show_dot := false:
	set(value):
		show_dot = value
		queue_redraw()


func _init(p_icon: String, p_face: Color, p_caption: String) -> void:
	icon_name = p_icon
	face = p_face
	caption = p_caption
	custom_minimum_size = Vector2(112, 124)
	flat = true
	focus_mode = Control.FOCUS_NONE
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var side := 78.0
	var down := is_pressed()
	var rect := Rect2(Vector2((size.x - side) * 0.5, 4.0), Vector2(side, side + UiStyle.CANDY_SLAB))
	var box := StyleBoxTexture.new()
	box.texture = UiStyle.candy_texture(face, face.darkened(0.3), down)
	for m in ["texture_margin_left", "texture_margin_right", "texture_margin_top", "texture_margin_bottom"]:
		box.set(m, 30.0)
	draw_style_box(box, rect)
	var c := rect.position + Vector2(side * 0.5, side * 0.5 + (5.0 if down else 0.0))
	UiIcons.draw(self, icon_name, c, side * 0.62, Color.WHITE)
	var font := UiStyle.font(700)
	var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, Vector2((size.x - w) * 0.5, size.y - 6.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
	if show_dot:
		var d := rect.position + Vector2(side - 4.0, 4.0)
		draw_circle(d, 11.0, Color.WHITE)
		draw_circle(d, 8.0, UiStyle.DANGER)
