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


## Big blast: white flash, fireballs, a ring racing over the ground, a
## column of black smoke, flying debris and embers, and a scorch mark that
## stays.
static func explosion(parent: Node3D, at: Vector3) -> void:
	var ground := Vector3(at.x, 0.05, at.z)
	flash(parent, at + Vector3.UP * 0.8, Color(1.0, 0.97, 0.85), 12.0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.3)
	light.omni_range = 9.0
	light.light_energy = 10.0
	parent.add_child(light)
	light.global_position = at + Vector3.UP * 1.5
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	lt.tween_callback(light.queue_free)
	# Fireballs: hot core first, darker red at the edge, rising as they burn out.
	var fire := [Color(1.0, 0.95, 0.6), Color(1.0, 0.72, 0.2), Color(1.0, 0.45, 0.12), Color(0.85, 0.2, 0.08)]
	for i in 16:
		var ball := MeshInstance3D.new()
		ball.mesh = _puff()
		var mat := _effect_material(fire[i % fire.size()], true, 3)
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ball)
		var offset := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)) * 1.1
		ball.global_position = at + offset * 0.3
		ball.scale = Vector3.ONE * 0.8
		var life := randf_range(0.7, 1.15)
		var size := randf_range(5.5, 8.5)
		var t := ball.create_tween().set_parallel()
		t.tween_property(ball, "global_position", at + offset * 1.6 + Vector3.UP * randf_range(0.6, 1.6), life) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(ball, "scale", Vector3.ONE * size, life * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(mat, "albedo_color", Color(0.25, 0.08, 0.04, 0.0), life * 0.6).set_delay(life * 0.4)
		t.chain().tween_callback(ball.queue_free)
	# Shock ring over the ground.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var ring_mat := _effect_material(Color(1.0, 0.85, 0.6, 0.8), true, 2)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = ground
	ring.scale = Vector3(0.5, 0.05, 0.5)
	var rt := ring.create_tween().set_parallel()
	rt.tween_property(ring, "scale", Vector3(9.0, 0.05, 9.0), 0.5).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring_mat, "albedo_color:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	rt.chain().tween_callback(ring.queue_free)
	# Black smoke column.
	for i in 18:
		var drift := Vector3(randf_range(-1.2, 1.2), randf_range(3.0, 6.0), randf_range(-1.2, 1.2))
		var delay := i * 0.04
		var gray := randf_range(0.12, 0.3)
		var start := at + Vector3(randf_range(-0.5, 0.5), 0.4, randf_range(-0.5, 0.5))
		parent.get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(parent):
				_smoke_ball(parent, start, drift, randf_range(1.6, 2.4), randf_range(2.6, 3.6),
						randf_range(1.8, 2.8), Color(gray, gray, gray * 1.05, 0.92)))
	# Debris and embers flying out in arcs.
	for i in 16:
		var piece := MeshInstance3D.new()
		var ember := i % 2 == 0
		piece.mesh = _spark() if ember else _debris()
		var mat := _effect_material(Color(1.0, 0.75, 0.3) if ember else Color(0.16, 0.15, 0.15), ember, 3)
		piece.material_override = mat
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(piece)
		piece.global_position = at + Vector3.UP * 0.5
		var heading := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(2.0, 4.5)
		var up := randf_range(2.0, 4.0)
		var life := randf_range(0.6, 1.0)
		var from := piece.global_position
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var t := piece.create_tween()
		t.tween_method(func(k: float):
			if is_instance_valid(piece):
				piece.global_position = from + heading * k + Vector3.UP * (up * k - 3.6 * k * k)
				piece.rotation = spin * k, 0.0, 1.0, life)
		t.parallel().tween_property(mat, "albedo_color:a", 0.0, life * 0.4).set_delay(life * 0.6)
		t.tween_callback(piece.queue_free)
	scorch(parent, ground, 3.2)


## Burnt patch left on the ground (stays until the level ends).
static func scorch(parent: Node3D, at: Vector3, size: float) -> void:
	var mark := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mark.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.04, 0.03, 0.85))
	g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	mat.albedo_texture = tex
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = at
	mark.rotation.y = randf() * TAU
	mark.scale = Vector3.ONE * 0.3
	mark.create_tween().tween_property(mark, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT)


## Dust thrown up when a car drops into a pit.
static func dust_burst(parent: Node3D, at: Vector3, color: Color) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		var drift := Vector3(sin(a), randf_range(0.4, 1.0), cos(a)) * randf_range(0.6, 1.2)
		_smoke_ball(parent, at, drift, randf_range(0.8, 1.1), randf_range(1.8, 2.4), randf_range(0.6, 0.9), color)


## Glass shards sparkling out of a hard crash.
static func shards(parent: Node3D, at: Vector3, push: Vector3) -> void:
	for i in 8:
		var shard := MeshInstance3D.new()
		shard.mesh = _debris()
		var mat := _effect_material(Color(0.8, 0.93, 1.0, 0.9), true, 3)
		shard.material_override = mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(shard)
		shard.global_position = at
		shard.scale = Vector3.ONE * 0.6
		var fly := (push * randf_range(-0.2, 0.6) + Vector3(randf_range(-1, 1), randf_range(0.4, 1.2), randf_range(-1, 1))) * 1.2
		var life := randf_range(0.3, 0.5)
		var t := shard.create_tween().set_parallel()
		t.tween_property(shard, "global_position", at + fly + Vector3.DOWN * 0.4, life).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "rotation", Vector3(randf() * 8, randf() * 8, 0), life)
		t.tween_property(mat, "albedo_color:a", 0.0, life)
		t.chain().tween_callback(shard.queue_free)


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
		grow: float, life: float, color := Color(0, 0, 0, 0)) -> void:
	if color.a == 0.0:
		color = Color(Cosmetics.color("smoke"), 0.95) # garage smoke color
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


static var _debris_mesh: BoxMesh


static func _debris() -> BoxMesh:
	if _debris_mesh == null:
		_debris_mesh = BoxMesh.new()
		_debris_mesh.size = Vector3(0.22, 0.08, 0.16)
	return _debris_mesh


static func _puff() -> SphereMesh:
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.28
		_puff_mesh.height = 0.56
		_puff_mesh.radial_segments = 8
		_puff_mesh.rings = 4
	return _puff_mesh
