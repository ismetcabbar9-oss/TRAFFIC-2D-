extends Node
## Autoload "ScreenFit": keeps the 2D interface at a comfortable size in both
## orientations by swapping the base canvas size (720x1280 portrait,
## 1280x720 landscape). The 3D view always renders at full resolution.

const PORTRAIT := Vector2i(720, 1280)
const LANDSCAPE := Vector2i(1280, 720)


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()


## Screen insets (notch, rounded corners, system bars) in canvas units:
## x = left, y = top, z = right, w = bottom.
func safe_insets() -> Vector4:
	var window := get_tree().root
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size.x <= 0.0 or screen_size.x <= 0.0:
		return Vector4.ZERO
	var to_canvas := Vector2(window.content_scale_size) / Vector2(window.size)
	var scale := maxf(to_canvas.x, to_canvas.y) # "expand" keeps the larger ratio
	return Vector4(safe.position.x, safe.position.y,
			screen_size.x - safe.end.x, screen_size.y - safe.end.y) * scale


func _fit() -> void:
	var window := get_tree().root
	var landscape := window.size.x > window.size.y
	window.content_scale_size = LANDSCAPE if landscape else PORTRAIT
