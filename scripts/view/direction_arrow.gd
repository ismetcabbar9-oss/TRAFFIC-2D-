class_name DirectionArrow
extends Node3D
## Flat arrow pointing along +Z (the vehicle's driving direction): a light fill
## with a dark outline so it reads on any car color. A faint light band sweeps
## across it now and then; `flash_hint` makes it blink warm yellow with a halo.
## The arrow itself never moves. Unit size; scale to fit.
##
## Kinds: a straight arrow; a short arrow with a stop bar (cargo: one step
## only); a curved arrow for a vehicle that turns first (clockwise is toward
## -X, the vehicle's right side seen from above).

const SHADER := preload("res://shaders/arrow.gdshader")
const STRAIGHT_SHAPE := [
	Vector2(0.0, 0.5), Vector2(0.4, 0.02), Vector2(0.16, 0.02), Vector2(0.16, -0.5),
	Vector2(-0.16, -0.5), Vector2(-0.16, 0.02), Vector2(-0.4, 0.02),
]
enum Kind { STRAIGHT, STEP, TURN_CW, TURN_CCW }
enum Layer { OUTLINE, FILL, HALO }

@export var fill_color := Color(0.9, 0.91, 0.93, 0.96)
@export var outline_color := Color(0.12, 0.14, 0.2, 0.85)
@export var outline_width := 0.07

var kind := Kind.STRAIGHT:
	set(value):
		kind = value
		if _mesh_instance:
			_mesh_instance.mesh = _build_mesh()

var _material: ShaderMaterial
var _hint_tween: Tween
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("phase", randf() * 10.0)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Arrow"
	_mesh_instance.mesh = _build_mesh()
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


## Two quick warm blinks with a halo: a brief nudge toward this car.
func flash_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	for i in 2:
		_hint_tween.tween_method(_set_hint, 0.0, 1.0, 0.12).set_ease(Tween.EASE_OUT)
		_hint_tween.tween_method(_set_hint, 1.0, 0.15, 0.22).set_ease(Tween.EASE_IN)
	_hint_tween.tween_method(_set_hint, 0.15, 0.0, 0.35)


## Paid hint: keeps glowing (gently pulsing) until the car is tapped.
func hold_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_method(_set_hint, 0.55, 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_method(_set_hint, 1.0, 0.55, 0.35).set_trans(Tween.TRANS_SINE)


func clear_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	_set_hint(0.0)


func _set_hint(amount: float) -> void:
	if _material:
		_material.set_shader_parameter("hint", amount)


## Polygons (x, z) making up the arrow of the current kind.
func _shapes() -> Array[PackedVector2Array]:
	match kind:
		Kind.STEP:
			var short := PackedVector2Array()
			for p in STRAIGHT_SHAPE:
				short.append(Vector2(p.x, p.y * 0.62 - 0.12))
			var bar := PackedVector2Array([Vector2(-0.38, 0.3), Vector2(0.38, 0.3),
					Vector2(0.38, 0.44), Vector2(-0.38, 0.44)])
			return [short, bar]
		Kind.TURN_CW, Kind.TURN_CCW:
			return [_curved(1.0 if kind == Kind.TURN_CCW else -1.0)]
	return [PackedVector2Array(STRAIGHT_SHAPE)]


## Quarter-circle arrow starting at the rear pointing forward and ending
## pointing sideways (`side` +1 = +X).
static func _curved(side: float) -> PackedVector2Array:
	const R := 0.42
	const W := 0.14 # half band width
	const HEAD := 0.32 # half arrowhead width
	const END := 1.15 # radians of band before the head
	const TIP := 1.75
	var center := Vector2(side * R, -0.32)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 9:
		var a := END * i / 8.0
		var d := Vector2(-side * cos(a), sin(a))
		outer.append(center + d * (R + W))
		inner.append(center + d * (R - W))
	var points := outer
	var d_end := Vector2(-side * cos(END), sin(END))
	points.append(center + d_end * (R + HEAD))
	var d_tip := Vector2(-side * cos(TIP), sin(TIP))
	points.append(center + d_tip * R)
	points.append(center + d_end * maxf(R - HEAD, 0.04))
	inner.reverse()
	points.append_array(inner)
	# Center the shape on the roof.
	var shift := Vector2(-side * 0.08, 0.02)
	for i in points.size():
		points[i] += shift
	return points


func _build_mesh() -> ArrayMesh:
	# All layers share one mesh so each arrow stays a single draw call.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shapes := _shapes()
	for halo in [[0.3, 0.22], [0.2, 0.4]]: # soft-ish glow from two rings
		for shape in shapes:
			for ring in Geometry2D.offset_polygon(shape, halo[0], Geometry2D.JOIN_ROUND):
				_add_polygon(st, ring, -0.004, Color(1, 1, 1, halo[1]), Layer.HALO)
	for shape in shapes:
		for outline in Geometry2D.offset_polygon(shape, outline_width, Geometry2D.JOIN_ROUND):
			_add_polygon(st, outline, 0.0, outline_color, Layer.OUTLINE)
	for shape in shapes:
		_add_polygon(st, shape, 0.01, fill_color, Layer.FILL)
	return st.commit()


func _add_polygon(st: SurfaceTool, points: PackedVector2Array, y: float, color: Color, layer: Layer) -> void:
	for i in Geometry2D.triangulate_polygon(points):
		st.set_color(color)
		st.set_uv(Vector2(layer, 0))
		st.add_vertex(Vector3(points[i].x, y, points[i].y))
