class_name HeadlightPool
extends MultiMeshInstance3D
## Night worlds: every car's headlight pool in one draw call. Follows the cars
## each frame (they only move while leaving, so this is cheap).


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2.ONE # each instance is scaled to its car
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/glow.gdshader")
	material.set_shader_parameter("glow_color", Color(1.0, 0.93, 0.72))
	material.set_shader_parameter("strength", 0.42)
	material.set_shader_parameter("stretch", 1.0)
	quad.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	var transforms := VehicleView.headlight_transforms()
	if multimesh.instance_count != transforms.size():
		multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
