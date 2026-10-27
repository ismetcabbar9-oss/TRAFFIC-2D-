extends Node
## Autoload "ScreenFit": keeps the 2D interface at a comfortable size in both
## orientations by swapping the base canvas size (720x1280 portrait,
## 1280x720 landscape). The 3D view always renders at full resolution.

const PORTRAIT := Vector2i(720, 1280)
const LANDSCAPE := Vector2i(1280, 720)


func _ready() -> void:
	get_tree().root.size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var window := get_tree().root
	var landscape := window.size.x > window.size.y
	window.content_scale_size = LANDSCAPE if landscape else PORTRAIT
