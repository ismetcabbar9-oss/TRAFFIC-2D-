class_name Confetti
extends Control
## Burst of paper confetti shot up from the bottom corners; pieces tumble,
## flutter and fall, then the node frees itself. Drawn in one _draw call.

const COUNT := 120
const LIFETIME := 2.8
const GRAVITY := 1500.0
const DRAG := 1.3

var _pieces: Array[Dictionary] = []
var _age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := get_viewport_rect().size
	for i in COUNT:
		var left := i % 2 == 0
		var origin := Vector2(s.x * (0.08 if left else 0.92), s.y + 10.0)
		var angle := deg_to_rad(randf_range(-86.0, -62.0) if left else randf_range(-118.0, -94.0))
		var speed := randf_range(0.85, 1.25) * s.y * 2.0
		_pieces.append({
			"pos": origin, "vel": Vector2(cos(angle), sin(angle)) * speed,
			"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
			"size": Vector2(randf_range(14, 24), randf_range(8, 13)),
			"color": Cosmetics.color("confetti"), "flutter": randf() * TAU,
		})


func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	for p in _pieces:
		p.vel.y += GRAVITY * delta
		p.vel *= exp(-DRAG * delta) # air drag keeps the fall soft (frame-rate independent)
		p.flutter += delta * 7.0
		p.pos += (p.vel + Vector2(sin(p.flutter) * 60.0, 0.0)) * delta
		p.rot += p.spin * delta
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFETIME - _age) / 0.6, 0.0, 1.0)
	for p in _pieces:
		# Width shrinks with the flutter so pieces look like they flip.
		var w: float = p.size.x * absf(cos(p.flutter))
		draw_set_transform(p.pos, p.rot)
		draw_rect(Rect2(Vector2(-w, -p.size.y) * 0.5, Vector2(w, p.size.y)), Color(p.color, fade))
	draw_set_transform(Vector2.ZERO)
