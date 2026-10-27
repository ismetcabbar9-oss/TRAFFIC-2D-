class_name DirectionArrow
extends Node3D
## Flat arrow pointing along +Z (the vehicle's driving direction), drawn white
## with a dark outline so it reads on any car color. Unit size; scale to fit.

@export var fill_color := Color(1, 1, 1, 0.95)
@export var outline_color := Color(0.12, 0.14, 0.2, 0.85)
@export var outline_width := 0.07

const SHAPE := [
	Vector2(0.0, 0.5), Vector2(0.4, 0.02), Vector2(0.16, 0.02), Vector2(0.16, -0.5),
	Vector2(-0.16, -0.5), Vector2(-0.16, 0.02), Vector2(-0.4, 0.02),
]


func _ready() -> void:
	var outline := Geometry2D.offset_polygon(PackedVector2Array(SHAPE), outline_width, Geometry2D.JOIN_ROUND)
	_add_polygon("Outline", outline[0], 0.0, outline_color)
	_add_polygon("Fill", PackedVector2Array(SHAPE), 0.01, fill_color)


func _add_polygon(node_name: String, points: PackedVector2Array, y: float, color: Color) -> void:
	var vertices := PackedVector3Array()
	for p in points:
		vertices.append(Vector3(p.x, y, p.y))
	var indices := Geometry2D.triangulate_polygon(points)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
