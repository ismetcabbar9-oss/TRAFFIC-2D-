class_name ExitGate
extends Node3D
## Toll booth with a red/white boom barrier across the exit road. The boom
## lifts while a leaving car is approaching or passing and drops behind it.

@export var open_angle := 82.0 ## degrees
@export var detect_before := 9.0 ## start opening when a car is this far ahead
@export var detect_after := 3.0 ## keep open until the car is this far past

var _pivot: Node3D
var _open := false
var _tween: Tween
var _half_road := 1.2


func setup(at: Vector3, road_width: float) -> void:
	position = at
	_half_road = road_width * 0.5
	var side := _half_road + 0.75 # booth center, right of the road

	# Booth: walls, window band, overhanging roof with a red trim and beacon.
	_block(Vector3(side, 0.6, 0), Vector3(0.9, 1.2, 0.9), Color("f2efe8"))
	_block(Vector3(side, 0.85, 0), Vector3(0.92, 0.32, 0.92), Color("7cc6e8"))
	_block(Vector3(side, 1.24, 0), Vector3(1.2, 0.08, 1.2), Color("d9534f"))
	_block(Vector3(side, 1.32, 0), Vector3(1.0, 0.1, 1.0), Color("4e5565"))
	_block(Vector3(side, 1.45, 0), Vector3(0.18, 0.16, 0.18), Color("ffb23e"))
	# Post the boom hangs from.
	var post_x := _half_road + 0.12
	_block(Vector3(post_x, 0.42, 0), Vector3(0.2, 0.84, 0.2), Color("5b6170"))

	_pivot = Node3D.new()
	_pivot.position = Vector3(post_x, 0.78, 0)
	add_child(_pivot)
	var boom_len := road_width + 0.1
	var stripes := 6
	for i in stripes:
		var color := Color("e84a4a") if i % 2 == 0 else Color.WHITE
		var seg := boom_len / stripes
		_block(Vector3(-seg * (i + 0.5), 0, 0), Vector3(seg, 0.1, 0.1), color, _pivot)
	_block(Vector3(0.28, 0, 0), Vector3(0.35, 0.18, 0.18), Color("3d424e"), _pivot) # counterweight


func _process(_delta: float) -> void:
	var want_open := false
	for p in VehicleView.exiting_positions():
		var local := p - global_position
		if absf(local.x) < _half_road + 0.5 and local.z > -detect_before and local.z < detect_after:
			want_open = true
			break
	if want_open != _open:
		_open = want_open
		_swing(-deg_to_rad(open_angle) if _open else 0.0, 0.25 if _open else 0.6)


func _swing(angle: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation:z", angle, duration) \
		.set_trans(Tween.TRANS_BACK if angle == 0.0 else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _block(center: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	mi.material_override = m
	mi.position = center
	parent.add_child(mi)
