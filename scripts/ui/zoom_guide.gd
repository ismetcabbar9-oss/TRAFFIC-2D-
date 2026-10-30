class_name ZoomGuide
extends Control
## First-time gesture guide over the board: two fingertips spreading and
## closing (pinch to zoom), then one dragging (pan), with a caption, a note
## about double tap and an "OK" button. The game moves the camera in step
## (see Game._zoom_tutorial) and closes it when the player pinches or taps OK.

signal closed

var fingers: Array[Vector2] = [] ## fingertip positions now (screen pixels)
var _caption: Label
var _note: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE # pinches reach the game underneath


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_top = -330
	box.offset_bottom = -190
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	_caption = Label.new()
	_caption.add_theme_font_override("font", UiStyle.font(800))
	_caption.add_theme_font_size_override("font_size", 32)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_caption)
	_note = Label.new()
	_note.text = tr("ZOOM_TUT_DOUBLE")
	_note.add_theme_font_size_override("font_size", 22)
	_note.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.35))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(_note)
	var ok := Button.new()
	ok.text = tr("ZOOM_TUT_OK")
	ok.theme_type_variation = "GoodButton"
	ok.custom_minimum_size = Vector2(260, 70)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func():
		Sfx.play("ui_click", -4.0)
		closed.emit())
	box.add_child(ok)


func set_caption(key: String) -> void:
	_caption.text = tr(key)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for p in fingers:
		draw_circle(p + Vector2(4, 6), 30.0, Color(0, 0, 0, 0.22)) # shadow
		draw_circle(p, 30.0, Color(1, 1, 1, 0.9))
		draw_arc(p, 30.0, 0.0, TAU, 40, Color(0.12, 0.14, 0.2, 0.85), 4.0, true)
		draw_circle(p, 12.0, Color("ffb23e"))
