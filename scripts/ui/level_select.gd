extends Control
## Main menu: title, play button, level grid and sound/vibration toggles.

const GAME_SCENE := "res://scenes/game.tscn"

var _grid: GridContainer
var _sound: Button
var _vibration: Button
var _speed: Button
var _column: VBoxContainer
var _title: Label


func _ready() -> void:
	theme = UiStyle.make_theme()
	_build()
	_refresh()
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


## Tighter spacing on short (landscape phone) screens.
func _fit_layout() -> void:
	var short := get_viewport_rect().size.y < 800.0
	_column.add_theme_constant_override("separation", 14 if short else 26)
	_title.add_theme_font_size_override("font_size", 60 if short else 78)


func _build() -> void:
	var bg := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("bfe3f2"))
	gradient.set_color(1, Color("e7f6d9"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)
	_column = column

	_title = Label.new()
	_title.text = "Traffic Escape"
	_title.add_theme_font_override("font", UiStyle.font(800))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var subtitle := Label.new()
	subtitle.text = "Doğru sırayla otoparkı boşalt!"
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.3))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var play := Button.new()
	play.text = "Oyna"
	play.add_theme_font_size_override("font_size", 48)
	play.custom_minimum_size = Vector2(320, 0)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): _open_level(mini(Progress.unlocked - 1, LevelCatalog.count() - 1)))
	column.add_child(play)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_grid)
	for i in LevelCatalog.count():
		var tile := LevelTile.new()
		tile.custom_minimum_size = Vector2(112, 112)
		tile.pressed.connect(_open_level.bind(i))
		_grid.add_child(tile)

	var settings := HBoxContainer.new()
	settings.alignment = BoxContainer.ALIGNMENT_CENTER
	settings.add_theme_constant_override("separation", 16)
	column.add_child(settings)
	_sound = _toggle_button(func(): Progress.set_sound(not Progress.sound_on))
	settings.add_child(_sound)
	_vibration = _toggle_button(func(): Progress.set_vibration(not Progress.vibration_on))
	settings.add_child(_vibration)
	_speed = _toggle_button(Progress.cycle_speed)
	settings.add_child(_speed)


func _toggle_button(on_press: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "IconButton"
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func():
		on_press.call()
		Sfx.play("ui_click", -4.0)
		_refresh())
	return b


func _refresh() -> void:
	for tile: LevelTile in _grid.get_children():
		tile.setup(tile.get_index(), not Progress.is_unlocked(tile.get_index()), Progress.is_completed(tile.get_index()))
		var is_next := tile.get_index() == Progress.unlocked - 1 and not tile.done
		if is_next and not tile.has_meta("pulsing"):
			tile.set_meta("pulsing", true)
			_pulse(tile)
	_sound.text = "Ses: %s" % ("Açık" if Progress.sound_on else "Kapalı")
	_vibration.text = "Titreşim: %s" % ("Açık" if Progress.vibration_on else "Kapalı")
	_speed.text = "Hız: %s" % Progress.speed_label()


func _pulse(tile: Control) -> void:
	await get_tree().process_frame
	tile.pivot_offset = tile.size * 0.5
	var t := tile.create_tween().set_loops()
	t.tween_property(tile, "scale", Vector2.ONE * 1.08, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(tile, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _open_level(index: int) -> void:
	if not Progress.is_unlocked(index):
		return
	Sfx.play("ui_click", -4.0)
	Progress.current_level = index
	get_tree().change_scene_to_file(GAME_SCENE)
