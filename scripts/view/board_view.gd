class_name BoardView
extends Node3D
## Builds the parking lot, the ring road around it and the surrounding ground.
## Cell (0, 0) is the top-left cell; the lot is centered on the origin.

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
	_add_lot_lines()
	_add_road_dashes()


func lot_size() -> Vector2:
	return Vector2(cols, rows) * theme.cell_size


## Half extents (XZ) of everything that should stay on screen.
func view_half_extents() -> Vector2:
	var pad := theme.sidewalk_width + theme.road_width + theme.outer_sidewalk_width
	return lot_size() * 0.5 + Vector2.ONE * pad


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
