class_name Hud
extends CanvasLayer
## In-game interface: top bar (menu, level, wrong moves left, restart), the
## rescue bar at the bottom (coins, hint, undo, crane), combo pop-ups, tip
## cards, rescue offers and the win / lose result panel with its confetti.

signal restart_requested
signal next_requested
signal menu_requested
signal tutorial_closed
signal rescue_pressed(kind: String) ## "hint", "undo" or "crane"
signal offer_accepted(kind: String, with_ad: bool) ## pay for a rescue
signal continue_requested(with_ad: bool) ## the lose panel's rescue: +2 moves, rewind or rush continue
signal bomb_time_requested ## the "+3" button next to a bomb about to go off
signal double_coins_requested
signal dev_requested ## developer mode panel
signal paused_changed(paused: bool) ## the pause panel opened or closed

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
var _retry_button: Button
var _retry_pulse: Tween
var _star_row: HBoxContainer
var _stars: Array[StarIcon] = []
var _stats: VBoxContainer
var _time_value: Label
var _record_tag: Label
var _combo_value: Label
var _coin_value: Label
var _rescue_buttons := {} ## kind -> RescueButton
var _star_note: Label ## why the third star was missed
var _rush_bar: ProgressBar ## endless mode: time until the next car arrives
var _bomb_button: Button ## "Bomb +3" rescue while a bomb is about to blow
var _continue_pulse: Tween
var _rush_fill: StyleBoxFlat
var _coin_label: Label
var _continue_ad: Button
var _continue_coins: Button
var _double_button: Button
var _earned := 0
var _hand: TapHand
var _rescue_bar: Control
var _rescue_backdrop: Control
var _menu_button: Button


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.make_theme()
	add_child(root)
	_root = root
	_build_top_bar(root)
	_build_rescue_bar(root)
	_build_hint(root)
	_hand = TapHand.new()
	_hand.visible = false
	root.add_child(_hand)
	_build_result(root)


## Hard levels show their title in red.
func set_level_title(text: String, hard := false) -> void:
	_title.text = text
	_title.add_theme_color_override("font_color", Color("ffd0d1") if hard else Color.WHITE)
	_title.add_theme_color_override("font_outline_color", Color("b8282d") if hard else UiStyle.INK)
	_title.add_theme_color_override("font_shadow_color", Color("b8282d") if hard else UiStyle.INK)


func set_time_of_day(text: String) -> void:
	_time_label.text = text + "  ·"


func set_mistakes(left: int, total: int) -> void:
	_meter.set_counts(left, total)


## `result`: stars, time, combo, coins, best_time, perfect and last_level
## (no level follows in this world, so the panel leads back to the menu).
func show_win(result: Dictionary) -> void:
	_won = true
	_last_level = result.last_level
	_badge.text = tr("WIN_PERFECT")
	_badge.visible = result.perfect
	# Behind the panel, in front of the dimmed board.
	var confetti := Confetti.new()
	_overlay.add_child(confetti)
	_overlay.move_child(confetti, 0)
	Sfx.play("celebrate", -4.0, 1.0, 0.0)
	_result_title.text = tr("WIN_TITLE")
	_result_title.add_theme_color_override("font_color", UiStyle.GOOD_DARK)
	_result_text.visible = _last_level and not result.get("onboarding_done", false)
	_result_text.text = tr("WIN_WORLD_DONE")
	if result.has("streak"):
		_result_text.text = tr("DAILY_STREAK") % result.streak
	_star_row.visible = true
	_stats.visible = true
	_star_note.text = tr(result.get("star_note", "")) if result.get("star_note", "") != "" else ""
	_star_note.visible = _star_note.text != ""
	_time_value.text = _format_time(result.time)
	_record_tag.visible = result.best_time
	_combo_value.text = "x%d" % result.combo if result.combo >= 2 else "-"
	_coin_value.text = "+0"
	_primary.text = tr("HUD_MENU") if _last_level else tr("WIN_NEXT")
	_secondary.visible = not _last_level and not result.get("onboarding", false)
	if result.get("onboarding_done", false):
		_primary.text = tr("WIN_CONTINUE")
	_primary.theme_type_variation = "GoodButton"
	_earned = result.coins
	_double_button.visible = result.get("double_ok", false)
	_double_button.disabled = false
	_continue_ad.visible = false
	_continue_coins.visible = false
	for star in _stars:
		star.filled = false
		star.scale = Vector2.ONE
	_show_result()
	_reveal(result.stars, result.coins)


## `offer`: {kind, price, can_afford, ad_ok, [moves]}; empty when no rescue
## is possible (e.g. the board is boxed in). `note`: a "so close" line that
## also makes the rescue buttons throb.
func show_lose(offer: Dictionary = {}, reason := "", note := "") -> void:
	_won = false
	_double_button.visible = false
	_set_continue(offer, note != "")
	_result_title.text = tr("LOSE_BOOM_TITLE" if reason != "" else "LOSE_TITLE")
	_result_title.add_theme_color_override("font_color", UiStyle.DANGER)
	_result_text.visible = true
	_result_text.text = tr({"explosion": "LOSE_TANKER_TEXT", "bomb": "LOSE_BOMB_TEXT"}.get(reason, "LOSE_TEXT"))
	if note != "":
		_result_text.text += "\n" + note
	_star_row.visible = false
	_stats.visible = false
	_star_note.visible = false
	_primary.text = tr("LOSE_RETRY")
	_primary.theme_type_variation = ""
	_secondary.visible = _menu_button.visible # hidden in the first session
	_badge.visible = false
	_show_result()


## The lose panel's rescue buttons (ad and coins) for `offer.kind`:
## "continue" (+moves), "rewind", "rush_clear" (remove cars) or "rush_life".
func _set_continue(offer: Dictionary, throb: bool) -> void:
	if _continue_pulse:
		_continue_pulse.kill()
		_continue_pulse = null
	_continue_ad.scale = Vector2.ONE
	_continue_ad.visible = offer.get("ad_ok", false)
	_continue_coins.visible = not offer.is_empty()
	if offer.is_empty():
		return
	var kind: String = offer.kind
	match kind:
		"continue":
			_continue_ad.text = tr("CONTINUE_AD") % offer.moves
			_continue_coins.text = tr("CONTINUE_COINS") % [offer.moves, offer.price]
		_:
			_continue_ad.text = tr(kind.to_upper() + "_AD")
			_continue_coins.text = tr(kind.to_upper() + "_COINS") % offer.price
	_continue_coins.disabled = not offer.can_afford
	if throb:
		var button := _continue_ad if _continue_ad.visible else _continue_coins
		_continue_pulse = button.create_tween().set_loops()
		button.resized.connect(func(): button.pivot_offset = button.size * 0.5)
		button.pivot_offset = button.size * 0.5
		_continue_pulse.tween_property(button, "scale", Vector2.ONE * 1.05, 0.35).set_trans(Tween.TRANS_SINE)
		_continue_pulse.tween_property(button, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)


## The "Bomb +3" button shows while a bomb is about to blow and can still be
## given more time.
func set_bomb_offer(on: bool) -> void:
	if _bomb_button.visible == on:
		return
	_bomb_button.visible = on
	if on:
		_bomb_button.pivot_offset = _bomb_button.size * 0.5
		var t := _bomb_button.create_tween()
		_bomb_button.scale = Vector2.ONE * 0.3
		t.tween_property(_bomb_button, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Stars pop in one by one with a rising chime, then the coins count up.
func _reveal(stars: int, coins: int) -> void:
	await get_tree().create_timer(0.45).timeout
	for i in stars:
		if not _overlay.visible:
			return
		var star: StarIcon = _stars[i]
		star.filled = true
		star.pivot_offset = star.size * 0.5
		star.scale = Vector2.ONE * 1.6
		star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("combo", -6.0, pow(2.0, i * 4.0 / 12.0), 0.0)
		Haptics.pulse(20)
		await get_tree().create_timer(0.28).timeout
	var t := create_tween()
	t.tween_method(func(v: float): _coin_value.text = "+%d" % roundi(v), 0.0, float(coins), 0.6)
	t.tween_callback(func():
		_coin_value.pivot_offset = _coin_value.size * 0.5
		_coin_value.scale = Vector2.ONE * 1.3
		_coin_value.create_tween().tween_property(_coin_value, "scale", Vector2.ONE, 0.2))


## The rewarded ad for double coins finished: show the new total.
func coins_doubled() -> void:
	_double_button.disabled = true
	_earned *= 2
	_coin_value.text = "+%d" % _earned
	_coin_value.pivot_offset = _coin_value.size * 0.5
	_coin_value.scale = Vector2.ONE * 1.5
	_coin_value.create_tween().tween_property(_coin_value, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	Sfx.play("combo", -4.0, 1.5, 0.0)


## Developer panel: one button per [label, callable]; any choice closes it.
func show_dev_panel(actions: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("DEV_TITLE")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiStyle.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for entry in actions + [[tr("OFFER_CANCEL"), Callable()]]:
		var b := Button.new()
		b.text = entry[0]
		b.add_theme_font_size_override("font_size", 26)
		if not (entry[1] as Callable).is_valid():
			b.theme_type_variation = "IconButton"
		var action: Callable = entry[1]
		b.pressed.connect(func():
			_click()
			dim.queue_free()
			if action.is_valid():
				action.call())
		box.add_child(b)


## Small banner sliding in under the top bar (e.g. an achievement).
func show_toast(title: String, text: String) -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.17, 0.19, 0.28, 0.92)
	box.set_corner_radius_all(22)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(StarIcon.new(40))
	var texts := VBoxContainer.new()
	row.add_child(texts)
	for pair in [[title, 22, Color("ffc93c")], [text, 28, Color.WHITE]]:
		var l := Label.new()
		l.text = pair[0]
		l.add_theme_font_size_override("font_size", pair[1])
		l.add_theme_color_override("font_color", pair[2])
		texts.add_child(l)
	add_child(panel) # above the result overlay
	await get_tree().process_frame
	var width := get_viewport().get_visible_rect().size.x
	var insets: Vector4 = get_node("/root/ScreenFit").safe_insets()
	var y := 150.0 + insets.y
	panel.position = Vector2((width - panel.size.x) * 0.5, -panel.size.y)
	Sfx.play("celebrate", -8.0, 1.2, 0.0)
	var t := panel.create_tween()
	t.tween_property(panel, "position:y", y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.0)
	t.tween_property(panel, "modulate:a", 0.0, 0.3)
	t.tween_callback(panel.queue_free)


## First session: no menu button, no rescue bar; nothing but the board.
func set_onboarding(on: bool) -> void:
	_menu_button.visible = not on
	_rescue_bar.visible = not on
	_rescue_backdrop.visible = not on


## Pause panel: resume, restart, sound and music switches, back to the menu.
func show_pause() -> void:
	paused_changed.emit(true)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.2, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("PAUSE_TITLE")
	UiStyle.style_title(title, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var close := func():
		dim.queue_free()
		paused_changed.emit(false)
	# Sound and music switches as round buttons.
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 28)
	box.add_child(toggles)
	for kind in ["sound", "music"]:
		var on: bool = Progress.sound_on if kind == "sound" else Progress.music_on
		var b := RoundButton.new(kind if on else kind + "_off", UiStyle.BLUE if on else UiStyle.MUTED, 84.0)
		b.pressed.connect(func():
			_click()
			if kind == "sound":
				Progress.set_sound(not Progress.sound_on)
			else:
				Progress.set_music(not Progress.music_on)
			var now: bool = Progress.sound_on if kind == "sound" else Progress.music_on
			b.icon_name = kind if now else kind + "_off"
			b.face = UiStyle.BLUE if now else UiStyle.MUTED
			b.queue_redraw())
		toggles.add_child(b)
	var resume := Button.new()
	resume.text = tr("PAUSE_RESUME")
	resume.theme_type_variation = "GoodButton"
	resume.pressed.connect(func():
		_click()
		close.call())
	box.add_child(resume)
	var restart := Button.new()
	restart.text = tr("PAUSE_RESTART")
	restart.pressed.connect(func():
		_click()
		close.call()
		restart_requested.emit())
	box.add_child(restart)
	var home := Button.new()
	home.text = tr("HUD_MENU")
	home.theme_type_variation = "IconButton"
	home.pressed.connect(func():
		_click()
		close.call()
		menu_requested.emit())
	box.add_child(home)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.18)


## Pointing hand tapping `screen_pos` (first-time guidance).
func show_hand(screen_pos: Vector2) -> void:
	_hand.target = screen_pos
	_hand.visible = true


func hide_hand() -> void:
	_hand.visible = false


# --- Rescue bar --------------------------------------------------------------------

func set_coins(amount: int) -> void:
	_coin_label.text = str(amount)


## Badge shows `badge` (count, or coin price if `is_price`).
func set_rescue(kind: String, badge: String, is_price: bool, enabled := true) -> void:
	var b: RescueButton = _rescue_buttons[kind]
	b.set_badge(badge, is_price)
	b.disabled = not enabled


func set_crane_active(on: bool) -> void:
	(_rescue_buttons["crane"] as RescueButton).active = on


## Asks how to pay for a rescue: coins (if affordable) or a rewarded ad.
func show_offer(kind: String, price: int, can_afford: bool, ad_ok: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.2, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title := Label.new()
	title.text = tr("RESCUE_" + kind.to_upper())
	title.add_theme_font_size_override("font_size", 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := Label.new()
	text.text = tr("RESCUE_%s_DESC" % kind.to_upper())
	text.add_theme_font_size_override("font_size", 28)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.x = 440
	box.add_child(text)
	var close := func():
		var t := dim.create_tween()
		t.tween_property(dim, "modulate:a", 0.0, 0.15)
		t.tween_callback(dim.queue_free)
	var pay := Button.new()
	pay.text = tr("OFFER_COINS") % price if can_afford else tr("OFFER_NO_COINS") % price
	pay.disabled = not can_afford
	pay.pressed.connect(func():
		_click()
		close.call()
		offer_accepted.emit(kind, false))
	box.add_child(pay)
	if ad_ok:
		var ad := Button.new()
		ad.text = tr("OFFER_AD")
		ad.theme_type_variation = "GoodButton"
		ad.pressed.connect(func():
			_click()
			close.call()
			offer_accepted.emit(kind, true))
		box.add_child(ad)
	var cancel := Button.new()
	cancel.text = tr("OFFER_CANCEL")
	cancel.theme_type_variation = "IconButton"
	cancel.pressed.connect(func():
		_click()
		close.call())
	box.add_child(cancel)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)


func _build_rescue_bar(root: Control) -> void:
	var backdrop := TextureRect.new()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = fade
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 0.6)
	backdrop.texture = tex
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var insets: Vector4 = get_node("/root/ScreenFit").safe_insets()
	backdrop.offset_top = -190 - insets.w
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	_rescue_backdrop = backdrop

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 28 + int(insets.x))
	margin.add_theme_constant_override("margin_right", 28 + int(insets.z))
	margin.add_theme_constant_override("margin_bottom", 22 + int(insets.w))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	_rescue_bar = margin
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(30)
	style.content_margin_left = 12
	style.content_margin_right = 20
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", style)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pill)
	var coins := HBoxContainer.new()
	coins.add_theme_constant_override("separation", 8)
	pill.add_child(coins)
	coins.add_child(CoinIcon.new(32))
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 28)
	_coin_label.add_theme_color_override("font_color", UiStyle.INK)
	coins.add_child(_coin_label)

	if Progress.dev_enabled():
		var dev := Button.new()
		dev.text = "DEV"
		dev.theme_type_variation = "IconButton"
		dev.add_theme_font_size_override("font_size", 22)
		dev.add_theme_color_override("font_color", UiStyle.DANGER)
		dev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dev.pressed.connect(func():
			_click()
			dev_requested.emit())
		row.add_child(dev)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for kind in ["hint", "undo", "crane"]:
		var b := RescueButton.new(kind)
		b.pressed.connect(func():
			_click()
			rescue_pressed.emit(kind))
		_rescue_buttons[kind] = b
		row.add_child(b)


static func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Floating "x3 Super!" over the car that just left; `at` is a screen position.
var _banner: Control ## cut scene title ("CLEARED!", "BOOM!")


## Cut scene title: a huge word slams onto the screen, `sub` (e.g. the best
## combo) pops in under it. Stays until hide_banner. Runs in real time.
func show_banner(text: String, color: Color, outline: Color, sub := "") -> void:
	hide_banner()
	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_banner as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_banner)
	var title := Label.new()
	title.text = text
	var font := UiStyle.font(800)
	title.add_theme_font_override("font", font)
	# As big as fits the screen width (long titles get smaller).
	var room := _root.size.x * 0.88 if _root.size.x > 0.0 else 640.0
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 108).x + 52.0
	title.add_theme_font_size_override("font_size", int(108.0 * minf(1.0, room / width)))
	title.add_theme_color_override("font_color", color)
	title.add_theme_color_override("font_outline_color", outline)
	title.add_theme_constant_override("outline_size", 26)
	title.add_theme_color_override("font_shadow_color", Color(outline, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(title)
	if sub != "":
		var line := Label.new()
		line.text = sub
		line.add_theme_font_override("font", UiStyle.font(800))
		line.add_theme_font_size_override("font_size", 48)
		line.add_theme_color_override("font_color", Color.WHITE)
		line.add_theme_color_override("font_outline_color", outline)
		line.add_theme_constant_override("outline_size", 14)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.modulate.a = 0.0
		_banner.add_child(line)
		var lt := line.create_tween().set_ignore_time_scale(true)
		lt.tween_interval(0.3)
		lt.tween_property(line, "modulate:a", 1.0, 0.2)
	await get_tree().process_frame
	if not is_instance_valid(_banner):
		return
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 2.6
	_banner.modulate.a = 0.0
	var t := _banner.create_tween().set_ignore_time_scale(true).set_parallel()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_banner, "modulate:a", 1.0, 0.12)


func hide_banner() -> void:
	if not is_instance_valid(_banner):
		return
	var old := _banner
	_banner = null
	var t := old.create_tween().set_ignore_time_scale(true).set_parallel()
	t.tween_property(old, "modulate:a", 0.0, 0.2)
	t.tween_property(old, "scale", Vector2.ONE * 0.85, 0.2)
	t.chain().tween_callback(old.queue_free)


## Full-screen flash of `color` that fades out (real time).
func flash(color: Color, duration := 0.35) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	var t := rect.create_tween().set_ignore_time_scale(true)
	t.tween_property(rect, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	t.tween_callback(rect.queue_free)


## Paper confetti over the board (the win panel brings its own).
func confetti() -> void:
	var c := Confetti.new()
	_root.add_child(c)


## Endless mode: shows the bar that fills up until the next car drops.
func set_rush(on: bool) -> void:
	_rush_bar.visible = on


## `fraction` of the wait for the next car that has passed; turns from green
## to red as the drop nears.
func set_rush_progress(fraction: float) -> void:
	_rush_bar.value = fraction
	_rush_fill.bg_color = UiStyle.GOOD.lerp(UiStyle.DANGER, smoothstep(0.55, 0.95, fraction))


## Score pop-up ("+35") rising from a screen point.
func show_points(points: int, at: Vector2) -> void:
	var label := Label.new()
	label.text = "+%d" % points
	label.add_theme_font_override("font", UiStyle.font(800))
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color("ffd34d"))
	label.add_theme_color_override("font_outline_color", UiStyle.INK)
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	await get_tree().process_frame
	label.position = _root.get_global_transform_with_canvas().affine_inverse() * at - label.size * 0.5
	var t := label.create_tween().set_parallel()
	t.tween_property(label, "position:y", label.position.y - 70.0, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.45)
	t.chain().tween_callback(label.queue_free)


## End of an endless run: why it ended, the score against the best, how
## long it lasted, the best combo and the coins earned.
## `result`: {score, best, new_best, time, combo, coins, reason, offer, note}.
func show_rush_over(result: Dictionary) -> void:
	_won = false
	_double_button.visible = false
	_set_continue(result.get("offer", {}), result.get("note", "") != "")
	var titles := {"full": "RUSH_FULL", "explosion": "LOSE_BOOM_TITLE", "bomb": "LOSE_BOOM_TITLE"}
	_result_title.text = tr(titles.get(result.reason, "RUSH_OUT"))
	_result_title.add_theme_color_override("font_color", UiStyle.DANGER)
	_result_text.visible = true
	_result_text.text = tr("RUSH_SCORE_LINE") % [result.score, result.best]
	if result.get("note", "") != "":
		_result_text.text += "\n" + result.note
	_badge.text = tr("RUSH_NEW_BEST")
	_badge.visible = result.new_best
	_star_row.visible = false
	_star_note.visible = false
	_stats.visible = true
	_time_value.text = _format_time(result.time)
	_record_tag.visible = false
	_combo_value.text = "x%d" % result.combo if result.combo >= 2 else "-"
	_coin_value.text = "+%d" % result.coins
	_primary.text = tr("RUSH_AGAIN")
	_primary.theme_type_variation = "GoodButton"
	_secondary.visible = true
	_show_result()


func show_combo(count: int, at: Vector2) -> void:
	var words := ["", "", "", "COMBO_3", "COMBO_4"]
	var label := Label.new()
	label.text = "x%d %s" % [count, tr(words[count] if count < words.size() else "COMBO_5")]
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


## Tip card ("how to play", or a world's new mechanic); emits
## `tutorial_closed` when dismissed.
func show_tutorial(title_key := "TUT_TITLE", line_keys: Array = ["TUT_1", "TUT_2", "TUT_3", "TUT_4"]) -> void:
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
	title.text = tr(title_key)
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for line in line_keys:
		var l := Label.new()
		l.text = tr(line)
		l.add_theme_font_size_override("font_size", 28)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 460
		box.add_child(l)
	var go := Button.new()
	go.text = tr("TUT_START")
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
	hide_banner()
	if _retry_pulse:
		_retry_pulse.kill()
		_retry_pulse = null
		_retry_button.scale = Vector2.ONE


## Draws the eye to Retry (the board can no longer be cleared).
func pulse_retry() -> void:
	if _retry_pulse:
		return
	_retry_button.pivot_offset = _retry_button.size * 0.5
	_retry_pulse = _retry_button.create_tween().set_loops()
	_retry_pulse.tween_property(_retry_button, "scale", Vector2.ONE * 1.15, 0.4).set_trans(Tween.TRANS_SINE)
	_retry_pulse.tween_property(_retry_button, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


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
	_menu_button = RoundButton.new("pause", UiStyle.BLUE, 76.0)
	_menu_button.pressed.connect(func():
		_click()
		show_pause())
	bar.add_child(_menu_button)
	_title = Label.new()
	UiStyle.style_title(_title, 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_retry_button = RoundButton.new("retry", UiStyle.BLUE, 76.0)
	_retry_button.pressed.connect(func():
		_click()
		restart_requested.emit())
	bar.add_child(_retry_button)

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
	caption.text = tr("HUD_MOVES")
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.25))
	meter_row.add_child(caption)
	_meter = MistakeMeter.new()
	meter_row.add_child(_meter)

	_rush_bar = ProgressBar.new()
	_rush_bar.max_value = 1.0
	_rush_bar.step = 0.0
	_rush_bar.show_percentage = false
	_rush_bar.custom_minimum_size = Vector2(360, 14)
	_rush_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rush_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiStyle.INK, 0.25)
	bg.set_corner_radius_all(7)
	_rush_fill = StyleBoxFlat.new()
	_rush_fill.bg_color = UiStyle.GOOD
	_rush_fill.set_corner_radius_all(7)
	_rush_bar.add_theme_stylebox_override("background", bg)
	_rush_bar.add_theme_stylebox_override("fill", _rush_fill)
	_rush_bar.visible = false
	rows.add_child(_rush_bar)

	_bomb_button = Button.new()
	_bomb_button.text = tr("BOMB_TIME_BUTTON")
	_bomb_button.theme_type_variation = "GoodButton"
	_bomb_button.add_theme_font_size_override("font_size", 28)
	_bomb_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bomb_button.custom_minimum_size = Vector2(240, 64)
	_bomb_button.visible = false
	_bomb_button.pressed.connect(func():
		_click()
		bomb_time_requested.emit())
	rows.add_child(_bomb_button)


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
	anchor.add_theme_constant_override("margin_bottom", 200 + int(insets.w)) # above the rescue bar
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
	_badge.text = tr("WIN_PERFECT")
	_badge.add_theme_font_size_override("font_size", 30)
	_badge.add_theme_color_override("font_color", UiStyle.ACCENT_DARK)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.visible = false
	box.add_child(_badge)

	_result_text = Label.new()
	_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_text.custom_minimum_size.x = 460
	box.add_child(_result_text)

	_star_row = HBoxContainer.new()
	_star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_star_row.add_theme_constant_override("separation", 14)
	box.add_child(_star_row)
	for i in 3:
		var star := StarIcon.new(96 if i == 1 else 80, false)
		star.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		_stars.append(star)
		_star_row.add_child(star)

	_star_note = Label.new()
	_star_note.add_theme_font_size_override("font_size", 22)
	_star_note.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.35))
	_star_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_star_note.visible = false
	box.add_child(_star_note)

	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	box.add_child(_stats)
	_time_value = _stat_row(tr("RES_TIME"))
	_record_tag = Label.new()
	_record_tag.text = tr("RES_RECORD")
	_record_tag.add_theme_font_size_override("font_size", 22)
	_record_tag.add_theme_color_override("font_color", UiStyle.ACCENT_DARK)
	_time_value.get_parent().add_child(_record_tag)
	_time_value.get_parent().move_child(_record_tag, 1)
	_combo_value = _stat_row(tr("RES_COMBO"))
	_coin_value = _stat_row(tr("RES_COINS"))
	var coin_row := _coin_value.get_parent()
	var coin := CoinIcon.new(34)
	coin_row.add_child(coin)
	coin_row.move_child(coin, 1)
	_coin_value.add_theme_color_override("font_color", UiStyle.ACCENT_DARK)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	_double_button = Button.new()
	_double_button.text = tr("WIN_DOUBLE")
	_double_button.pressed.connect(func():
		_click()
		_double_button.disabled = true
		double_coins_requested.emit())
	buttons.add_child(_double_button)
	_continue_ad = Button.new()
	_continue_ad.theme_type_variation = "GoodButton"
	_continue_ad.pressed.connect(func():
		_click()
		continue_requested.emit(true))
	buttons.add_child(_continue_ad)
	_continue_coins = Button.new()
	_continue_coins.pressed.connect(func():
		_click()
		continue_requested.emit(false))
	buttons.add_child(_continue_coins)
	_primary = Button.new()
	_primary.pressed.connect(_on_primary)
	buttons.add_child(_primary)
	_secondary = Button.new()
	_secondary.text = tr("HUD_MENU")
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


## Adds "caption ........ value" to the stats block and returns the value label.
func _stat_row(caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_stats.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", UiStyle.INK.lerp(Color.WHITE, 0.3))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.add_theme_font_override("font", UiStyle.font(800))
	value.add_theme_font_size_override("font_size", 32)
	row.add_child(value)
	return value
