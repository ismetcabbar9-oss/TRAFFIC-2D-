class_name FlatIcon
extends MeshInstance3D
## Flat outlined sign lying on the XZ plane (like a decal): padlock, key or a
## frame around a footprint. Built from simple polygons; fill and outline are
## vertex colors in one mesh, so each icon is a single draw call. Unit size.

const OUTLINE := Color(0.1, 0.12, 0.18, 0.9)

static var _material: StandardMaterial3D


## `shapes`: polygons in (x, z). Outlines go below, fills on top and
## `details` (dark, no outline) on top of the fill.
static func create(shapes: Array, fill: Color, outline_width := 0.07, details: Array = []) -> FlatIcon:
	var icon := FlatIcon.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if outline_width > 0.0:
		for shape in shapes:
			for ring in Geometry2D.offset_polygon(shape, outline_width, Geometry2D.JOIN_ROUND):
				_add(st, ring, 0.0, OUTLINE)
	for shape in shapes:
		_add(st, shape, 0.008, fill)
	for shape in details:
		_add(st, shape, 0.016, OUTLINE)
	icon.mesh = st.commit()
	icon.material_override = _shared_material()
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return icon


## Padlock seen from above, shackle toward -Z (away from the camera).
static func padlock_shapes(open := false) -> Array:
	var body := _rect(Vector2(-0.34, -0.08), Vector2(0.34, 0.42))
	var shackle := _arc_band(Vector2(0.0, -0.08), 0.21, 0.07, PI, TAU, 10)
	var legs := [_rect(Vector2(-0.28, -0.1), Vector2(-0.14, 0.0)), _rect(Vector2(0.14, -0.1), Vector2(0.28, 0.0))]
	if open:
		shackle = _arc_band(Vector2(0.0, -0.2), 0.21, 0.07, PI, TAU, 10)
		legs = [_rect(Vector2(0.14, -0.22), Vector2(0.28, 0.0))]
	return [shackle] + legs + [body]


static func padlock_details() -> Array:
	return [_rect(Vector2(-0.05, 0.1), Vector2(0.05, 0.26))]


## Key seen from above: ring at -Z, blade toward +Z with two teeth.
static func key_shapes() -> Array:
	var shapes: Array = []
	for i in 8: # ring from segments (no polygons with holes needed)
		shapes.append(_arc_band(Vector2(0.0, -0.22), 0.17, 0.075, i * TAU / 8.0 - 0.02, (i + 1) * TAU / 8.0 + 0.02, 3))
	shapes.append(_rect(Vector2(-0.06, -0.06), Vector2(0.06, 0.46)))
	shapes.append(_rect(Vector2(0.0, 0.26), Vector2(0.18, 0.34)))
	shapes.append(_rect(Vector2(0.0, 0.38), Vector2(0.14, 0.46)))
	return shapes


## Rounded frame hugging a `size` rectangle (thin band), as separate sides.
static func frame_shapes(size: Vector2, band: float) -> Array:
	var h := size * 0.5
	return [
		_rect(Vector2(-h.x, -h.y), Vector2(h.x, -h.y + band)),
		_rect(Vector2(-h.x, h.y - band), Vector2(h.x, h.y)),
		_rect(Vector2(-h.x, -h.y), Vector2(-h.x + band, h.y)),
		_rect(Vector2(h.x - band, -h.y), Vector2(h.x, h.y)),
	]


static func _rect(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])


static func _arc_band(center: Vector2, radius: float, half_width: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		var d := Vector2(cos(a), sin(a))
		outer.append(center + d * (radius + half_width))
		inner.append(center + d * (radius - half_width))
	inner.reverse()
	outer.append_array(inner)
	return outer


static func _add(st: SurfaceTool, points: PackedVector2Array, y: float, color: Color) -> void:
	for i in Geometry2D.triangulate_polygon(points):
		st.set_color(color)
		st.add_vertex(Vector3(points[i].x, y, points[i].y))


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _material
