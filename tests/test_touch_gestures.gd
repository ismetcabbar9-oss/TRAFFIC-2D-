extends TestCase
## Taps, drags and pinches from raw touches.

var _taps: Array = []
var _pans: Array = []
var _pinches: Array = []


func _gestures() -> TouchGestures:
	_taps.clear()
	_pans.clear()
	_pinches.clear()
	var g := TouchGestures.new()
	g.tapped.connect(func(p): _taps.append(p))
	g.panned.connect(func(d): _pans.append(d))
	g.pinched.connect(func(f, c): _pinches.append(f))
	return g


static func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


static func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	return e


func test_tap_on_release() -> void:
	var g := _gestures()
	g.handle(_touch(0, Vector2(100, 100), true), 1000.0)
	check(_taps.is_empty(), "nothing on press")
	g.handle(_drag(0, Vector2(104, 102)), 1000.0) # a small wobble is still a tap
	g.handle(_touch(0, Vector2(104, 102), false), 1000.0)
	check_eq(_taps.size(), 1, "tap on release")


func test_drag_is_not_a_tap() -> void:
	var g := _gestures()
	g.handle(_touch(0, Vector2(100, 100), true), 1000.0)
	g.handle(_drag(0, Vector2(160, 100)), 1000.0)
	g.handle(_touch(0, Vector2(160, 100), false), 1000.0)
	check(_taps.is_empty(), "no tap after a drag")
	check(not _pans.is_empty(), "panned")


func test_pinch_zooms_and_never_taps() -> void:
	var g := _gestures()
	g.handle(_touch(0, Vector2(100, 500), true), 1000.0)
	g.handle(_touch(1, Vector2(300, 500), true), 1000.0)
	g.handle(_drag(1, Vector2(500, 500)), 1000.0)
	check(not _pinches.is_empty() and _pinches[0] > 1.9, "spread fingers zoom in")
	g.handle(_touch(1, Vector2(500, 500), false), 1000.0)
	g.handle(_touch(0, Vector2(100, 500), false), 1000.0)
	check(_taps.is_empty(), "no tap from a pinch")


func test_two_quick_taps_with_two_fingers() -> void:
	var g := _gestures()
	g.handle(_touch(0, Vector2(100, 100), true), 1000.0)
	g.handle(_touch(0, Vector2(100, 100), false), 1000.0)
	g.handle(_touch(1, Vector2(400, 300), true), 1000.0)
	g.handle(_touch(1, Vector2(400, 300), false), 1000.0)
	check_eq(_taps.size(), 2, "both taps count")
