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
static var _gift_offered := false
var _title_taps := 0
var _title_tap_time := 0.0


func _ready() -> void:
	Sfx.play_music("menu")
	theme = UiStyle.make_theme()
	_add_background()
	_pages["home"] = _page()
	_pages["world"] = _page()
	_pages["settings"] = _page()
	_pages["credits"] = _page()
	_pages["shop"] = _page()
	_pages["garage"] = _page()
	_pages["gift"] = _page()
	_pages["achievements"] = _page()
	_pages["dev"] = _page()
	if return_to_world:
		return_to_world = false
		_world = Progress.current_world
		_show("world", false)
	else:
		_show("home", false)
		# Once per launch, greet the player with the gift waiting for them.
		if not _gift_offered and Progress.tutorial_seen and Progress.gift_day() >= 0:
			_gift_offered = true
			_show("gift", false)
	Progress.coins_changed.connect(func(_c): _refresh_coins())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _current == "home":
			get_tree().quit()
		else:
			_click()
			_show({"credits": "settings", "dev": "settings", "world": "home"}.get(_current, "home"))


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
		"shop": _build_shop()
		"garage": _build_garage()
		"gift": _build_gift()
		"achievements": _build_achievements()
		"dev": _build_dev()
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
	var trophies := _small_button(tr("MENU_ACHIEVEMENTS"), func(): _show("achievements"))
	bar.add_child(trophies)
	if Achievements.any_claimable(Progress):
		_add_dot(trophies)
	bar.add_child(_small_button(tr("MENU_SETTINGS"), func(): _show("settings")))

	var title := Label.new()
	title.text = "Traffic Escape"
	title.add_theme_font_override("font", UiStyle.font(800))
	title.add_theme_font_size_override("font_size", 74)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Seven taps on the title switch developer mode on (debug builds only).
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_on_title_input)
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

	var extras := GridContainer.new()
	extras.columns = 2
	extras.add_theme_constant_override("h_separation", 16)
	extras.add_theme_constant_override("v_separation", 14)
	page.add_child(extras)
	var streak := Progress.daily_streak()
	var puzzle_text := tr("MENU_DAILY_DONE") if Progress.daily_done_today() else tr("MENU_DAILY")
	if streak > 0:
		puzzle_text += "  ·  " + tr("STREAK_N") % streak
	var puzzle := _wide_button(puzzle_text, _start_daily)
	extras.add_child(puzzle)
	var gift := _wide_button(tr("MENU_GIFT"), func(): _show("gift"))
	extras.add_child(gift)
	if Progress.gift_day() >= 0:
		_add_dot(gift)
	for entry in [["MENU_SHOP", "shop"], ["MENU_GARAGE", "garage"]]:
		var b := _wide_button(tr(entry[0]), func(): _show(entry[1]))
		extras.add_child(b)

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
	if Progress.dev_enabled():
		more.add_child(_wide_button(tr("DEV_TITLE"), func(): _show("dev")))


func _setting_row(rows: VBoxContainer, key: String, value: String, action: Callable, page := "settings") -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	var label := _label(tr(key), 32, UiStyle.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 180
	row.add_child(label)
	var b := _small_button(value, func():
		action.call()
		_show(page, false))
	b.custom_minimum_size.x = 200
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


# --- Shop and garage ----------------------------------------------------------------

func _page_header(page: VBoxContainer, title_key: String, back_to: String) -> void:
	var bar := HBoxContainer.new()
	page.add_child(bar)
	bar.add_child(_small_button(tr("BACK"), func(): _show(back_to)))
	var title := _label(tr(title_key), 42, UiStyle.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(title)
	bar.add_child(_coin_pill())


func _section(page: VBoxContainer, key: String) -> void:
	var l := _label(tr(key), 30, UiStyle.INK.lerp(Color.WHITE, 0.25))
	page.add_child(l)


## Rescue packs for coins, free coins for an ad, and (phase 4) the store.
func _build_shop() -> void:
	var page: VBoxContainer = _pages["shop"]
	_clear(page)
	_page_header(page, "SHOP_TITLE", "home")
	var have := _label(tr("SHOP_YOU_HAVE") % [Progress.item_count("hint"), Progress.item_count("undo"),
			Progress.item_count("crane")], 26, UiStyle.INK)
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(have)
	_section(page, "SHOP_RESCUES")
	var shop: Dictionary = Economy.value("shop")
	for pack in shop.packs:
		var parts := PackedStringArray()
		for item in pack.items:
			parts.append("%s ×%d" % [tr("RESCUE_" + str(item).to_upper()), int(pack.items[item])])
		var buy := func():
			if Progress.spend_coins(int(pack.price)):
				for item in pack.items:
					Progress.add_item(item, int(pack.items[item]))
				Sfx.play("combo", -4.0, 1.2, 0.0)
				_show("shop", false)
		_shop_row(page, tr(pack.id), " · ".join(parts), "%d" % int(pack.price), true,
				Progress.coins >= int(pack.price), buy)
	var free := int(shop.free_coins)
	_shop_row(page, tr("SHOP_FREE_COINS") % free, tr("SHOP_FREE_COINS_SUB"), tr("OFFER_AD"), false,
			AdManager.rewarded_available("free_coins"), func():
				AdManager.show_rewarded("free_coins", func():
					Progress.add_coins(free)
					_show("shop", false)))
	_section(page, "SHOP_STORE")
	for key in ["STORE_AD_FREE", "STORE_STARTER", "STORE_COINS_S", "STORE_COINS_M", "STORE_COINS_L"]:
		_shop_row(page, tr(key), tr(key + "_SUB"), tr("SOON_SHORT"), false, false, Callable())


## Panel row: title and detail on the left, action button on the right.
func _shop_row(page: VBoxContainer, title: String, detail: String, action: String, is_price: bool,
		enabled: bool, on_press: Callable) -> void:
	var panel := PanelContainer.new()
	page.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(_label(title, 30, UiStyle.INK))
	var d := _label(detail, 22, UiStyle.INK.lerp(Color.WHITE, 0.3), true)
	d.custom_minimum_size.x = 360
	texts.add_child(d)
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	b.disabled = not enabled
	if is_price:
		b.text = "   " + action
		var coin := CoinIcon.new(28)
		coin.position = Vector2(26, 0)
		b.add_child(coin)
		b.resized.connect(func(): coin.position = Vector2(30, (b.size.y - 28) * 0.5))
	else:
		b.text = action
		b.theme_type_variation = "GoodButton"
	if on_press.is_valid():
		b.pressed.connect(func():
			_click()
			on_press.call())
	row.add_child(b)


## Cosmetic unlocks per category; tap to buy (coins) or to equip.
func _build_garage() -> void:
	var page: VBoxContainer = _pages["garage"]
	_clear(page)
	_page_header(page, "GARAGE_TITLE", "home")
	var note := _label(tr("GARAGE_NOTE"), 24, UiStyle.INK.lerp(Color.WHITE, 0.3), true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(note)
	for category in Cosmetics.CATEGORIES:
		_section(page, "GARAGE_" + category.to_upper())
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		page.add_child(grid)
		for item in Cosmetics.items(category):
			var tile := GarageTile.new()
			grid.add_child(tile)
			var id: String = item.id
			var equipped_id := Progress.equipped(category)
			if equipped_id == "":
				equipped_id = Cosmetics.items(category)[0].id
			tile.setup(category, item, Progress.owns(id), id == equipped_id)
			tile.pressed.connect(func():
				if Progress.owns(id):
					_click()
					Progress.equip(id)
				elif Progress.buy_cosmetic(id):
					Sfx.play("combo", -4.0, 1.2, 0.0)
					Progress.equip(id)
				else:
					Sfx.play("lock_rattle", -4.0)
					_shake(tile)
					return
				_show("garage", false))


func _shake(node: Control) -> void:
	var start := node.position
	var t := node.create_tween()
	for dx in [10.0, -8.0, 5.0, 0.0]:
		t.tween_property(node, "position:x", start.x + dx, 0.05)


# --- Daily gift, daily puzzle and achievements ----------------------------------------

## Seven-day calendar; today's gift can be taken once (or doubled with an ad).
func _build_gift() -> void:
	var page: VBoxContainer = _pages["gift"]
	_clear(page)
	_page_header(page, "GIFT_TITLE", "home")
	var note := _label(tr("GIFT_NOTE"), 24, UiStyle.INK.lerp(Color.WHITE, 0.3), true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(note)
	var today := Progress.gift_display_day()
	var claimable := Progress.gift_day() >= 0
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(grid)
	for day in Daily.GIFT_REWARDS.size():
		var done := day < today or (day == today and not claimable)
		grid.add_child(_gift_tile(day, done, day == today and claimable))
	var take := Button.new()
	take.text = tr("GIFT_TAKE") if claimable else tr("GIFT_COME_BACK")
	take.disabled = not claimable
	take.theme_type_variation = "GoodButton"
	take.pressed.connect(func():
		_click()
		Progress.claim_gift()
		Sfx.play("celebrate", -4.0)
		_show("gift", false))
	page.add_child(take)
	if claimable and AdManager.rewarded_available("daily_gift"):
		var double := Button.new()
		double.text = tr("GIFT_DOUBLE")
		double.pressed.connect(func():
			_click()
			AdManager.show_rewarded("daily_gift", func():
				Progress.claim_gift(2)
				Sfx.play("celebrate", -4.0)
				_show("gift", false)))
		page.add_child(double)


func _gift_tile(day: int, done: bool, is_today: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff4d6") if is_today else (Color("e3f7ea") if done else Color.WHITE)
	style.set_corner_radius_all(20)
	style.set_border_width_all(4 if is_today else 0)
	style.border_color = UiStyle.ACCENT
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := _label(tr("GIFT_DAY") % (day + 1), 22, UiStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var coin := CoinIcon.new(44)
	coin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(coin)
	var amount := "%d" % Daily.GIFT_REWARDS[day]
	if day == Daily.GIFT_REWARDS.size() - 1:
		amount += " + " + tr("RESCUE_CRANE")
	var value := _label(amount, 22 if day < 6 else 18, UiStyle.ACCENT_DARK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	if done:
		var check := _label(tr("GIFT_TAKEN"), 18, UiStyle.GOOD_DARK)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(check)
	return panel


## Builds (or loads) today's puzzle on a worker thread, then starts it.
func _start_daily() -> void:
	Daily.prepare()
	if not Daily.is_ready():
		var veil := ColorRect.new()
		veil.color = Color(0.1, 0.12, 0.2, 0.6)
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(veil)
		var l := _label(tr("DAILY_PREPARING"), 34, Color.WHITE)
		l.set_anchors_preset(Control.PRESET_CENTER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		veil.add_child(l)
		while not Daily.is_ready():
			await get_tree().process_frame
	Daily.start()
	Transition.change_scene(GAME_SCENE)


func _build_achievements() -> void:
	var page: VBoxContainer = _pages["achievements"]
	_clear(page)
	_page_header(page, "ACH_TITLE", "home")
	for entry in Achievements.LIST:
		var value := mini(Achievements.stat(Progress, entry.stat), int(entry.goal))
		var done := Achievements.is_done(Progress, entry)
		var claimed: bool = entry.id in Progress.claimed
		var panel := PanelContainer.new()
		page.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var star := StarIcon.new(46, done)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(star)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		var name_label := _label(tr("ACH_" + str(entry.id).to_upper()), 26, UiStyle.INK)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size.x = 200
		texts.add_child(name_label)
		var bar := ProgressBar.new()
		bar.max_value = int(entry.goal)
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		texts.add_child(bar)
		texts.add_child(_label("%d / %d" % [value, int(entry.goal)], 20, UiStyle.INK.lerp(Color.WHITE, 0.35)))
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 24)
		if claimed:
			b.text = tr("ACH_COLLECTED")
			b.disabled = true
			b.theme_type_variation = "IconButton"
		else:
			b.text = "+%d" % int(entry.coins)
			b.disabled = not done
			b.theme_type_variation = "GoodButton" if done else ""
			var id: String = entry.id
			b.pressed.connect(func():
				_click()
				if Progress.claim_achievement(id) > 0:
					Sfx.play("celebrate", -4.0)
				_show("achievements", false))
		row.add_child(b)


## Small red dot in the top-right corner of a button (something to collect).
static func _add_dot(button: Control) -> void:
	var dot := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.DANGER
	style.set_corner_radius_all(10)
	dot.add_theme_stylebox_override("panel", style)
	dot.size = Vector2(20, 20)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(dot)
	button.resized.connect(func(): dot.position = Vector2(button.size.x - 16, -4))


# --- Developer mode ------------------------------------------------------------------

func _on_title_input(event: InputEvent) -> void:
	# Touches reach the GUI as emulated mouse clicks, so only clicks count.
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not Progress.dev_available():
		return
	var now := Time.get_ticks_msec() / 1000.0
	_title_taps = _title_taps + 1 if now - _title_tap_time < 1.5 else 1
	_title_tap_time = now
	if _title_taps >= 7:
		_title_taps = 0
		Progress.set_dev("enabled", not Progress.dev_enabled())
		Sfx.play("celebrate", -4.0)
		_show("dev" if Progress.dev_enabled() else "home")


## Developer tools: unlock everything, coins and rescues, resets.
func _build_dev() -> void:
	var page: VBoxContainer = _pages["dev"]
	_clear(page)
	_page_header(page, "DEV_TITLE", "settings")
	var note := _label(tr("DEV_NOTE"), 22, UiStyle.INK.lerp(Color.WHITE, 0.3), true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(note)

	var panel := PanelContainer.new()
	page.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	for flag in ["unlock_all", "unlimited_ads"]:
		_setting_row(rows, "DEV_" + flag.to_upper(), tr("ON") if Progress.dev_flag(flag) else tr("OFF"),
				func(): Progress.set_dev(flag, not Progress.dev_flag(flag)), "dev")

	var actions := [
		["DEV_COINS", func(): Progress.add_coins(1000)],
		["DEV_RESCUES", func():
			for item in ["hint", "undo", "crane"]:
				Progress.add_item(item, 5)],
		["DEV_ALL_STARS", func():
			for w in LevelCatalog.world_count():
				for l in LevelCatalog.level_count(w):
					if Progress.level_stars(w, l) == 0:
						Progress.levels["%d:%d" % [w, l]] = {"stars": 3, "time": -1.0, "combo": 0}
			Progress.save()],
		["DEV_GIFT", func():
			Progress.gift = {}
			Progress.save()],
		["DEV_DAILY", func():
			Progress.daily_puzzle = {}
			Daily.clear_cache()
			Progress.save()],
		["DEV_DAILY_RANDOM", func():
			Daily.prepare("%d-%02d-%02d" % [2000 + randi() % 50, 1 + randi() % 12, 1 + randi() % 28])
			while not Daily.is_ready():
				await get_tree().process_frame
			Daily.start()
			Transition.change_scene(GAME_SCENE)],
		["DEV_TIPS", func():
			Progress.tutorial_seen = false
			Progress.tips_seen = []
			Progress.flags.erase("crane_gift")
			Progress.save()],
		["DEV_FREE_HINTS", func():
			Progress.daily = {}
			Progress.save()],
		["DEV_TROPHIES", func():
			Progress.claimed = []
			Progress.save()],
		["DEV_GARAGE", func():
			Progress.owned = []
			Progress.equipped_items = {}
			Progress.save()],
	]
	for entry in actions:
		var key: String = entry[0]
		var action: Callable = entry[1]
		page.add_child(_wide_button(tr(key), func():
			await action.call()
			_toast(tr("DEV_DONE"))
			_show("dev", false)))
	var reset := _wide_button(tr("DEV_RESET"), func(): _confirm_reset())
	reset.add_theme_color_override("font_color", UiStyle.DANGER)
	page.add_child(reset)
	page.add_child(_wide_button(tr("DEV_OFF"), func():
		Progress.set_dev("enabled", false)
		_show("settings")))


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("DEV_RESET_CONFIRM")
	dialog.ok_button_text = tr("DEV_RESET")
	dialog.cancel_button_text = tr("OFFER_CANCEL")
	add_child(dialog)
	dialog.confirmed.connect(func():
		Progress.reset_progress()
		_show("dev", false))
	dialog.popup_centered()


## Short message at the bottom of the screen.
func _toast(text: String) -> void:
	var l := _label(text, 28, Color.WHITE)
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.19, 0.28, 0.9)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel", style)
	box.add_child(l)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	await get_tree().process_frame
	var vp := get_viewport_rect().size
	box.position = Vector2((vp.x - box.size.x) * 0.5, vp.y - box.size.y - 60.0)
	var t := box.create_tween()
	t.tween_interval(1.0)
	t.tween_property(box, "modulate:a", 0.0, 0.3)
	t.tween_callback(box.queue_free)


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
