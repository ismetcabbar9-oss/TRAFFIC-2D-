class_name VehicleView
extends Node3D
## Visual for one vehicle: loads its model, faces it along its direction,
## scales it to fit its footprint and plays its exit / crash animations.

signal exit_finished ## drove off screen; the node frees itself right after

const SIDE_GAP := 0.28 ## free space left beside the car inside its cell
const END_GAP := 0.45 ## free space left between bumpers inside the slot

const ARROW_SCENE := preload("res://scenes/direction_arrow.tscn")
const CRATE_MODEL := "res://assets/models/props/box.glb"
const CRATE_FOOTPRINT := 0.715 ## crate model width at scale 1

@export var exit_acceleration := 45.0 ## m/s²
@export var exit_max_speed := 24.0 ## m/s
@export var crash_acceleration := 60.0 ## m/s²
@export var brake_deceleration := 90.0 ## m/s² when queueing behind another car
@export var skid_length := 1.6 ## tyre marks left behind at launch (m)
@export var smoke_time := 0.55 ## seconds of exhaust smoke while accelerating

## Cars currently driving out. A car yields only to cars closer to the end of
## their route, so the one nearest the exit always keeps moving (no deadlock).
static var _exiting: Array[VehicleView] = []

## Player's driving speed setting; scales exit acceleration and top speed.
static var speed_scale := 1.0
## Night worlds: cars throw a pool of headlight on the ground ahead.
static var headlights := false

var state: VehicleState
var type: String:
	get: return state.type
var dir: int:
	get: return state.dir
var cell: Vector2i:
	get: return state.cell
var length: int:
	get: return state.length

var half_length := 0.0 ## of the fitted model, along its driving axis
var half_width := 0.0

var _board: BoardView
var _fx: Node3D ## world-space parent for effects that outlive their position
var _body: Node3D ## pivot for model + arrow; nudged without moving the car
var _model: Node3D
var _arrow: DirectionArrow
var _pick_body: StaticBody3D
var _home := Vector3.ZERO
var _tween: Tween
var _nudge_tween: Tween
var _squash_tween: Tween
var _wheels: Array[Node3D] = []

var _route: Curve3D
var _route_pos := 0.0
var _speed := 0.0
var _drive_time := 0.0
var _next_puff := 0.0
var _skids: Array[MeshInstance3D] = []
var _last_forward := Vector3.ZERO
var _roof := 0.0
var _crate: Node3D ## cargo marker on the roof
var _badge: FlatIcon ## padlock (locked) or key (key holder) above the roof
var _frame: FlatIcon ## group-colored outline on the ground
var _hint_ring: FlatIcon ## paid hint marker
var _bomb: Node3D ## time bomb on the roof
var _bomb_label: Label3D
var _fuse_spark: MeshInstance3D


static func exiting_count() -> int:
	return _exiting.size()


static func exiting_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for v in _exiting:
		result.append(v.global_position)
	return result


func setup(board: BoardView, p_state: VehicleState, effects_root: Node3D) -> void:
	_board = board
	_fx = effects_root
	state = p_state
	name = "Vehicle%d_%s" % [state.id, type]
	var cell_size := board.theme.cell_size

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_model = VehicleCatalog.load_model(type).instantiate()
	FleetPaint.apply(_model, type, state.id)
	_body.add_child(_model)
	for wheel in _model.find_children("wheel-*", "Node3D", false, false):
		_wheels.append(wheel)
		# Wheels sit inside the body's shadow; skipping them saves draw calls.
		for part in [wheel] + wheel.find_children("*", "GeometryInstance3D", true, false):
			if part is GeometryInstance3D:
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roof := _fit_model(cell_size)
	_roof = roof
	_add_arrow(cell_size, roof)
	_add_pick_body(roof)
	_add_mechanic_markers(cell_size)
	if headlights:
		_add_headlights(cell_size)

	rotation.y = GridDir.to_yaw(dir)
	_home = board.cell_to_world(footprint_center())
	position = _home
	set_process(false)


## Center of the footprint in (fractional) cell coordinates.
func footprint_center() -> Vector2:
	var span := Vector2(length - 1, 0) if GridDir.is_horizontal(dir) else Vector2(0, length - 1)
	return Vector2(cell) + span * 0.5


## Free space between this car's body and the edge of its footprint, seen from
## a car arriving along `axis_dir`.
func inset_toward(axis_dir: int) -> float:
	var cell_size := _board.theme.cell_size
	if GridDir.is_horizontal(axis_dir) == GridDir.is_horizontal(dir):
		return length * cell_size * 0.5 - half_length
	return cell_size * 0.5 - half_width


func forward() -> Vector3:
	var v := GridDir.to_vector(dir)
	return Vector3(v.x, 0, v.y)


## World point on the front bumper, at mid height.
func front_point() -> Vector3:
	return global_position + global_basis.z.normalized() * half_length + Vector3.UP * 0.35


## Drives `distance` meters ahead, calls `on_impact`, then bounces back home.
func play_crash(distance: float, on_impact: Callable) -> void:
	_kill_tween()
	position = _home
	var duration := sqrt(2.0 * maxf(distance, 0.05) / crash_acceleration)
	_tween = create_tween()
	_tween.tween_property(self, "position", _home + forward() * distance, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_impact)
	_tween.tween_callback(_squash.bind(Vector3(1.06, 0.9, 0.92), 0.09, 0.45))
	_tween.tween_property(self, "position", _home, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pops the car onto the lot at level start (scale from nothing, slight bounce).
func pop_in(delay: float) -> void:
	scale = Vector3.ONE * 0.01
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Endless mode: drops onto the lot from above, lands with a squash and a
## puff of dust; `on_landed` runs on touch-down.
func drop_in(on_landed: Callable) -> void:
	_kill_tween()
	position = _home + Vector3.UP * 7.0
	_tween = create_tween()
	_tween.tween_property(self, "position", _home, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		_squash(Vector3(1.1, 0.8, 1.06), 0.06, 0.45)
		Effects.dust_burst(_fx, global_position + Vector3.UP * 0.1, Color(0.9, 0.9, 0.88, 0.85))
		on_landed.call())


## Briefly lights up the roof arrow to point the player at this car.
func flash_hint() -> void:
	_arrow.flash_hint()


## Paid hint: the arrow glows and a pulsing frame rings the car until
## cleared; the car hops once.
func hold_hint() -> void:
	_arrow.hold_hint()
	_squash(Vector3(0.95, 1.12, 0.95), 0.1, 0.5)
	if _hint_ring == null:
		var cell_size := _board.theme.cell_size
		var area := Vector2(cell_size + 0.15, cell_size * length + 0.15)
		_hint_ring = FlatIcon.create(FlatIcon.frame_shapes(area, 0.16), Color(1.0, 0.8, 0.22), 0.03)
		_hint_ring.position.y = 0.02
		add_child(_hint_ring)
		var t := _hint_ring.create_tween().set_loops()
		t.tween_property(_hint_ring, "scale", Vector3(1.08, 1.0, 1.05), 0.35).set_trans(Tween.TRANS_SINE)
		t.tween_property(_hint_ring, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_SINE)


func clear_hint() -> void:
	_arrow.clear_hint()
	if _hint_ring:
		_hint_ring.queue_free()
		_hint_ring = null


## Undo of a pull-forward or turn: glides back to the (restored) state.
func play_restore() -> void:
	_kill_tween()
	_arrow.kind = _arrow_kind()
	if state.cargo and _crate == null:
		_add_crate(_board.theme.cell_size)
	var target := _board.cell_to_world(footprint_center())
	var yaw := GridDir.to_yaw(dir)
	var start_yaw := rotation.y
	var delta := wrapf(yaw - start_yaw, -PI, PI)
	_home = target
	_tween = create_tween()
	_tween.tween_method(func(t: float): rotation.y = start_yaw + delta * t, 0.0, 1.0, 0.3)
	_tween.parallel().tween_property(self, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Crane rescue: a hook comes down, the car swings up and away.
func play_lift() -> void:
	_kill_tween()
	clear_hint()
	_arrow.visible = false
	if _frame:
		_frame.visible = false
	_pick_body.queue_free()
	var hook := Node3D.new()
	var cable := MeshInstance3D.new()
	var cable_mesh := CylinderMesh.new()
	cable_mesh.top_radius = 0.03
	cable_mesh.bottom_radius = 0.03
	cable_mesh.height = 14.0
	cable.mesh = cable_mesh
	cable.position.y = 7.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("3d4452")
	cable.material_override = steel
	hook.add_child(cable)
	var block := MeshInstance3D.new()
	var block_mesh := BoxMesh.new()
	block_mesh.size = Vector3(0.35, 0.3, 0.35)
	block.mesh = block_mesh
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color("ffc93c")
	block.material_override = yellow
	hook.add_child(block)
	add_child(hook)
	var roof := _roof + 0.15
	hook.position.y = roof + 10.0
	_tween = create_tween()
	_tween.tween_property(hook, "position:y", roof, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_squash.bind(Vector3(1.05, 0.92, 1.05), 0.06, 0.3))
	_tween.tween_interval(0.12)
	_tween.tween_property(self, "position:y", position.y + 9.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "rotation:y", rotation.y + 0.8, 0.7)
	_tween.tween_callback(func():
		exit_finished.emit()
		queue_free())


## Small knock when something bumps into this car.
func nudge(push: Vector3) -> void:
	if _nudge_tween:
		_nudge_tween.kill()
	_body.position = Vector3.ZERO
	var local := global_transform.basis.inverse() * push
	_nudge_tween = create_tween()
	_nudge_tween.tween_property(_body, "position", local * 0.18, 0.06).set_ease(Tween.EASE_OUT)
	_nudge_tween.tween_property(_body, "position", Vector3.ZERO, 0.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Leaves the lot along the board's exit route and frees itself off screen.
func play_exit() -> void:
	_kill_tween()
	clear_hint()
	_arrow.visible = false
	if _frame:
		_frame.visible = false
	_pick_body.queue_free()
	_route = _board.exit_route(position, dir)
	_route_pos = 0.0
	_speed = 0.0
	_drive_time = 0.0
	_last_forward = global_basis.z.normalized()
	_exiting.append(self)
	set_process(true)
	_launch_effects()


## Exhaust "pop", smoke, tyre marks and a squash-and-stretch kick.
func _launch_effects() -> void:
	var back := -forward()
	var exhaust := global_position + back * (half_length + 0.1) + Vector3.UP * 0.3
	Effects.backfire(_fx, exhaust)
	Effects.exhaust_puff(_fx, exhaust, back)
	_next_puff = 0.05
	var side := global_basis.x.normalized()
	var axle := global_position + back * half_length * 0.55 + Vector3.UP * 0.01
	for s in [-1.0, 1.0]:
		_skids.append(Effects.skid_mark(_fx, axle + side * s * half_width * 0.7, forward(), 0.2))
	_squash(Vector3(0.94, 1.08, 1.1), 0.08, 0.5)
	_body.rotation.x = -0.12 # nose up as the rear squats


func _exit_tree() -> void:
	_exiting.erase(self)


func _process(delta: float) -> void:
	var limit := _speed_limit()
	if _speed > limit:
		_speed = maxf(limit, _speed - brake_deceleration * delta)
	else:
		_speed = minf(_speed + exit_acceleration * speed_scale * delta, limit)
	_route_pos += _speed * delta
	_drive_time += delta
	_update_drive_effects(delta)
	var total := _route.get_baked_length()
	if _route_pos >= total:
		set_process(false)
		exit_finished.emit()
		queue_free()
		return
	var lift := Vector3.UP * _board.surface_height()
	var here := _route.sample_baked(_route_pos) + lift
	var ahead := _route.sample_baked(minf(_route_pos + 0.4, total)) + lift
	position = here
	if here.distance_squared_to(ahead) > 0.0001:
		look_at(ahead, Vector3.UP, true)


func _update_drive_effects(delta: float) -> void:
	for wheel in _wheels:
		wheel.rotation.x += _speed * delta / 0.3
	if _drive_time < smoke_time and _drive_time >= _next_puff:
		_next_puff += 0.05
		var back := -global_basis.z.normalized()
		Effects.trail_puff(_fx, global_position + back * (half_length + 0.1) + Vector3.UP * 0.3, back)
	if _route_pos < skid_length:
		for mark in _skids:
			Effects.stretch_skid(mark, _route_pos)
	# Settle the launch pitch and lean the body out of turns.
	var fwd := global_basis.z.normalized()
	var yaw_rate := _last_forward.signed_angle_to(fwd, Vector3.UP) / maxf(delta, 0.001)
	_last_forward = fwd
	_body.rotation.x = move_toward(_body.rotation.x, 0.0, delta * 0.5)
	_body.rotation.z = lerpf(_body.rotation.z, clampf(yaw_rate * 0.025, -0.12, 0.12), minf(delta * 10.0, 1.0))


func _squash(peak: Vector3, attack: float, release: float) -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_body, "scale", peak, attack).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_body, "scale", Vector3.ONE, release) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Top speed allowed by higher-priority cars in the lane ahead: scans a strip in
## front of the bumper and slows down the closer another car's body is.
func _speed_limit() -> float:
	const LOOK_AHEAD := [0.0, 0.6, 1.2, 1.8, 2.4, 3.0]
	var forward_dir := global_transform.basis.z.normalized() # model front is +Z
	var side_dir := global_transform.basis.x.normalized()
	var bumper := global_position + forward_dir * (half_length + 0.15)
	var limit := exit_max_speed * speed_scale
	var follow := 8.0 * speed_scale # allowed speed per meter of free road ahead
	var my_remaining := _remaining()
	for other in _exiting:
		if other == self or other._remaining() > my_remaining \
				or (other._remaining() == my_remaining and other.state.id > state.id):
			continue
		var to_local := other.global_transform.affine_inverse()
		for ahead in LOOK_AHEAD:
			if ahead * follow >= limit:
				break
			var hit := false
			for side in [-1.0, 0.0, 1.0]:
				var p: Vector3 = to_local * (bumper + forward_dir * ahead + side_dir * side * half_width)
				if absf(p.x) < other.half_width + 0.2 and absf(p.z) < other.half_length + 0.2:
					hit = true
					break
			if hit:
				limit = ahead * follow
				break
	return limit


func _remaining() -> float:
	return _route.get_baked_length() - _route_pos


func _kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null


## Returns the height of the fitted model's roof.
func _fit_model(cell_size: float) -> float:
	var aabb := _model_aabb(_model, Transform3D())
	# Kenney cars face +Z; detect it from the front wheels in case a model differs.
	var front := _model.find_child("wheel-front-left", false, false) as Node3D
	if front != null and front.position.z < 0.0:
		_model.rotation.y = PI

	var width_scale := (cell_size - SIDE_GAP) / aabb.size.x
	var length_scale := (cell_size * length - END_GAP) / aabb.size.z
	var s := minf(width_scale, length_scale)
	var stretch := clampf(length_scale / s, 1.0, VehicleCatalog.max_stretch(type))
	_model.scale = Vector3(s, s, s * stretch)
	half_width = aabb.size.x * s * 0.5
	half_length = aabb.size.z * s * stretch * 0.5
	# Center the model on its footprint.
	var c := aabb.get_center()
	var offset := Vector3(-c.x, 0.0, -c.z) * _model.scale
	if _model.rotation.y != 0.0:
		offset = -offset
	_model.position = offset
	return aabb.end.y * s


func _add_arrow(cell_size: float, roof: float) -> void:
	_arrow = ARROW_SCENE.instantiate()
	_arrow.kind = _arrow_kind()
	_arrow.position.y = roof + 0.04
	_arrow.scale = Vector3.ONE * cell_size * 0.5
	_body.add_child(_arrow)


## Collision box used only for tap picking.
func _add_pick_body(roof: float) -> void:
	_pick_body = StaticBody3D.new()
	_pick_body.set_meta("vehicle_id", state.id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_width * 2.0, roof, half_length * 2.0)
	shape.shape = box
	shape.position.y = roof * 0.5
	_pick_body.add_child(shape)
	add_child(_pick_body)


static func _model_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var has := false
	var t: Transform3D = xf * ((node as Node3D).transform if node is Node3D else Transform3D())
	if node is MeshInstance3D:
		result = t * (node as MeshInstance3D).get_aabb()
		has = true
	for child in node.get_children():
		var a := _model_aabb(child, t)
		if a.size != Vector3.ZERO:
			result = a if not has else result.merge(a)
			has = true
	return result


# --- World mechanics ------------------------------------------------------------

func _arrow_kind() -> DirectionArrow.Kind:
	if state.cargo:
		return DirectionArrow.Kind.STEP
	if state.turn != 0:
		return DirectionArrow.Kind.TURN_CW if state.turn > 0 else DirectionArrow.Kind.TURN_CCW
	return DirectionArrow.Kind.STRAIGHT


func _add_crate(cell_size: float) -> void:
	_crate = (load(CRATE_MODEL) as PackedScene).instantiate()
	_crate.scale = Vector3.ONE * cell_size * 0.4 / CRATE_FOOTPRINT
	_crate.position = Vector3(0.0, _roof - 0.02, -half_length * 0.52)
	_crate.rotation.y = 0.15
	_body.add_child(_crate)


## Crate for cargo; padlock or key plus a ground frame in the group color.
func _add_mechanic_markers(cell_size: float) -> void:
	if state.cargo:
		_add_crate(cell_size)
	if state.bomb > 0:
		_add_bomb(cell_size)
	var group := state.lock if state.lock >= 0 else state.key
	if group < 0:
		return
	var color := MechanicStyle.group_color(group)
	if state.lock >= 0:
		_badge = FlatIcon.create(FlatIcon.padlock_shapes(), color, 0.07, FlatIcon.padlock_details())
	else:
		_badge = FlatIcon.create(FlatIcon.key_shapes(), color)
	# Behind the arrow, floating a little above the roof.
	_badge.scale = Vector3.ONE * cell_size * 0.46
	_badge.position = Vector3(0.0, _roof + 0.25, -half_length * 0.72)
	_body.add_child(_badge)
	var bob := _badge.create_tween().set_loops()
	bob.tween_property(_badge, "position:y", _roof + 0.38, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_badge, "position:y", _roof + 0.25, 0.8).set_trans(Tween.TRANS_SINE)
	var area := Vector2(cell_size - 0.12, cell_size * length - 0.12)
	_frame = FlatIcon.create(FlatIcon.frame_shapes(area, 0.08), Color(color, 0.85), 0.025)
	_frame.position.y = 0.012
	add_child(_frame)


# --- Hazards --------------------------------------------------------------------

## Black bomb with a burning fuse on the roof and its countdown above it.
func _add_bomb(cell_size: float) -> void:
	_bomb = Node3D.new()
	_bomb.position = Vector3(0.0, _roof, -half_length * 0.42)
	_body.add_child(_bomb)
	var r := cell_size * 0.25
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	ball.mesh = sphere
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("22252c")
	black.roughness = 0.3
	ball.material_override = black
	ball.position.y = r * 0.9
	_bomb.add_child(ball)
	var fuse := MeshInstance3D.new()
	var rope := CylinderMesh.new()
	rope.top_radius = r * 0.12
	rope.bottom_radius = r * 0.12
	rope.height = r * 0.7
	fuse.mesh = rope
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color("c9a46a")
	fuse.material_override = cord
	fuse.position = Vector3(0.0, r * 2.0, 0.0)
	fuse.rotation.z = 0.4
	_bomb.add_child(fuse)
	_fuse_spark = MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = r * 0.28
	spark.height = r * 0.56
	_fuse_spark.mesh = spark
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd23f")
	_fuse_spark.material_override = glow
	_fuse_spark.position = Vector3(-r * 0.15, r * 2.35, 0.0)
	_bomb.add_child(_fuse_spark)
	var flicker := _fuse_spark.create_tween().set_loops()
	flicker.tween_property(_fuse_spark, "scale", Vector3.ONE * 1.5, 0.09)
	flicker.tween_property(_fuse_spark, "scale", Vector3.ONE * 0.8, 0.11)
	# The count sits in a round red badge floating above the bomb.
	var badge := Node3D.new()
	badge.position = Vector3(0.0, r * 2.2 + cell_size * 0.55, 0.0)
	_bomb.add_child(badge)
	for rim in [false, true]: # colored disc first (updated by update_bomb), white rim behind
		var disc := Sprite3D.new()
		disc.texture = _badge_texture()
		disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		disc.no_depth_test = true
		disc.render_priority = 3 if rim else 4
		disc.pixel_size = cell_size * (0.74 if rim else 0.62) / 128.0
		badge.add_child(disc)
	_bomb_label = Label3D.new()
	_bomb_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bomb_label.no_depth_test = true
	_bomb_label.render_priority = 5
	_bomb_label.font = UiStyle.font(800)
	_bomb_label.font_size = 96
	_bomb_label.outline_size = 0
	_bomb_label.pixel_size = cell_size * 0.0055
	badge.add_child(_bomb_label)
	for part in _bomb.find_children("*", "GeometryInstance3D", true, false):
		(part as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_bomb(false)


## Shows the bomb's count; red and shaking for the last three taps.
func update_bomb(bump := true) -> void:
	if _bomb_label == null:
		return
	_bomb_label.text = str(state.bomb)
	var urgent := state.bomb <= 3
	var badge := _bomb_label.get_parent() as Node3D
	(badge.get_child(0) as Sprite3D).modulate = Color("ff2d20") if urgent else Color("2b2f38")
	if not bump:
		return
	var t := badge.create_tween()
	badge.scale = Vector3.ONE * (1.7 if urgent else 1.35)
	t.tween_property(badge, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if urgent:
		play_locked() # a nervous shake


static var _badge_tex: ImageTexture


## Plain white disc, tinted by the sprites that use it.
static func _badge_texture() -> ImageTexture:
	if _badge_tex == null:
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var c := Vector2(size, size) * 0.5
		for y in size:
			for x in size:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(62.0 - d, 0.0, 1.0)))
		_badge_tex = ImageTexture.create_from_image(img)
	return _badge_tex


## Explosion: the car is thrown up a little, tips over and is left charred.
func play_burnt(push: Vector3) -> void:
	_kill_tween()
	clear_hint()
	_arrow.visible = false
	if _bomb:
		_bomb.queue_free()
		_bomb = null
		_bomb_label = null
	var soot := StandardMaterial3D.new()
	soot.albedo_color = Color(0.05, 0.04, 0.035, 0.82)
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh in _model.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).material_overlay = soot
	var local := global_transform.basis.inverse() * push
	var tilt := Vector3(local.z, 0.0, -local.x).normalized() * 0.45 if local.length() > 0.01 else Vector3(0.3, 0, 0)
	_tween = create_tween()
	_tween.tween_property(self, "position", position + Vector3.UP * 1.2 + push * 0.4, 0.22).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_body, "rotation", tilt, 0.35)
	_tween.tween_property(self, "position", position + push * 0.6, 0.25).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_squash.bind(Vector3(1.08, 0.85, 1.05), 0.06, 0.4))


## Drives over the pit edge, tips nose first into it and disappears;
## `on_fallen` runs as it vanishes.
func play_fall(pit: Vector3, on_fallen: Callable) -> void:
	_kill_tween()
	clear_hint()
	_arrow.visible = false
	if _frame:
		_frame.visible = false
	_pick_body.queue_free()
	var reach := (pit - position)
	reach.y = 0.0
	var drive := maxf(reach.length() - half_length * 0.6, 0.05)
	var edge := position + reach.normalized() * drive
	_tween = create_tween()
	_tween.tween_property(self, "position", edge, sqrt(2.0 * drive / crash_acceleration) + 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_body, "rotation:x", 1.0, 0.18).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "position", Vector3(pit.x, position.y - 0.5, pit.z), 0.18)
	_tween.tween_property(self, "position:y", position.y - 2.5, 0.25).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "scale", Vector3.ONE * 0.2, 0.25).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_fallen)
	_tween.tween_callback(func():
		exit_finished.emit()
		queue_free())


## A hard knock: the body twists a little and springs back.
func jolt(amount: float) -> void:
	var t := create_tween()
	t.tween_property(_body, "rotation:y", amount, 0.06).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "rotation:y", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Cargo: drives one cell forward to its new footprint and drops the crate.
func play_advance() -> void:
	_kill_tween()
	_arrow.kind = DirectionArrow.Kind.STRAIGHT
	var target := _board.cell_to_world(footprint_center())
	_tween = create_tween()
	_tween.tween_property(self, "position", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_squash.bind(Vector3(1.04, 0.94, 0.95), 0.07, 0.35))
	_home = target
	_squash(Vector3(0.96, 1.05, 1.06), 0.08, 0.3)
	if _crate:
		var crate := _crate
		_crate = null
		var t := crate.create_tween()
		t.tween_property(crate, "position:y", crate.position.y + 0.6, 0.18).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(crate, "rotation:y", crate.rotation.y + 1.2, 0.3)
		t.tween_property(crate, "scale", Vector3.ONE * 0.01, 0.18).set_ease(Tween.EASE_IN)
		t.tween_callback(crate.queue_free)


## Turn: swings 90 degrees around the rear cell onto its new footprint.
func play_turn() -> void:
	_kill_tween()
	_arrow.kind = DirectionArrow.Kind.STRAIGHT
	var pivot := _board.cell_to_world(Vector2(state.tail()))
	var start_pos := position
	var start_yaw := rotation.y
	var delta := wrapf(GridDir.to_yaw(dir) - start_yaw, -PI, PI)
	_home = _board.cell_to_world(footprint_center())
	_tween = create_tween()
	_tween.tween_method(func(t: float):
		position = pivot + (start_pos - pivot).rotated(Vector3.UP, delta * t)
		rotation.y = start_yaw + delta * t, 0.0, 1.0, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func():
		position = _home
		rotation.y = GridDir.to_yaw(dir))


## Turn blocked: swings partway, calls `on_impact`, then swings back.
func play_turn_crash(on_impact: Callable) -> void:
	_kill_tween()
	position = _home
	rotation.y = GridDir.to_yaw(dir)
	var pivot := _board.cell_to_world(Vector2(state.tail()))
	var start_yaw := rotation.y
	var swing := -state.turn * PI * 0.5 * 0.28
	var swing_to := func(t: float):
		position = pivot + (_home - pivot).rotated(Vector3.UP, swing * t)
		rotation.y = start_yaw + swing * t
	_tween = create_tween()
	_tween.tween_method(swing_to, 0.0, 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(on_impact)
	_tween.tween_callback(_squash.bind(Vector3(1.06, 0.9, 0.92), 0.09, 0.45))
	_tween.tween_method(swing_to, 1.0, 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tapped while locked: a short shake and a rattle of the padlock.
func play_locked() -> void:
	if _nudge_tween:
		_nudge_tween.kill()
	_body.rotation.y = 0.0
	_nudge_tween = create_tween()
	for a in [0.07, -0.06, 0.04, 0.0]:
		_nudge_tween.tween_property(_body, "rotation:y", a, 0.06)
	if _badge:
		var t := _badge.create_tween()
		t.tween_property(_badge, "scale", _badge.scale * 1.35, 0.08)
		t.tween_property(_badge, "scale", _badge.scale, 0.25).set_trans(Tween.TRANS_BACK)


## The key car has left: the padlock springs open and fades away.
func unlock() -> void:
	if _badge == null:
		return
	var badge := _badge
	_badge = null
	var open := FlatIcon.create(FlatIcon.padlock_shapes(true), MechanicStyle.group_color(state.lock), 0.07, FlatIcon.padlock_details())
	open.transform = badge.transform
	_body.add_child(open)
	badge.queue_free()
	var t := open.create_tween()
	t.tween_property(open, "scale", open.scale * 1.4, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(open, "position:y", open.position.y + 0.5, 0.5)
	t.tween_property(open, "scale", Vector3.ONE * 0.01, 0.2).set_ease(Tween.EASE_IN)
	t.tween_callback(open.queue_free)
	if _frame:
		var frame := _frame
		_frame = null
		var f := frame.create_tween()
		f.tween_property(frame, "scale", Vector3(1.15, 1.0, 1.08), 0.25)
		f.parallel().tween_property(frame, "transparency", 1.0, 0.25)
		f.tween_callback(frame.queue_free)


## Night worlds: where this car's headlight pool lies, relative to its body
## (drawn by HeadlightPool together with every other car's).
var headlight_offset := Transform3D()
static var _with_headlights: Array[VehicleView] = []


func _add_headlights(cell_size: float) -> void:
	headlight_offset = Transform3D(Basis().scaled(Vector3(cell_size * 0.95, 1.0, cell_size * 1.3)),
			Vector3(0.0, 0.06, half_length + cell_size * 0.5))
	_with_headlights.append(self)
	tree_exiting.connect(func(): _with_headlights.erase(self))


## Global transforms of every headlight pool on screen.
static func headlight_transforms() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for v in _with_headlights:
		if is_instance_valid(v) and v.is_inside_tree():
			result.append(v._body.global_transform * v.headlight_offset)
	return result
