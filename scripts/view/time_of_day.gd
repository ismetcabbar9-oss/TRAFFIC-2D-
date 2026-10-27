class_name TimeOfDay
## Gentle time-of-day lighting: the sun moves from east (morning) over the
## south (noon, behind the camera) to the west (evening), sinking and warming
## as it goes. Kept subtle so the board always stays easy to read.

const FIRST_HOUR := 8.0 ## level 1
const LAST_HOUR := 19.0 ## last level

## hour -> [sun color, sun energy, ambient color, ambient energy]
const KEYS := [
	[8.0, Color(1.0, 0.89, 0.76), 0.92, Color(0.80, 0.86, 1.0), 0.52],
	[12.0, Color(1.0, 0.97, 0.92), 1.0, Color(0.85, 0.9, 1.0), 0.5],
	[16.0, Color(1.0, 0.9, 0.74), 0.97, Color(0.86, 0.86, 0.95), 0.5],
	[19.0, Color(1.0, 0.8, 0.64), 0.92, Color(0.86, 0.82, 0.92), 0.52],
]
const MAX_ELEVATION := 62.0 ## degrees, at noon
const MIN_ELEVATION := 30.0 ## never lower: long shadows would hide cars
const NIGHT_HOUR := 22.0 ## label hour used by night worlds


## Hour of day for a level, spread evenly from morning to sunset.
static func hour_for_level(index: int, count: int) -> float:
	if count <= 1:
		return 12.0
	return lerpf(FIRST_HOUR, LAST_HOUR, float(index % count) / (count - 1))


static func label(hour: float) -> String:
	if hour >= 21.0:
		return TranslationServer.translate("TOD_NIGHT")
	if hour < 11.0:
		return TranslationServer.translate("TOD_MORNING")
	if hour < 14.0:
		return TranslationServer.translate("TOD_NOON")
	if hour < 17.0:
		return TranslationServer.translate("TOD_AFTERNOON")
	return TranslationServer.translate("TOD_EVENING")


## Points `sun` and tints it and the ambient light for `hour`.
## The scales compensate for renderers that light differently.
static func apply(hour: float, sun: DirectionalLight3D, env: Environment,
		sun_scale := 1.0, ambient_scale := 1.0) -> void:
	var swing := clampf((hour - 12.0) / 6.0, -1.0, 1.0) * PI * 0.5 # -90° east .. +90° west
	var elevation := deg_to_rad(maxf(MAX_ELEVATION * cos(swing), MIN_ELEVATION))
	var horizontal := Vector3(-sin(swing), 0.0, cos(swing)) # east = +X, south = +Z
	var sun_dir := (horizontal * cos(elevation) + Vector3.UP * sin(elevation)).normalized()
	# A directional light shines along its -Z: from the sun toward the ground.
	sun.global_basis = Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)

	var k := _sample(hour)
	sun.light_color = k[0]
	sun.light_energy = k[1] * sun_scale
	env.ambient_light_color = k[2]
	env.ambient_light_energy = k[3] * ambient_scale


## Night: cool moonlight from high up and a deep blue ambient, bright enough
## that every car stays easy to read.
static func apply_night(sun: DirectionalLight3D, env: Environment, sun_scale := 1.0, ambient_scale := 1.0) -> void:
	var sun_dir := Vector3(0.35, 1.0, 0.45).normalized()
	sun.global_basis = Basis.looking_at(-sun_dir, Vector3.UP)
	sun.light_color = Color(0.66, 0.75, 1.0)
	sun.light_energy = 0.55 * sun_scale
	env.ambient_light_color = Color(0.45, 0.52, 0.85)
	env.ambient_light_energy = 0.72 * ambient_scale


static func _sample(hour: float) -> Array:
	if hour <= KEYS[0][0]:
		return KEYS[0].slice(1)
	for i in range(1, KEYS.size()):
		if hour <= KEYS[i][0]:
			var a: Array = KEYS[i - 1]
			var b: Array = KEYS[i]
			var t: float = (hour - a[0]) / (b[0] - a[0])
			return [(a[1] as Color).lerp(b[1], t), lerpf(a[2], b[2], t),
					(a[3] as Color).lerp(b[3], t), lerpf(a[4], b[4], t)]
	return KEYS[-1].slice(1)
