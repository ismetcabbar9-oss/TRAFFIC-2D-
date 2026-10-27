class_name BoardView
extends Node3D
## Builds the parking lot, the ring road around it, the exit with its barrier
## and the surrounding ground. Static pieces are merged into one mesh per
## material to keep draw calls low.
## Cell (0, 0) is the top-left cell; the lot is centered on the origin.

const EXIT_ROAD_LENGTH := 80.0
const ASPHALT := preload("res://shaders/asphalt.gdshader")

@export var theme: BoardTheme

var cols := 6
var rows := 6

var _boxes := {} ## material key -> Array[Transform3D] of unit boxes
var _gate: ExitGate


func build(p_cols: int, p_rows: int) -> void:
	cols = p_cols
	rows = p_rows
	if theme == null:
		theme = BoardTheme.new()
	for child in get_children():
		child.queue_free()
	_boxes.clear()

	var lot := lot_size() * 0.5
	var road_outer := lot + Vector2.ONE * (theme.sidewalk_width + theme.road_width)
	var curb := theme.curb_width
	var exit_gap := theme.road_width

	# Ground, road surface (also under the lot) and the exit road.
	_box("grass", Vector3.ZERO, Vector2(400, 400), 0.0, 0.1)
	_box("road", Vector3.ZERO, road_outer * 2.0, 0.01, 0.02)
	_box("road", Vector3(0, 0, road_outer.y + EXIT_ROAD_LENGTH * 0.5), Vector2(theme.road_width, EXIT_ROAD_LENGTH), 0.01, 0.02)
	# Raised curbs and pavements on both sides of the ring road.
	_ring("curb", road_outer, road_outer + Vector2.ONE * curb, 0.065, 0.1, exit_gap)
	_ring("pavement", road_outer + Vector2.ONE * curb, road_outer + Vector2.ONE * theme.outer_sidewalk_width, 0.055, 0.1, exit_gap)
	_ring("pavement", lot + Vector2.ONE * curb, lot + Vector2.ONE * theme.sidewalk_width, 0.055, 0.1)
	_ring("curb", lot, lot + Vector2.ONE * curb, 0.065, 0.1)
	_box("lot", Vector3.ZERO, lot * 2.0, 0.03, 0.04)
	_add_markings(lot, road_outer)
	_commit_boxes()
	_add_exit_label(road_outer)

	_gate = ExitGate.new()
	add_child(_gate)
	_gate.setup(Vector3(0, 0.01, exit_gate_z()), theme.road_width)


## Z of the barrier on the exit road.
func exit_gate_z() -> float:
	return lot_size().y * 0.5 + theme.sidewalk_width + theme.road_width + theme.outer_sidewalk_width + 2.1


func lot_size() -> Vector2:
	return Vector2(cols, rows) * theme.cell_size


## Half extents (XZ) of everything that should stay on screen.
func view_half_extents() -> Vector2:
	var pad := theme.sidewalk_width + theme.road_width + theme.outer_sidewalk_width
	return lot_size() * 0.5 + Vector2.ONE * pad


## Half extents (XZ) of the ring road's center line.
func ring_half_extents() -> Vector2:
	return lot_size() * 0.5 + Vector2.ONE * (theme.sidewalk_width + theme.road_width * 0.5)


## Cell under a world position (may lie outside the lot).
func world_to_cell(world: Vector3) -> Vector2i:
	var local := Vector2(world.x, world.z) + lot_size() * 0.5
	return Vector2i(floori(local.x / theme.cell_size), floori(local.y / theme.cell_size))


## Driving route for a vehicle leaving the lot from `start` heading `dir`:
## out to the ring road, around it in the right-hand lane to the exit at the
## bottom center, then straight off screen. Corners are rounded.
func exit_route(start: Vector3, dir: int) -> Curve3D:
	var h := ring_half_extents()
	var p := Vector2(start.x, start.z)
	var exit := Vector2(0.0, h.y)
	var points: Array[Vector2] = [p]
	match dir:
		GridDir.DOWN:
			points.append(Vector2(p.x, h.y))
		GridDir.LEFT:
			points.append_array([Vector2(-h.x, p.y), Vector2(-h.x, h.y)])
		GridDir.RIGHT:
			points.append_array([Vector2(h.x, p.y), Vector2(h.x, h.y)])
		GridDir.UP:
			var side := -1.0 if p.x < 0.0 else 1.0
			points.append_array([Vector2(p.x, -h.y), Vector2(side * h.x, -h.y), Vector2(side * h.x, h.y)])
	points.append_array([exit, exit + Vector2(0.0, EXIT_ROAD_LENGTH * 0.8)])
	return _rounded_curve(_offset_to_lane(_simplify(points)), 1.3)


## Drops repeated and collinear points.
static func _simplify(points: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q in points:
		if not out.is_empty() and out[-1].distance_to(q) < 0.01:
			continue
		if out.size() >= 2:
			var d1 := (out[-1] - out[-2]).normalized()
			var d2 := (q - out[-1]).normalized()
			if d1.dot(d2) > 0.999:
				out[-1] = q
				continue
		out.append(q)
	return out


## Shifts every segment after the first (lot -> road) into the right-hand lane.
func _offset_to_lane(points: Array[Vector2]) -> Array[Vector2]:
	var lane := theme.road_width * 0.25
	var out: Array[Vector2] = [points[0]]
	for i in range(1, points.size()):
		var offset := Vector2.ZERO
		if i >= 2:
			offset += _right(points[i] - points[i - 1]) * lane
		if i < points.size() - 1:
			offset += _right(points[i + 1] - points[i]) * lane
		out.append(points[i] + offset)
	return out


## Driver's right-hand side for a heading on the XZ plane (+Z is screen-down).
static func _right(heading: Vector2) -> Vector2:
	var d := heading.normalized()
	return Vector2(-d.y, d.x)


static func _rounded_curve(points: Array[Vector2], radius: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.1
	var y := 0.0
	curve.add_point(Vector3(points[0].x, y, points[0].y))
	for i in range(1, points.size() - 1):
		var d_in := (points[i] - points[i - 1])
		var d_out := (points[i + 1] - points[i])
		var r := minf(radius, minf(d_in.length(), d_out.length()) * 0.5)
		d_in = d_in.normalized()
		d_out = d_out.normalized()
		var a := points[i] - d_in * r
		var b := points[i] + d_out * r
		var k := r * 0.55
		curve.add_point(Vector3(a.x, y, a.y), Vector3.ZERO, Vector3(d_in.x, 0, d_in.y) * k)
		curve.add_point(Vector3(b.x, y, b.y), -Vector3(d_out.x, 0, d_out.y) * k)
	var last := points[-1]
	curve.add_point(Vector3(last.x, y, last.y))
	return curve


func surface_height() -> float:
	return 0.04


## World position of the center of a grid cell (may lie outside the lot).
func cell_to_world(cell: Vector2) -> Vector3:
	var origin := -lot_size() * 0.5
	var p := origin + (cell + Vector2(0.5, 0.5)) * theme.cell_size
	return Vector3(p.x, surface_height(), p.y)


## Painted lines: parking grid, yellow lot border, road edge lines, center
## dashes, exit-road dashes and the zebra crossing at the exit.
func _add_markings(lot: Vector2, road_outer: Vector2) -> void:
	var paint_y := 0.034
	var road_paint_y := 0.014
	var w := theme.lot_line_width
	for c in range(1, cols):
		_paint("lot_line", Vector3(-lot.x + c * theme.cell_size, 0, 0), Vector2(w, lot.y * 2.0), paint_y)
	for r in range(1, rows):
		_paint("lot_line", Vector3(0, 0, -lot.y + r * theme.cell_size), Vector2(lot.x * 2.0, w), paint_y)
	_ring("lot_border", lot - Vector2.ONE * 0.16, lot - Vector2.ONE * 0.08, paint_y + 0.002, 0.004)

	var inner_edge := lot + Vector2.ONE * (theme.sidewalk_width + 0.14)
	_ring("road_line", inner_edge, inner_edge + Vector2.ONE * 0.07, road_paint_y, 0.004)
	var outer_edge := road_outer - Vector2.ONE * 0.21
	_ring("road_line", outer_edge, outer_edge + Vector2.ONE * 0.07, road_paint_y, 0.004, theme.road_width)

	var half := ring_half_extents()
	var dash := 0.7
	var gap := 0.55
	for side in 4:
		var horizontal := side % 2 == 0
		var length := half.x * 2.0 if horizontal else half.y * 2.0
		var count := int((length - theme.road_width) / (dash + gap))
		var start := -(count * (dash + gap) - gap) * 0.5
		for i in count:
			var t := start + i * (dash + gap) + dash * 0.5
			if side == 2 and absf(t) < theme.road_width * 0.5 + dash:
				continue # junction with the exit road
			var size := Vector2(dash, 0.1) if horizontal else Vector2(0.1, dash)
			var at: Vector3 = [Vector3(t, 0, -half.y), Vector3(half.x, 0, t), Vector3(t, 0, half.y), Vector3(-half.x, 0, t)][side]
			_paint("road_line", at, size, road_paint_y)

	# Zebra crossing where the pavement meets the exit road.
	var cross_z := road_outer.y + theme.outer_sidewalk_width * 0.5
	var stripes := 5
	var stripe_w := theme.road_width / (stripes * 2.0 - 1.0)
	for i in stripes:
		var x := -theme.road_width * 0.5 + stripe_w * (i * 2.0 + 0.5)
		_paint("road_line", Vector3(x, 0, cross_z), Vector2(stripe_w * 0.9, theme.outer_sidewalk_width * 0.85), road_paint_y)
	var z := road_outer.y + theme.outer_sidewalk_width + 3.6
	while z < road_outer.y + EXIT_ROAD_LENGTH:
		_paint("road_line", Vector3(0, 0, z + dash * 0.5), Vector2(0.1, dash), road_paint_y)
		z += dash + gap


## "EXIT" painted on the exit road, readable from the camera.
func _add_exit_label(road_outer: Vector2) -> void:
	var label := Label3D.new()
	label.text = tr("ROAD_EXIT")
	label.font = UiStyle.font(800)
	label.font_size = 96
	label.pixel_size = 0.0075
	label.outline_size = 0
	label.modulate = Color(theme.road_line, 0.9)
	label.double_sided = false
	label.rotation_degrees.x = -90.0
	label.position = Vector3(0, 0.016, road_outer.y + theme.outer_sidewalk_width + 1.0)
	add_child(label)


## Frame of four boxes between two centered rectangles (half extents), with an
## optional opening of width `gap` in the bottom side for the exit road.
func _ring(key: String, inner: Vector2, outer: Vector2, top_y: float, height: float, gap := 0.0) -> void:
	var band := outer - inner
	var mid := (inner + outer) * 0.5
	_box(key, Vector3(0, 0, -mid.y), Vector2(outer.x * 2.0, band.y), top_y, height)
	if gap <= 0.0:
		_box(key, Vector3(0, 0, mid.y), Vector2(outer.x * 2.0, band.y), top_y, height)
	else:
		var piece := outer.x - gap * 0.5
		for side in [-1.0, 1.0]:
			_box(key, Vector3(side * (gap * 0.5 + piece * 0.5), 0, mid.y), Vector2(piece, band.y), top_y, height)
	for side in [-1.0, 1.0]:
		_box(key, Vector3(side * mid.x, 0, 0), Vector2(band.x, inner.y * 2.0), top_y, height)


func _paint(key: String, center: Vector3, size: Vector2, top_y: float) -> void:
	_box(key, center, size, top_y, 0.004)


## Queues an axis-aligned box; boxes sharing a key become one mesh.
func _box(key: String, center: Vector3, size: Vector2, top_y: float, height: float) -> void:
	var xf := Transform3D(Basis.from_scale(Vector3(size.x, height, size.y)),
			Vector3(center.x, top_y - height * 0.5, center.z))
	if not _boxes.has(key):
		_boxes[key] = []
	_boxes[key].append(xf)


func _commit_boxes() -> void:
	var unit := BoxMesh.new()
	for key in _boxes:
		var st := SurfaceTool.new()
		for xf in _boxes[key]:
			st.append_from(unit, 0, xf)
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize().replace(" ", "")
		mi.mesh = st.commit()
		mi.material_override = _material(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if key == "curb" \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _material(key: String) -> Material:
	match key:
		"grass":
			return _surface(theme.grass, 0.05, 0.09, 2.5)
		"road":
			return _surface(theme.road, 0.07, 0.05, 7.0)
		"lot":
			return _surface(theme.lot, 0.06, 0.04, 7.0)
		"pavement":
			return _surface(theme.sidewalk, 0.03, 0.03, 5.0)
	var color: Color = {"curb": theme.curb, "lot_line": theme.lot_line,
			"lot_border": theme.lot_border, "road_line": theme.road_line}[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _surface(color: Color, grain: float, blotch: float, scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ASPHALT
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("blotch", blotch)
	m.set_shader_parameter("grain_scale", scale)
	return m
