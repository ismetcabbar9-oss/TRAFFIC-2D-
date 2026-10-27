class_name VehicleView
extends Node3D
## Visual for one vehicle: loads its model, faces it along its direction and
## scales it to fit its footprint on the grid.

const SIDE_GAP := 0.28 ## free space left beside the car inside its cell
const END_GAP := 0.45 ## free space left between bumpers inside the slot

const ARROW_SCENE := preload("res://scenes/direction_arrow.tscn")

var state: VehicleState
var type: String:
	get: return state.type
var dir: int:
	get: return state.dir
var cell: Vector2i:
	get: return state.cell
var length: int:
	get: return state.length

var _model: Node3D


func setup(board: BoardView, p_state: VehicleState) -> void:
	state = p_state
	name = "Vehicle%d_%s" % [state.id, type]

	_model = VehicleCatalog.load_model(type).instantiate()
	add_child(_model)
	var top := _fit_model(board.theme.cell_size)
	_add_contact_shadow(board.theme.cell_size)
	_add_arrow(board.theme.cell_size, top)

	rotation.y = GridDir.to_yaw(dir)
	position = board.cell_to_world(footprint_center())


## Center of the footprint in (fractional) cell coordinates.
func footprint_center() -> Vector2:
	var span := Vector2(length - 1, 0) if GridDir.is_horizontal(dir) else Vector2(0, length - 1)
	return Vector2(cell) + span * 0.5


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
	# Center the model on its footprint.
	var c := aabb.get_center()
	var offset := Vector3(-c.x, 0.0, -c.z) * _model.scale
	if _model.rotation.y != 0.0:
		offset = -offset
	_model.position = offset
	return aabb.end.y * s


func _add_arrow(cell_size: float, roof: float) -> void:
	var arrow: Node3D = ARROW_SCENE.instantiate()
	arrow.position.y = roof + 0.04
	arrow.scale = Vector3.ONE * cell_size * 0.5
	add_child(arrow)


## Soft dark patch under the car so it reads as grounded on any renderer.
func _add_contact_shadow(cell_size: float) -> void:
	var quad := MeshInstance3D.new()
	quad.name = "ContactShadow"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(cell_size - SIDE_GAP * 0.4, cell_size * length - END_GAP * 0.6)
	quad.mesh = mesh
	quad.material_override = _contact_shadow_material()
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position.y = 0.005
	add_child(quad)


static var _shadow_material: StandardMaterial3D

static func _contact_shadow_material() -> StandardMaterial3D:
	if _shadow_material == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0.45))
		gradient.set_color(1, Color(0, 0, 0, 0))
		gradient.add_point(0.55, Color(0, 0, 0, 0.35))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_SQUARE
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_shadow_material = StandardMaterial3D.new()
		_shadow_material.albedo_texture = tex
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _shadow_material


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
