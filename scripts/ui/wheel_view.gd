class_name WheelView
extends Control
## The lucky wheel drawn in code: colored slices with their prize, a gold
## rim with bulbs and a hub. `spin_to` turns it a few times and stops with a
## slice under the pointer at the top, ticking as slices pass.

signal stopped(index: int)

const COLORS := [Color("ff5a5f"), Color("ffb23e"), Color("37c47a"), Color("4aa3ff"),
	Color("b07cff"), Color("ff8a3d"), Color("2ec4b6"), Color("ffd34d")]

var angle := 0.0: ## current turn of the wheel (radians)
	set(value):
		var slice := TAU / Wheel.PRIZES.size()
		if floori(value / slice) != floori(angle / slice):
			Sfx.play("ui_click", -10.0, 1.4, 0.05)
		angle = value
		queue_redraw()
var spinning := false


func _init() -> void:
	custom_minimum_size = Vector2(540, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Spins and stops with prize `index` under the pointer.
func spin_to(index: int) -> void:
	spinning = true
	var slice := TAU / Wheel.PRIZES.size()
	# Slice i is centered at angle + (i + 0.5) * slice from the top (-PI/2).
	var target := -(index + 0.5) * slice + randf_range(-0.3, 0.3) * slice
	var turns := TAU * 5.0
	var goal := angle - fposmod(angle, TAU) + turns + fposmod(target, TAU)
	var t := create_tween()
	t.tween_property(self, "angle", goal, 3.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		spinning = false
		stopped.emit(index))


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 22.0
	var n := Wheel.PRIZES.size()
	var slice := TAU / n
	draw_circle(c + Vector2(0, 8), r + 20.0, Color(0, 0, 0, 0.18)) # shadow
	draw_circle(c, r + 20.0, Color("e0a326"))
	draw_circle(c, r + 12.0, Color("ffd166"))
	for i in n:
		var a0 := -PI * 0.5 + angle + i * slice
		var pts := PackedVector2Array([c])
		for k in 13:
			var a := a0 + slice * k / 12.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, COLORS[i % COLORS.size()])
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color(1, 1, 1, 0.8), 3.0, true)
		_draw_prize(c, r, a0 + slice * 0.5, Wheel.PRIZES[i])
	for k in 16: # bulbs on the rim
		var a := k * TAU / 16.0
		draw_circle(c + Vector2(cos(a), sin(a)) * (r + 16.0), 5.0, Color.WHITE if k % 2 == 0 else Color("fff4d6"))
	draw_circle(c, r * 0.16, Color("e0a326"))
	draw_circle(c, r * 0.12, Color("ffd166"))
	# Pointer at the top.
	var tip := c + Vector2(0, -r + 18.0)
	var top := c + Vector2(0, -r - 34.0)
	draw_colored_polygon(PackedVector2Array([tip, top + Vector2(-26, 0), top + Vector2(26, 0)]), Color("d62839"))
	draw_circle(top, 14.0, Color("d62839"))
	draw_circle(top, 6.0, Color.WHITE)


## Prize text (and a coin) along the slice's middle, reading outward.
func _draw_prize(c: Vector2, r: float, a: float, prize: Dictionary) -> void:
	var font := UiStyle.font(800)
	var text := str(prize.amount) if prize.kind == "coins" else tr("RESCUE_" + str(prize.kind).to_upper())
	var size_px := 34 if prize.kind == "coins" else 24
	if prize.get("jackpot", false):
		size_px = 40
	draw_set_transform(c, a + PI * 0.5)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var y := -r * 0.62
	draw_string_outline(font, Vector2(-w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 8, Color(0, 0, 0, 0.35))
	draw_string(font, Vector2(-w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)
	if prize.kind == "coins":
		var coin := Vector2(0, -r * 0.84)
		draw_circle(coin, 14.0, Color("ffc93c"))
		draw_arc(coin, 9.0, 0.0, TAU, 16, Color("e0a326"), 2.0, true)
	draw_set_transform(Vector2.ZERO)
