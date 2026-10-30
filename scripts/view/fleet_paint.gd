class_name FleetPaint
## Garage paint job ("fleet theme"): repaints the body of every civilian car on
## the lot. Police, ambulance, fire truck, taxi and tanker keep their own
## colors. Solid paints share one color, palette paints give each car one of
## a few colors, rainbow runs through all of them; chrome and gold are
## metallic, neon glows. Flat-colored models swap their body material;
## textured ones get a recolored copy of their texture (cached).

## Body material of the flat-colored models.
const PAINT_MATERIAL := {
	"sedan_sports": "body_red", "suv": "body_dark_purple", "suv_luxury": "body_light_yellow",
	"van": "body_dark_blue", "pickup": "body_dark_green", "delivery": "body_dark_green",
	"bus": "body_light_blue",
}
## Textured models: the paint is the lower right quarter of their texture
## (a dark-to-light gradient) plus the palette stripe of the same hue that the
## sides use; lights and trim have other hues.
const TEXTURED := ["sedan", "hatchback"]

static var _materials := {} ## key -> material
static var _textures := {} ## key -> recolored texture


## Repaints `model` (a freshly loaded vehicle of `type`) with the equipped
## paint; `index` picks the car's color in palette and rainbow paints.
static func apply(model: Node, type: String, index: int, item := {}) -> void:
	if item.is_empty():
		var id := ""
		var progress := Cosmetics._progress()
		if progress:
			id = progress.equipped("paint")
		item = Cosmetics.find(id)
	if item.is_empty() or item.get("mode", "factory") == "factory":
		return
	if not PAINT_MATERIAL.has(type) and not type in TEXTURED:
		return
	var color := _color_for(item, index)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		var hue := -1.0 # factory paint hue of a textured model (from its first surface)
		for s in mesh.get_surface_count():
			var base := mesh.surface_get_material(s) as StandardMaterial3D
			if base == null:
				continue
			if type in TEXTURED:
				if base.albedo_texture == null:
					continue
				if hue < 0.0:
					var img := base.albedo_texture.get_image()
					if img.is_compressed():
						img.decompress()
					hue = img.get_pixel(img.get_width() * 3 / 4, img.get_height() * 3 / 4).h
				(mi as MeshInstance3D).set_surface_override_material(s, _textured(base, item, color, hue, s == 0))
			elif base.resource_name == PAINT_MATERIAL[type]:
				(mi as MeshInstance3D).set_surface_override_material(s, _flat(base, item, color))


static func _color_for(item: Dictionary, index: int) -> Color:
	var colors: Array = item.colors
	match item.mode:
		"palette", "rainbow":
			return colors[posmod(index * 7 + 3, colors.size())] if item.mode == "palette" else colors[index % colors.size()]
	return colors[0]


static func _flat(base: StandardMaterial3D, item: Dictionary, color: Color) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [base.resource_name, item.id, color.to_html()]
	if not _materials.has(key):
		var m := base.duplicate() as StandardMaterial3D
		m.albedo_color = color
		_finish(m, item, color)
		_materials[key] = m
	return _materials[key]


static func _textured(base: StandardMaterial3D, item: Dictionary, color: Color, hue: float, quarter: bool) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [base.albedo_texture.resource_path, item.id, color.to_html()]
	if not _materials.has(key):
		var m := base.duplicate() as StandardMaterial3D
		m.albedo_texture = _recolored(base.albedo_texture, color, hue, quarter)
		_finish(m, item, color)
		_materials[key] = m
	return _materials[key]


static func _finish(m: StandardMaterial3D, item: Dictionary, color: Color) -> void:
	m.metallic = float(item.get("metallic", 0.0))
	m.roughness = float(item.get("roughness", 0.6))
	var glow := float(item.get("glow", 0.0))
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow


## The texture with its paint repainted in `color`: every pixel close to the
## factory paint `hue` (and the paint quarter itself, on the paint surface),
## keeping its shade.
static func _recolored(texture: Texture2D, color: Color, hue: float, quarter: bool) -> Texture2D:
	var key := "%s|%s" % [texture.resource_path, color.to_html()]
	if _textures.has(key):
		return _textures[key]
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps() # the smaller copies would keep the old paint
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			var in_quarter := quarter and x >= w / 2 and y >= h / 2
			var near := absf(wrapf(p.h - hue, -0.5, 0.5)) < 0.04 and p.s > 0.3 and p.v > 0.15
			if not in_quarter and not near:
				continue
			var shade := clampf(p.v / 0.75, 0.55, 1.2)
			img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, p.a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex
