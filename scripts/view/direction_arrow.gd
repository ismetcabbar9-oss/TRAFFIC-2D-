class_name DirectionArrow
extends Node3D
## Flat arrow pointing along +Z (the vehicle's driving direction): a light fill
## with a dark outline so it reads on any car color. A faint light band sweeps
## across it now and then; `flash_hint` makes it blink warm yellow with a halo.
## The arrow itself never moves. Unit size; scale to fit.

const SHADER := preload("res://shaders/arrow.gdshader")
const SHAPE := [
	Vector2(0.0, 0.5), Vector2(0.4, 0.02), Vector2(0.16, 0.02), Vector2(0.16, -0.5),
	Vector2(-0.16, -0.5), Vector2(-0.16, 0.02), Vector2(-0.4, 0.02),
]
enum Layer { OUTLINE, FILL, HALO }

@export var fill_color := Color(0.9, 0.91, 0.93, 0.96)
@export var outline_color := Color(0.12, 0.14, 0.2, 0.85)
@export var outline_width := 0.07

var _material: ShaderMaterial
var _hint_tween: Tween


func _ready() -> void:
	# All layers share one mesh so each arrow stays a single draw call.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape := PackedVector2Array(SHAPE)
	for halo in [[0.3, 0.22], [0.2, 0.4]]: # soft-ish glow from two rings
		var ring := Geometry2D.offset_polygon(shape, halo[0], Geometry2D.JOIN_ROUND)[0]
		_add_polygon(st, ring, -0.004, Color(1, 1, 1, halo[1]), Layer.HALO)
	var outline := Geometry2D.offset_polygon(shape, outline_width, Geometry2D.JOIN_ROUND)[0]
	_add_polygon(st, outline, 0.0, outline_color, Layer.OUTLINE)
	_add_polygon(st, shape, 0.01, fill_color, Layer.FILL)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("phase", randf() * 10.0)

	var mi := MeshInstance3D.new()
	mi.name = "Arrow"
	mi.mesh = st.commit()
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Two quick warm blinks with a halo: a brief nudge toward this car.
func flash_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	for i in 2:
		_hint_tween.tween_method(_set_hint, 0.0, 1.0, 0.12).set_ease(Tween.EASE_OUT)
		_hint_tween.tween_method(_set_hint, 1.0, 0.15, 0.22).set_ease(Tween.EASE_IN)
	_hint_tween.tween_method(_set_hint, 0.15, 0.0, 0.35)


func clear_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	_set_hint(0.0)


func _set_hint(amount: float) -> void:
	if _material:
		_material.set_shader_parameter("hint", amount)


func _add_polygon(st: SurfaceTool, points: PackedVector2Array, y: float, color: Color, layer: Layer) -> void:
	for i in Geometry2D.triangulate_polygon(points):
		st.set_color(color)
		st.set_uv(Vector2(layer, 0))
		st.add_vertex(Vector3(points[i].x, y, points[i].y))
