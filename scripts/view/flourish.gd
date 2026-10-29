class_name Flourish
## World-specific finale of the level-end cut scene: fireworks over the lot
## (night, and every hard level), seagulls gliding past (beach), a burst of
## snow (snow), a plane flying low over the lot (airport). City gets paper
## confetti from the HUD. Built from tweened meshes like Effects; each piece
## frees itself.

const PLANE := "res://assets/models/hq/worlds/plane.glb"
const FIREWORK_COLORS := [Color("ff4d6d"), Color("ffd23f"), Color("4cc9f0"), Color("72e06a"), Color("c77dff"), Color("ff9f1c")]


## Plays the finale for `world_id` around `center`; `extent` is about the
## lot's half size. `big` (hard levels) adds fireworks everywhere.
static func play(parent: Node3D, world_id: String, center: Vector3, extent: float, big: bool) -> void:
	match world_id:
		"night":
			fireworks(parent, center, extent, 6 if big else 4)
		"beach":
			seagulls(parent, center, extent)
		"snow":
			snow_burst(parent, center, extent)
		"airport":
			plane_flyover(parent, center, extent)
	if big and world_id != "night":
		fireworks(parent, center, extent, 4)


## Rockets climb from behind the lot and burst into rings of colored stars.
static func fireworks(parent: Node3D, center: Vector3, extent: float, count: int) -> void:
	for i in count:
		var from := center + Vector3(randf_range(-extent, extent) * 0.7, 0.3, randf_range(-extent, extent * 0.3))
		var top := from + Vector3(randf_range(-1.0, 1.0), randf_range(4.0, 6.0), randf_range(-0.5, 0.5))
		var color: Color = FIREWORK_COLORS[i % FIREWORK_COLORS.size()]
		var delay := i * 0.22 + randf_range(0.0, 0.1)
		parent.get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(parent):
				_rocket(parent, from, top, color))


static func _rocket(parent: Node3D, from: Vector3, top: Vector3, color: Color) -> void:
	var rocket := _ball(parent, Color(1.0, 0.95, 0.8), 0.25)
	rocket.global_position = from
	var t := rocket.create_tween()
	t.tween_property(rocket, "global_position", top, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		rocket.queue_free()
		_burst(parent, top, color)
		Sfx.play("exhaust_pop", -6.0, randf_range(0.6, 0.8), 0.05))


static func _burst(parent: Node3D, at: Vector3, color: Color) -> void:
	Effects.flash(parent, at, Color(color, 0.9), 5.0)
	for k in 40:
		var star := _ball(parent, color.lightened(randf_range(0.0, 0.4)), 0.15)
		star.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var to := at + dir * randf_range(3.2, 4.4) + Vector3.DOWN * 0.8
		var life := randf_range(0.8, 1.1)
		var mat := star.material_override as StandardMaterial3D
		var t := star.create_tween().set_parallel()
		t.tween_property(star, "global_position", to, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(mat, "albedo_color:a", 0.0, life * 0.5).set_delay(life * 0.5)
		t.chain().tween_callback(star.queue_free)


## A few white gulls glide across the sky in a loose line, flapping.
static func seagulls(parent: Node3D, center: Vector3, extent: float) -> void:
	for i in 4:
		var gull := _gull(parent)
		gull.scale = Vector3.ONE * 2.2
		var y := 3.0 + i * 0.3
		var z := center.z - extent * 0.4 + i * 1.3
		var from := Vector3(center.x - extent * 2.2 - i * 1.2, y, z)
		var to := Vector3(center.x + extent * 2.2 - i * 1.2, y + 0.8, z - 1.0)
		gull.global_position = from
		gull.look_at(to, Vector3.UP, true)
		var t := gull.create_tween()
		t.tween_property(gull, "global_position", to, 2.4 + i * 0.15).set_trans(Tween.TRANS_SINE)
		t.tween_callback(gull.queue_free)


static func _gull(parent: Node3D) -> Node3D:
	var gull := Node3D.new()
	parent.add_child(gull)
	var white := _material(Color("f7f7f2"))
	var gray := _material(Color("5d6470"))
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.16
	capsule.height = 0.8
	body.mesh = capsule
	body.rotation.x = PI * 0.5
	body.material_override = white
	gull.add_child(body)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		gull.add_child(hinge)
		var wing := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.75, 0.03, 0.26)
		wing.mesh = box
		wing.material_override = white
		wing.position.x = side * 0.38
		hinge.add_child(wing)
		var tip := MeshInstance3D.new()
		var tip_box := BoxMesh.new()
		tip_box.size = Vector3(0.22, 0.035, 0.22)
		tip.mesh = tip_box
		tip.material_override = gray
		tip.position.x = side * 0.82
		hinge.add_child(tip)
		var flap := hinge.create_tween().set_loops()
		flap.tween_property(hinge, "rotation:z", side * 0.55, 0.22).set_trans(Tween.TRANS_SINE)
		flap.tween_property(hinge, "rotation:z", -side * 0.25, 0.22).set_trans(Tween.TRANS_SINE)
	return gull


## Puffs of powder snow thrown up around the lot, with sparkling flakes.
static func snow_burst(parent: Node3D, center: Vector3, extent: float) -> void:
	for i in 14:
		var a := TAU * i / 14.0
		var at := center + Vector3(cos(a) * extent * 1.05, 0.3, sin(a) * extent * 1.05)
		var drift := Vector3(cos(a) * 0.8, randf_range(1.5, 2.6), sin(a) * 0.8)
		Effects._smoke_ball(parent, at, drift, randf_range(1.0, 1.5), randf_range(2.0, 2.8),
				randf_range(0.9, 1.3), Color(1, 1, 1, 0.95))
	for i in 30:
		var flake := _ball(parent, Color(1, 1, 1), 0.12)
		var at := center + Vector3(randf_range(-extent, extent), 0.5, randf_range(-extent, extent))
		flake.global_position = at
		var to := at + Vector3(randf_range(-1, 1), randf_range(2.5, 4.5), randf_range(-1, 1))
		var t := flake.create_tween().set_parallel()
		t.tween_property(flake, "global_position", to, 1.2).set_ease(Tween.EASE_OUT)
		t.tween_property(flake.material_override, "albedo_color:a", 0.0, 0.6).set_delay(0.6)
		t.chain().tween_callback(flake.queue_free)


## A plane sweeps low over the lot, banking, its shadow racing over the cars.
static func plane_flyover(parent: Node3D, center: Vector3, extent: float) -> void:
	var plane: Node3D = (load(PLANE) as PackedScene).instantiate()
	parent.add_child(plane)
	var from := center + Vector3(-extent * 2.6, 5.5, extent * 1.2)
	var to := center + Vector3(extent * 2.6, 6.5, -extent * 1.2)
	plane.global_position = from
	plane.look_at(to, Vector3.UP, true)
	plane.rotate_object_local(Vector3.FORWARD, 0.25)
	Sfx.play("engine_truck", -4.0, 1.6, 0.0)
	var t := plane.create_tween()
	t.tween_property(plane, "global_position", to, 1.8).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(plane.queue_free)


static func _ball(parent: Node3D, color: Color, radius: float) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	ball.mesh = Effects._puff()
	ball.scale = Vector3.ONE * radius / 0.28
	var mat := Effects._effect_material(color, true, 3)
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ball)
	return ball


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m
