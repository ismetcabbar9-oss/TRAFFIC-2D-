class_name Effects
## One-shot visual effects (smoke puffs, backfire flash, sparks, skid marks),
## built from tweened meshes so they look the same on every renderer.
## Every effect adds itself under `parent` and frees itself when done.
## Smoke, flash and sparks draw on top of cars: they are usually born between
## tightly parked vehicles and would otherwise be hidden inside them.

static var _puff_mesh: SphereMesh
static var _spark_mesh: BoxMesh


## Burst of exhaust smoke blown out behind the car: soft balls that shoot
## back, swell and fade.
static func exhaust_puff(parent: Node3D, at: Vector3, backward: Vector3) -> void:
	var side := backward.cross(Vector3.UP).normalized()
	for i in 7:
		var drift := (backward * randf_range(0.7, 1.6) + side * randf_range(-0.7, 0.7)
				+ Vector3.UP * randf_range(0.2, 0.7))
		_smoke_ball(parent, at + side * randf_range(-0.15, 0.15), drift,
				randf_range(0.7, 1.0), randf_range(1.6, 2.2), randf_range(0.5, 0.75))


## One small puff left behind by an accelerating car.
static func trail_puff(parent: Node3D, at: Vector3, backward: Vector3) -> void:
	var drift := backward * randf_range(0.2, 0.5) + Vector3.UP * randf_range(0.1, 0.3)
	_smoke_ball(parent, at, drift, randf_range(0.6, 0.85), randf_range(1.4, 1.8), randf_range(0.35, 0.5))


## Short orange flash at the exhaust pipe ("pat!").
static func backfire(parent: Node3D, at: Vector3) -> void:
	flash(parent, at, Color(1.0, 0.72, 0.25), 1.5)


## Quick glowing ball that pops out and fades.
static func flash(parent: Node3D, at: Vector3, color: Color, size: float) -> void:
	var glow := MeshInstance3D.new()
	glow.mesh = _puff()
	var mat := _effect_material(color, true, 2)
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glow)
	glow.global_position = at
	glow.scale = Vector3.ONE * 0.4
	var t := glow.create_tween().set_parallel()
	t.tween_property(glow, "scale", Vector3.ONE * size, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.16).set_delay(0.04)
	t.chain().tween_callback(glow.queue_free)


## Sparks and dust where two things collided.
static func impact(parent: Node3D, at: Vector3, push: Vector3) -> void:
	var side := push.cross(Vector3.UP).normalized()
	flash(parent, at, Color(1, 1, 0.92, 0.9), 2.4)
	for i in 6:
		var drift := -push * randf_range(0.1, 0.6) + side * randf_range(-1.1, 1.1) + Vector3.UP * randf_range(0.2, 0.7)
		_smoke_ball(parent, at, drift, randf_range(0.8, 1.1), randf_range(1.5, 2.0), randf_range(0.45, 0.65),
				Color(0.96, 0.94, 0.9, 0.9))
	for i in 12:
		var spark := MeshInstance3D.new()
		spark.mesh = _spark()
		var mat := _effect_material(Color(1.0, 0.92, 0.5), true, 3)
		spark.material_override = mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(spark)
		spark.global_position = at
		var fly := (-push * randf_range(0.2, 1.0) + side * randf_range(-1.2, 1.2) + Vector3.UP * randf_range(0.3, 1.0))
		fly = fly.normalized() * randf_range(0.9, 1.8)
		spark.look_at(at + fly, Vector3.UP if absf(fly.normalized().y) < 0.95 else Vector3.RIGHT, true)
		var life := randf_range(0.18, 0.3)
		var t := spark.create_tween().set_parallel()
		t.tween_property(spark, "global_position", at + fly + Vector3.DOWN * 0.15, life).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector3(0.6, 0.6, 0.2), life)
		t.tween_property(mat, "albedo_color", Color(1.0, 0.5, 0.15, 0.0), life)
		t.chain().tween_callback(spark.queue_free)


## Dark tyre mark on the ground; grows with `stretch_skid` and fades on its own.
static func skid_mark(parent: Node3D, start: Vector3, heading: Vector3, width: float) -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, 1.0)
	mark.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.12, 0.12, 0.14, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.set_meta("start", start)
	mark.set_meta("heading", heading)
	stretch_skid(mark, 0.05)
	var t := mark.create_tween()
	t.tween_interval(0.9)
	t.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	t.tween_callback(mark.queue_free)
	return mark


static func stretch_skid(mark: MeshInstance3D, length: float) -> void:
	if not is_instance_valid(mark):
		return
	var start: Vector3 = mark.get_meta("start")
	var heading: Vector3 = mark.get_meta("heading")
	mark.global_position = start + heading * length * 0.5
	mark.global_basis = Basis.looking_at(heading, Vector3.UP, true) * Basis.from_scale(Vector3(1, 1, length))


static func _smoke_ball(parent: Node3D, at: Vector3, drift: Vector3, start_scale: float,
		grow: float, life: float, color := Color(0.97, 0.97, 0.98, 0.95)) -> void:
	var ball := MeshInstance3D.new()
	ball.mesh = _puff()
	var mat := _effect_material(color, false, 1)
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ball)
	ball.global_position = at
	ball.scale = Vector3.ONE * start_scale
	var t := ball.create_tween().set_parallel()
	t.tween_property(ball, "global_position", at + drift, life) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ball, "scale", Vector3.ONE * start_scale * grow, life) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, life * 0.6).set_delay(life * 0.4)
	t.chain().tween_callback(ball.queue_free)


static func _effect_material(color: Color, unshaded: bool, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = priority
	m.roughness = 1.0
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _spark() -> BoxMesh:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3(0.08, 0.08, 0.34)
	return _spark_mesh


static func _puff() -> SphereMesh:
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.28
		_puff_mesh.height = 0.56
		_puff_mesh.radial_segments = 8
		_puff_mesh.rings = 4
	return _puff_mesh
