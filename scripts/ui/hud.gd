class_name Hud
extends CanvasLayer
## In-game interface: top bar (level, wrong moves left, restart) and the
## win / lose result panel.

signal restart_requested
signal next_requested

var _title: Label
var _meter: MistakeMeter
var _overlay: Control
var _panel: PanelContainer
var _result_title: Label
var _result_text: Label
var _primary: Button
var _won := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.make_theme()
	add_child(root)
	_build_top_bar(root)
	_build_result(root)


func set_level_title(text: String) -> void:
	_title.text = text


func set_mistakes(left: int, total: int) -> void:
	_meter.set_counts(left, total)


func show_win() -> void:
	_won = true
	_result_title.text = "Harika!"
	_result_title.add_theme_color_override("font_color", UiStyle.GOOD_DARK)
	_result_text.text = "Otopark boşaldı."
	_primary.text = "Devam"
	_primary.theme_type_variation = "GoodButton"
	_show_result()


func show_lose() -> void:
	_won = false
	_result_title.text = "Sıkıştın!"
	_result_title.add_theme_color_override("font_color", UiStyle.DANGER)
	_result_text.text = "Hamle hakkın bitti."
	_primary.text = "Tekrar Dene"
	_primary.theme_type_variation = ""
	_show_result()


func hide_result() -> void:
	_overlay.visible = false


func _show_result() -> void:
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.7
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_top_bar(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(bar)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 42)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_stretch_ratio = 1.0
	bar.add_child(_title)

	var middle := VBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 0)
	bar.add_child(middle)
	var caption := Label.new()
	caption.text = "Hamle hakkı"
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.25))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(caption)
	_meter = MistakeMeter.new()
	middle.add_child(_meter)

	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(right)
	var restart := Button.new()
	restart.text = "Tekrar"
	restart.theme_type_variation = "IconButton"
	restart.add_theme_font_size_override("font_size", 28)
	restart.pressed.connect(restart_requested.emit)
	right.add_child(restart)


func _build_result(root: Control) -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.1, 0.12, 0.2, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_panel.add_child(box)

	_result_title = Label.new()
	_result_title.add_theme_font_size_override("font_size", 72)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)

	_result_text = Label.new()
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_text)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	_primary = Button.new()
	_primary.pressed.connect(_on_primary)
	buttons.add_child(_primary)


func _on_primary() -> void:
	hide_result()
	if _won:
		next_requested.emit()
	else:
		restart_requested.emit()
