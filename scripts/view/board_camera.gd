class_name BoardCamera
extends Camera3D
## Slightly tilted top-down camera that keeps the whole board on screen in both
## portrait and landscape.

@export_range(0.0, 45.0) var tilt_degrees := 23.0 ## 0 = straight down
@export var margin := 0.3 ## extra world units around the board
## Screen fraction reserved for the HUD at the top and kept free at the bottom.
@export var top_reserve := 0.12
@export var top_reserve_landscape := 0.18
@export var bottom_reserve := 0.13 ## rescue bar

@export var shake_decay := 2.2 ## trauma lost per second
@export var shake_max_offset := 0.35 ## world units at full trauma

var _half_extents := Vector2(6, 6)
var _center_z := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _fit := Transform3D() ## framed pose computed by _refit
var _intro := 1.0 ## 0 = start of the level intro, 1 = settled on the board
var _intro_tween: Tween


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
	_apply_pose()


func _apply_pose() -> void:
	if _intro >= 1.0:
		global_transform = _fit
		return
	# Start pulled back 35% and turned a little, then ease onto the fit.
	var start_basis := _fit.basis.rotated(Vector3.RIGHT, deg_to_rad(-8.0)).rotated(Vector3.UP, deg_to_rad(6.0))
	var start := Transform3D(start_basis, _fit.origin + _fit.basis.z * _fit.origin.length() * 0.35)
	global_transform = start.interpolate_with(_fit, _intro)
