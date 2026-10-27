extends CanvasLayer
## Autoload "AdManager": every ad decision goes through here.
##
## Rewarded ads are always optional and capped per day (data/economy.json).
## Players who bought "ad-free" get the same rewards without watching.
## Until the AdMob plugin arrives (phase 4) a short placeholder screen stands
## in for the ad, so the whole flow can be played and tested.

signal ad_finished(placement: String, rewarded: bool)

const PLACEHOLDER_SECONDS := 1.5

var _busy := false


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS


## True if a rewarded ad (or its ad-free reward) can be offered right now.
func rewarded_available(placement: String) -> bool:
	if _busy:
		return false
	var limits: Dictionary = Economy.value("ad_limits_per_day")
	if Progress.ads_watched("total") >= int(limits.get("total", 15)):
		return false
	return Progress.ads_watched(placement) < int(limits.get(placement, 3))


## Shows a rewarded ad; calls `on_reward` only if it was watched to the end.
func show_rewarded(placement: String, on_reward: Callable) -> void:
	if not rewarded_available(placement):
		return
	_busy = true
	if Progress.ad_free:
		_finish(placement, true, on_reward)
		return
	await _placeholder()
	_finish(placement, true, on_reward)


func _finish(placement: String, rewarded: bool, on_reward: Callable) -> void:
	_busy = false
	if rewarded:
		Progress.count_ad(placement)
		on_reward.call()
	ad_finished.emit(placement, rewarded)


## Stand-in until the real ad SDK is connected: a dark screen for a moment.
func _placeholder() -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.05, 0.06, 0.1, 0.92)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var label := Label.new()
	label.text = tr("AD_PLACEHOLDER")
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	veil.add_child(label)
	await get_tree().create_timer(PLACEHOLDER_SECONDS, true, false, true).timeout
	veil.queue_free()
