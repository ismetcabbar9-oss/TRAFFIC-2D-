class_name MainMenu
extends Control
## Main menu with pages: home (coins, play, world cards), world (level grid),
## settings and credits. Pages swap with a short fade.

const GAME_SCENE := "res://scenes/game.tscn"
const WORLD_COLORS := [Color("4aa3ff"), Color("ffb23e"), Color("5cc8e8"), Color("6a5acd"), Color("2ec4b6")]
const CREDITS := [
	"Vehicles: \"4 Low Poly Toon City Cars\" by tselikov.viktor, \"Free Low Poly Vehicles Pack\" by rgsdev (CC BY 4.0)",
	"Trees: \"Polygon Tree Pack\" by StreakByte (CC BY 4.0)",
	"Buildings: \"Low poly City Assets\" by Paulisia (CC BY 4.0)",
	"Street props: \"City Props Collection vol. 1\" by TampaJoey (Sketchfab Free Standard)",
	"Beach: \"Stylized Palm tree set\" by parelaxel, \"Coconut Tree\" by sujirour, \"Beach Umbrella\" by stealth86, \"Lifeguard's Chair\" and \"Resort\" by jaromir.ternavskiy (CC BY 4.0)",
	"Snow: \"Low Poly Snowy Trees\" by PeToDes, \"Snowman\" by LiveToWin34, \"Snowy Wooden Hut\" by gecko0307 (CC BY 4.0)",
	"Airport: \"Cartoon Plane\" by antonmoek (CC BY 4.0); hangar, control tower and baggage truck by assetfactory (Sketchfab Free Standard)",
	"Cones, sounds and jingles: Kenney (CC0)",
	"Sound effects: Freesound contributors (CC0)",
	"Music: \"Happy Clappy Loop\" by owlishmedia, \"Apple Cider\" by Zane Little Music, \"Sandy Seaside 2\" by spring-spring, \"Happy synths loop\" by 3xBlast, \"Chill lofi inspired\" by qubodup, \"City Loop\" by wipics (CC0)",
	"Font: Baloo 2 by Ek Type (SIL Open Font License)",
]

var _pages := {} ## name -> Control
var _current := ""
var _coin_label: Label
var _world := 0 ## world shown on the world page
## Set by the game so leaving a level lands on that world's level grid.
static var return_to_world := false


func _ready() -> void:
	Sfx.play_music("menu")
	theme = UiStyle.make_theme()
	_add_background()
	_pages["home"] = _page()
	_pages["world"] = _page()
	_pages["settings"] = _page()
	_pages["credits"] = _page()
	if return_to_world:
		return_to_world = false
		_world = Progress.current_world
		_show("world", false)
	else:
		_show("home", false)
	Progress.coins_changed.connect(func(_c): _refresh_coins())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current == "home":
			get_tree().quit()
		else:
			_click()
			_show("settings" if _current == "credits" else "home")


# --- Page plumbing -------------------------------------------------------------

func _add_background() -> void:
	var bg := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("bfe3f2"))
	gradient.set_color(1, Color("e7f6d9"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_to = Vector2(0, 1)
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _page() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var insets: Vector4 = get_node("/root/ScreenFit").safe_insets()
	margin.add_theme_constant_override("margin_left", 28 + int(insets.x))
	margin.add_theme_constant_override("margin_right", 28 + int(insets.z))
	margin.add_theme_constant_override("margin_top", 24 + int(insets.y))
	margin.add_theme_constant_override("margin_bottom", 32 + int(insets.w))
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	return column


## Shows a page (rebuilding its content), with a quick cross-fade.
func _show(page: String, animate := true) -> void:
	match page:
		"home": _build_home()
		"world": _build_world()
		"settings": _build_settings()
		"credits": _build_credits()
	for name in _pages:
		(_pages[name] as Control).get_parent().get_parent().visible = name == page
	var shown: Control = (_pages[page] as Control).get_parent().get_parent()
	if animate:
		shown.modulate.a = 0.0
		create_tween().tween_property(shown, "modulate:a", 1.0, 0.18)
	_current = page


static func _clear(page: Control) -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()


# --- Home ------------------------------------------------------------------------

func _build_home() -> void:
	var page: VBoxContainer = _pages["home"]
	_clear(page)

	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(_coin_pill())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.add_child(_small_button(tr("MENU_SETTINGS"), func(): _show("settings")))

	var title := Label.new()
	title.text = "Traffic Escape"
	title.add_theme_font_override("font", UiStyle.font(800))
	title.add_theme_font_size_override("font_size", 74)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("MENU_SUBTITLE")
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.3))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(subtitle)

	var play := Button.new()
	play.text = tr("MENU_PLAY")
	play.add_theme_font_size_override("font_size", 50)
	play.custom_minimum_size = Vector2(340, 0)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_continue)
	page.add_child(play)

	for w in LevelCatalog.world_count():
		page.add_child(_world_card(w))
	_refresh_coins()


## Opens the next unfinished level of the furthest unlocked world.
func _continue() -> void:
	var world := 0
	for w in LevelCatalog.world_count():
		if Progress.is_world_unlocked(w):
			world = w
	_open_level(world, Progress.next_open_level(world))


func _world_card(w: int) -> Button:
	var info: Dictionary = LevelCatalog.world(w)
	var has_levels := LevelCatalog.level_count(w) > 0
	var unlocked := Progress.is_world_unlocked(w)
	var color: Color = WORLD_COLORS[w % WORLD_COLORS.size()]
	if not unlocked:
		color = color.lerp(Color("c9ced8"), 0.65)

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 118)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(26)
	style.border_width_bottom = 8
	style.border_color = color.darkened(0.25)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(state, style)
	card.disabled = not unlocked
	card.pressed.connect(func():
		_click()
		_world = w
		_show("world"))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	names.add_child(_label(tr("WORLD_N") % (w + 1), 24, Color(1, 1, 1, 0.85)))
	names.add_child(_label(tr(info.name), 38, Color.WHITE))

	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status)
	if not has_levels:
		status.add_child(_label(tr("WORLD_SOON"), 26, Color.WHITE))
	elif not unlocked:
		status.add_child(_label(tr("WORLD_NEEDS_STARS") % int(info.stars_required), 24, Color.WHITE))
	else:
		status.add_child(StarIcon.new(34))
		status.add_child(_label("%d/%d" % [Progress.world_stars(w), LevelCatalog.level_count(w) * 3], 30, Color.WHITE))
	return card


# --- World (level grid) --------------------------------------------------------

func _build_world() -> void:
	var page: VBoxContainer = _pages["world"]
	_clear(page)
	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(_small_button(tr("BACK"), func(): _show("home")))
	var title := _label(tr(LevelCatalog.world(_world).name), 40, UiStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	bar.add_child(_coin_pill())

	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_child(StarIcon.new(30))
	stars.add_child(_label("%d/%d" % [Progress.world_stars(_world), LevelCatalog.level_count(_world) * 3], 28, UiStyle.INK))
	page.add_child(stars)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 18)
	page.add_child(grid)
	var next := Progress.next_open_level(_world)
	for i in LevelCatalog.level_count(_world):
		var tile := LevelTile.new()
		tile.custom_minimum_size = Vector2(112, 124)
		grid.add_child(tile)
		tile.setup(i, not Progress.is_level_unlocked(_world, i), Progress.level_stars(_world, i),
				LevelCatalog.is_hard(_world, i))
		tile.pressed.connect(_open_level.bind(_world, i))
		if i == next and Progress.level_stars(_world, i) == 0:
			_pulse(tile)
	_refresh_coins()


func _pulse(tile: Control) -> void:
	await get_tree().process_frame
	tile.pivot_offset = tile.size * 0.5
	var t := tile.create_tween().set_loops()
	t.tween_property(tile, "scale", Vector2.ONE * 1.08, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(tile, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


# --- Settings and credits ------------------------------------------------------

func _build_settings() -> void:
	var page: VBoxContainer = _pages["settings"]
	_clear(page)
	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(_small_button(tr("BACK"), func(): _show("home")))
	var title := _label(tr("SETTINGS_TITLE"), 44, UiStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	bar.add_child(Control.new()) # keeps the title centered-ish

	var panel := PanelContainer.new()
	page.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	_setting_row(rows, "SET_SOUND", tr("ON") if Progress.sound_on else tr("OFF"),
			func(): Progress.set_sound(not Progress.sound_on))
	_setting_row(rows, "SET_MUSIC", tr("ON") if Progress.music_on else tr("OFF"),
			func(): Progress.set_music(not Progress.music_on))
	_setting_row(rows, "SET_VIBRATION", tr("ON") if Progress.vibration_on else tr("OFF"),
			func(): Progress.set_vibration(not Progress.vibration_on))
	_setting_row(rows, "SET_SPEED", Progress.speed_label(), Progress.cycle_speed)
	_setting_row(rows, "SET_LANGUAGE", tr({"auto": "LANG_AUTO", "en": "LANG_EN", "tr": "LANG_TR"}[Progress.language]),
			Progress.cycle_language)

	var more := VBoxContainer.new()
	more.add_theme_constant_override("separation", 12)
	page.add_child(more)
	# Purchases and the privacy policy arrive with the store build (phase 4).
	for key in ["SET_RESTORE", "SET_PRIVACY"]:
		var b := _wide_button("%s  ·  %s" % [tr(key), tr("SOON_SHORT")], Callable())
		b.disabled = true
		more.add_child(b)
	more.add_child(_wide_button(tr("SET_CREDITS"), func(): _show("credits")))


func _setting_row(rows: VBoxContainer, key: String, value: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	var label := _label(tr(key), 32, UiStyle.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var b := _small_button(value, func():
		action.call()
		_show("settings", false))
	b.custom_minimum_size.x = 230
	row.add_child(b)


func _build_credits() -> void:
	var page: VBoxContainer = _pages["credits"]
	_clear(page)
	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(_small_button(tr("BACK"), func(): _show("settings")))
	var title := _label(tr("CREDITS_TITLE"), 44, UiStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var panel := PanelContainer.new()
	page.add_child(panel)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 14)
	panel.add_child(text)
	text.add_child(_label(tr("CREDITS_INTRO"), 28, UiStyle.INK, true))
	for line in CREDITS:
		text.add_child(_label("• " + line, 24, UiStyle.INK.lerp(Color.WHITE, 0.15), true))


# --- Helpers -----------------------------------------------------------------------

func _coin_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(30)
	style.content_margin_left = 14
	style.content_margin_right = 22
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	row.add_child(CoinIcon.new(34))
	_coin_label = _label(str(Progress.coins), 30, UiStyle.INK)
	row.add_child(_coin_label)
	return pill


func _refresh_coins() -> void:
	if is_instance_valid(_coin_label):
		_coin_label.text = str(Progress.coins)


static func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
	return l


func _small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "IconButton"
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func():
		_click()
		action.call())
	return b


func _wide_button(text: String, action: Callable) -> Button:
	var b := _small_button(text, action) if action.is_valid() else Button.new()
	if not action.is_valid():
		b.text = text
		b.theme_type_variation = "IconButton"
		b.add_theme_font_size_override("font_size", 26)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _click() -> void:
	Sfx.play("ui_click", -4.0)


func _open_level(world: int, level: int) -> void:
	if not Progress.is_level_unlocked(world, level):
		return
	_click()
	Progress.current_world = world
	Progress.current_level = level
	Transition.change_scene(GAME_SCENE)
