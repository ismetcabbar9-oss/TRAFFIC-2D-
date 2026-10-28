class_name TouchGestures
extends RefCounted
## Turns raw touches into taps, one-finger pans and two-finger pinches.
##
## A tap is reported when a finger lifts without having moved much and without
## a second finger joining in (so pinching never taps a car). Several fingers
## tapping quickly one after another still each count.

signal tapped(position: Vector2)
signal panned(delta: Vector2)
signal pinched(factor: float, center: Vector2)

## Movement (in pixels, relative to screen height) that turns a touch into a drag.
const SLOP := 0.018

var _touches := {} ## index -> {"start": Vector2, "pos": Vector2, "moved": bool}
var _pinching := false


func handle(event: InputEvent, viewport_height: float) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = {"start": event.position, "pos": event.position, "moved": false}
			if _touches.size() >= 2:
				_pinching = true
		elif _touches.has(event.index):
			var t: Dictionary = _touches[event.index]
			_touches.erase(event.index)
			if not t.moved and not _pinching:
				tapped.emit(event.position)
			if _touches.is_empty():
				_pinching = false
		return true
	if event is InputEventScreenDrag and _touches.has(event.index):
		var t: Dictionary = _touches[event.index]
		var previous: Vector2 = t.pos
		t.pos = event.position
		if not t.moved and t.start.distance_to(event.position) > SLOP * viewport_height:
			t.moved = true
		if _touches.size() >= 2:
			_pinch(event.index, previous)
		elif t.moved:
			panned.emit(event.position - previous)
		return true
	return false


func _pinch(index: int, previous: Vector2) -> void:
	var other := -1
	for i in _touches:
		if i != index:
			other = i
			break
	if other < 0:
		return
	var anchor: Vector2 = _touches[other].pos
	var before := previous.distance_to(anchor)
	var now: Vector2 = _touches[index].pos
	if before > 1.0:
		pinched.emit(now.distance_to(anchor) / before, (now + anchor) * 0.5)
