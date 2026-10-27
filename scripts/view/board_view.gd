class_name BoardView
extends Node3D
## Builds the parking lot, the ring road around it and the surrounding ground.
## Cell (0, 0) is the top-left cell; the lot is centered on the origin.

const EXIT_ROAD_LENGTH := 80.0

@export var theme: BoardTheme

var cols := 6
var rows := 6

var _materials := {}


func build(p_cols: int, p_rows: int) -> void:
	cols = p_cols
	rows = p_rows
	if theme == null:
		theme = BoardTheme.new()
	for child in get_children():
		child.queue_free()
	_materials.clear()

	var lot := lot_size()
	var sw := theme.sidewalk_width
	var road := theme.road_width
	var outer := theme.outer_sidewalk_width

	# Layers from the outside in; each one is drawn slightly higher than the last.
	_add_box("Grass", Vector2(400, 400), -0.05, theme.grass, 0.1)
	_add_layer("OuterSidewalk", lot + Vector2.ONE * 2.0 * (sw + road + outer), 0.0, theme.sidewalk)
	_add_layer("Road", lot + Vector2.ONE * 2.0 * (sw + road), 0.01, theme.road)
	_add_layer("InnerCurb", lot + Vector2.ONE * 2.0 * sw, 0.02, theme.curb)
	_add_layer("InnerSidewalk", lot + Vector2.ONE * 2.0 * (sw - 0.08), 0.025, theme.sidewalk)
	_add_layer("Lot", lot, 0.03, theme.lot)
	_add_exit_road()
	_add_lot_lines()
	_add_road_dashes()


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


func _add_layer(node_name: String, size: Vector2, y: float, color: Color) -> void:
	_add_box(node_name, size, y, color, 0.02)


func _add_box(node_name: String, size: Vector2, top_y: float, color: Color, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, height, size.y)
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.position = Vector3(0, top_y - height * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _add_lot_lines() -> void:
	var lot := lot_size()
	var w := theme.lot_line_width
	var y := 0.035
	for c in range(1, cols):
		var x := -lot.x * 0.5 + c * theme.cell_size
		_add_box("LotLineV%d" % c, Vector2(w, lot.y), y, theme.lot_line, 0.004).position.x = x
	for r in range(1, rows):
		var z := -lot.y * 0.5 + r * theme.cell_size
		_add_box("LotLineH%d" % r, Vector2(lot.x, w), y, theme.lot_line, 0.004).position.z = z


## Straight road from the bottom of the ring down off screen.
func _add_exit_road() -> void:
	var h := ring_half_extents()
	var box := _add_box("ExitRoad", Vector2(theme.road_width, EXIT_ROAD_LENGTH), 0.012, theme.road, 0.02)
	box.position.z = h.y + EXIT_ROAD_LENGTH * 0.5
	var dash := 0.7
	var gap := 0.55
	var z := h.y + theme.road_width * 0.5 + gap
	while z < h.y + EXIT_ROAD_LENGTH:
		_add_box("ExitDash", Vector2(0.1, dash), 0.017, theme.road_line, 0.004).position.z = z + dash * 0.5
		z += dash + gap


## Dashed center line running around the ring road.
func _add_road_dashes() -> void:
	var half := lot_size() * 0.5 + Vector2.ONE * (theme.sidewalk_width + theme.road_width * 0.5)
	var dash := 0.7
	var gap := 0.55
	var y := 0.015
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
			var box := _add_box("Dash", size, y, theme.road_line, 0.004)
			match side:
				0: box.position = Vector3(t, box.position.y, -half.y)
				1: box.position = Vector3(half.x, box.position.y, t)
				2: box.position = Vector3(t, box.position.y, half.y)
				3: box.position = Vector3(-half.x, box.position.y, t)


func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[color] = m
	return m
