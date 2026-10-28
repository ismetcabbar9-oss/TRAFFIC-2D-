class_name BoardCamera
extends Camera3D
## Slightly tilted top-down camera that keeps the whole board on screen in both
## portrait and landscape. The player can zoom in (pinch, double tap, mouse
## wheel) and pan around while zoomed; the view never leaves the board.

@export_range(0.0, 45.0) var tilt_degrees := 23.0 ## 0 = straight down
@export var margin := 0.3 ## extra world units around the board
## Screen fraction reserved for the HUD at the top and kept free at the bottom.
@export var top_reserve := 0.12
@export var top_reserve_landscape := 0.18
@export var bottom_reserve := 0.13 ## rescue bar

@export var max_zoom := 2.6 ## 1 = whole board

@export var shake_decay := 2.2 ## trauma lost per second
@export var shake_max_offset := 0.35 ## world units at full trauma

var _half_extents := Vector2(6, 6)
var _center_z := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _fit := Transform3D() ## framed pose computed by _refit
var _intro := 1.0 ## 0 = start of the level intro, 1 = settled on the board
var _intro_tween: Tween
var _fit_target := Vector3.ZERO ## look-at point of the framed pose
var _fit_dist := 10.0 ## camera distance of the framed pose
var zoom := 1.0
var pan := Vector2.ZERO ## XZ offset of the look-at point while zoomed
var _zoom_tween: Tween


func _ready() -> void:
	get_viewport().size_changed.connect(_refit)


## Adds screen shake; `amount` in 0..1 (strength grows with its square).
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	_shake_time += delta * 45.0
	var strength := _trauma * _trauma * shake_max_offset
	h_offset = sin(_shake_time * 1.3) * strength
	v_offset = cos(_shake_time * 1.7 + 1.0) * strength


## Glides in from a little higher and further back onto the framed board.
func play_intro(duration := 0.8) -> void:
	if _intro_tween:
		_intro_tween.kill()
	_intro = 0.0
	_apply_pose()
	_intro_tween = create_tween()
	_intro_tween.tween_method(func(v: float): _intro = v; _apply_pose(), 0.0, 1.0, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Frames the board (centered half extents) plus `extra_bottom` world units
## below it, e.g. the exit barrier.
func frame_board(half_extents: Vector2, extra_bottom := 0.0) -> void:
	_half_extents = half_extents + Vector2(0.0, extra_bottom * 0.5) + Vector2.ONE * margin
	_center_z = extra_bottom * 0.5
	_refit()


func _refit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return
	var aspect := vp.x / vp.y
	var tilt := deg_to_rad(tilt_degrees)
	var top := top_reserve_landscape if aspect > 1.0 else top_reserve
	var usable := 1.0 - top - bottom_reserve
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var tan_h := tan_v * aspect

	# Distance needed to fit width and (tilt-foreshortened) depth.
	var dist_w := _half_extents.x / tan_h
	var depth := _half_extents.y * cos(tilt)
	var dist_d := depth / (tan_v * usable) + _half_extents.y * sin(tilt)
	var dist := maxf(dist_w, dist_d)

	var basis := Basis.from_euler(Vector3(-PI * 0.5 + tilt, 0.0, 0.0))
	var forward := -basis.z
	# Shift the look-at point so the board sits between the HUD reserves.
	var shift := (top - bottom_reserve) * 0.5 * 2.0 * tan_v * dist
	var target := Vector3(0.0, 0.0, _center_z - shift * cos(tilt))
	_fit = Transform3D(basis, target - forward * dist)
	_fit_target = target
	_fit_dist = dist
	_apply_pose()


func is_zoomed() -> bool:
	return zoom > 1.01


## Back to the whole board (level start).
func reset_view() -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	zoom = 1.0
	pan = Vector2.ZERO
	_apply_pose()


## Zooms by `factor` keeping the ground point under `screen_pos` in place.
func zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before: Variant = ground_point(screen_pos)
	zoom = clampf(zoom * factor, 1.0, max_zoom)
	_clamp_pan()
	_apply_pose()
	var after: Variant = ground_point(screen_pos)
	if before != null and after != null:
		pan += Vector2(before.x - after.x, before.z - after.z)
		_clamp_pan()
		_apply_pose()


## Moves the view with a finger drag of `delta` screen pixels.
func pan_by(delta: Vector2) -> void:
	if not is_zoomed():
		return
	var vp := get_viewport().get_visible_rect().size
	var per_pixel := 2.0 * tan(deg_to_rad(fov) * 0.5) * (_fit_dist / zoom) / vp.y
	pan -= Vector2(delta.x, delta.y / cos(deg_to_rad(tilt_degrees))) * per_pixel
	_clamp_pan()
	_apply_pose()


## Double tap: zoom in on `world` point, or back out when already zoomed.
func toggle_zoom(world: Vector3) -> void:
	var to_zoom := 1.0 if is_zoomed() else 2.0
	var to_pan := Vector2.ZERO
	if to_zoom > 1.0:
		to_pan = Vector2(world.x - _fit_target.x, world.z - _fit_target.z)
	var from_zoom := zoom
	var from_pan := pan
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_method(func(t: float):
		zoom = lerpf(from_zoom, to_zoom, t)
		pan = from_pan.lerp(to_pan, t)
		_clamp_pan()
		_apply_pose(), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Ground point (y = 0 plane) seen at a screen position, or null.
func ground_point(screen_pos: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.0).intersects_ray(project_ray_origin(screen_pos), project_ray_normal(screen_pos))


## Keeps the zoomed view over the board: the further in, the more it may move.
func _clamp_pan() -> void:
	var room := _half_extents * (1.0 - 1.0 / zoom)
	pan = pan.clamp(-room, room)


func _apply_pose() -> void:
	var view := _fit
	if zoom > 1.0 or pan != Vector2.ZERO:
		var forward := -_fit.basis.z
		view = Transform3D(_fit.basis, _fit_target + Vector3(pan.x, 0.0, pan.y) - forward * (_fit_dist / zoom))
	if _intro >= 1.0:
		global_transform = view
		return
	# Start pulled back 35% and turned a little, then ease onto the fit.
	var start_basis := _fit.basis.rotated(Vector3.RIGHT, deg_to_rad(-8.0)).rotated(Vector3.UP, deg_to_rad(6.0))
	var start := Transform3D(start_basis, _fit.origin + _fit.basis.z * _fit.origin.length() * 0.35)
	global_transform = start.interpolate_with(view, _intro)
