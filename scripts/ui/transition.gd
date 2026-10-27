extends CanvasLayer
## Autoload "Transition": a soft fade used when switching scenes or reloading
## a level, so screens never pop from one to the other.

const COLOR := Color("bfe3f2")
const OUT_TIME := 0.22
const IN_TIME := 0.35

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)


## Fades out, switches to `path`, fades back in.
func change_scene(path: String) -> void:
	await cover(func(): get_tree().change_scene_to_file(path))


## Fades out, runs `action` while the screen is covered, fades back in.
func cover(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP # no taps mid-transition
	await create_tween().tween_property(_veil, "modulate:a", 1.0, OUT_TIME).finished
	action.call()
	await get_tree().process_frame
	await get_tree().process_frame
	await create_tween().tween_property(_veil, "modulate:a", 0.0, IN_TIME).finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
