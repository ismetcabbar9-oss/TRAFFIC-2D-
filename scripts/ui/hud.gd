class_name Hud
extends CanvasLayer
## In-game interface: top bar (menu, level, wrong moves left, restart), combo
## pop-ups, the first-time tutorial card and the win / lose result panel with
## its confetti celebration.

signal restart_requested
signal next_requested
signal menu_requested
signal tutorial_closed

var _title: Label
var _time_label: Label
var _meter: MistakeMeter
var _overlay: Control
var _panel: PanelContainer
var _result_title: Label
var _result_text: Label
var _primary: Button
var _secondary: Button
var _won := false
var _hint: PanelContainer
var _hint_label: Label
var _last_level := false
var _root: Control
var _badge: Label


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.make_theme()
	add_child(root)
	_root = root
	_build_top_bar(root)
	_build_hint(root)
	_build_result(root)


func set_level_title(text: String) -> void:
	_title.text = text


func set_time_of_day(text: String) -> void:
	_time_label.text = text + "  ·"


func set_mistakes(left: int, total: int) -> void:
	_meter.set_counts(left, total)


## `last_level`: no level follows, so the panel leads back to the menu.
## `perfect`: cleared without a single crash.
func show_win(last_level: bool, perfect := false) -> void:
	_won = true
	_badge.visible = perfect
	# Behind the panel, in front of the dimmed board.
	var confetti := Confetti.new()
	_overlay.add_child(confetti)
	_overlay.move_child(confetti, 0)
	Sfx.play("celebrate", -4.0, 1.0, 0.0)
	_last_level = last_level
	_result_title.text = "Harika!"
	_result_title.add_theme_color_override("font_color", UiStyle.GOOD_DARK)
	_result_text.text = "Tüm bölümleri bitirdin!" if last_level else "Otopark boşaldı."
	_primary.text = "Menü" if last_level else "Sonraki Bölüm"
	_secondary.visible = not last_level
	_primary.theme_type_variation = "GoodButton"
	_show_result()


func show_lose() -> void:
	_won = false
	_result_title.text = "Sıkıştın!"
	_result_title.add_theme_color_override("font_color", UiStyle.DANGER)
	_result_text.text = "Hamle hakkın bitti."
	_primary.text = "Tekrar Dene"
	_primary.theme_type_variation = ""
	_secondary.visible = true
	_badge.visible = false
	_show_result()


## Floating "x3 Süper!" over the car that just left; `at` is a screen position.
func show_combo(count: int, at: Vector2) -> void:
	var words := ["", "", "", "Süper!", "Harika!"]
	var label := Label.new()
	label.text = "x%d %s" % [count, words[count] if count < words.size() else "Muhteşem!"]
	label.add_theme_font_override("font", UiStyle.font(800))
	label.add_theme_font_size_override("font_size", 46 + mini(count, 6) * 4)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", UiStyle.ACCENT_DARK)
	label.add_theme_constant_override("outline_size", 12)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	await get_tree().process_frame
	label.pivot_offset = label.size * 0.5
	label.position = _root.get_global_transform_with_canvas().affine_inverse() * at - label.size * 0.5
	label.scale = Vector2.ONE * 0.4
	var t := label.create_tween().set_parallel()
	t.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y - 110.0, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.6)
	t.chain().tween_callback(label.queue_free)


## One-time "how to play" card; emits `tutorial_closed` when dismissed.
func show_tutorial() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Nasıl oynanır?"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for line in ["Bir arabaya dokun: okun gösterdiği yöne gider.",
			"Yolu açıksa otoparktan çıkar.",
			"Önü kapalıysa çarpar ve bir hamle hakkın gider.",
			"Doğru sırayla tüm arabaları çıkar!"]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 28)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 460
		box.add_child(l)
	var go := Button.new()
	go.text = "Başla"
	go.theme_type_variation = "GoodButton"
	box.add_child(go)
	go.pressed.connect(func():
		_click()
		var t := dim.create_tween()
		t.tween_property(dim, "modulate:a", 0.0, 0.2)
		t.tween_callback(dim.queue_free)
		tutorial_closed.emit())
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.25)


func show_hint(text: String) -> void:
	_hint_label.text = text
	if _hint.visible:
		return
	_hint.visible = true
	_hint.modulate.a = 0.0
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.3)


func hide_hint() -> void:
	_hint.visible = false


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
	# Soft backdrop so the bar stays readable over trees and houses.
	var backdrop := TextureRect.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.82))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill_from = Vector2(0, 0.55)
	tex.fill_to = Vector2(0, 1)
	backdrop.texture = tex
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_TOP_WIDE)
	backdrop.offset_bottom = 190 + get_node("/root/ScreenFit").safe_insets().y
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var insets: Vector4 = get_node("/root/ScreenFit").safe_insets()
	margin.add_theme_constant_override("margin_left", 28 + int(insets.x))
	margin.add_theme_constant_override("margin_right", 28 + int(insets.z))
	margin.add_theme_constant_override("margin_top", 24 + int(insets.y))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(rows)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(bar)
	bar.add_child(_small_button("Menü", menu_requested.emit))
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 42)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	bar.add_child(_small_button("Tekrar", restart_requested.emit))

	var meter_row := HBoxContainer.new()
	meter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meter_row.add_theme_constant_override("separation", 12)
	meter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(meter_row)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 24)
	_time_label.add_theme_color_override("font_color", UiStyle.ACCENT_DARK)
	meter_row.add_child(_time_label)
	var caption := Label.new()
	caption.text = "Hamle hakkı"
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.25))
	meter_row.add_child(caption)
	_meter = MistakeMeter.new()
	meter_row.add_child(_meter)


func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "IconButton"
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(_click)
	b.pressed.connect(action)
	return b


func _build_hint(root: Control) -> void:
	var anchor := MarginContainer.new()
	anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var insets: Vector4 = get_node("/root/ScreenFit").safe_insets()
	anchor.add_theme_constant_override("margin_bottom", 40 + int(insets.w))
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anchor)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(center)
	_hint = PanelContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.17, 0.19, 0.28, 0.85)
	box.set_corner_radius_all(24)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_hint.add_theme_stylebox_override("panel", box)
	_hint.visible = false
	center.add_child(_hint)
	_hint_label = Label.new()
	_hint_label.add_theme_color_override("font_color", Color.WHITE)
	_hint_label.add_theme_font_size_override("font_size", 30)
	_hint.add_child(_hint_label)


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

	_badge = Label.new()
	_badge.text = "Hatasız bitirdin!"
	_badge.add_theme_font_size_override("font_size", 30)
	_badge.add_theme_color_override("font_color", UiStyle.ACCENT_DARK)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.visible = false
	box.add_child(_badge)

	_result_text = Label.new()
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_text)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	_primary = Button.new()
	_primary.pressed.connect(_on_primary)
	buttons.add_child(_primary)
	_secondary = Button.new()
	_secondary.text = "Menü"
	_secondary.theme_type_variation = "IconButton"
	_secondary.pressed.connect(func():
		_click()
		menu_requested.emit())
	buttons.add_child(_secondary)


func _click() -> void:
	Sfx.play("ui_click", -4.0)


func _on_primary() -> void:
	_click()
	hide_result()
	if _won and _last_level:
		menu_requested.emit()
	elif _won:
		next_requested.emit()
	else:
		restart_requested.emit()
