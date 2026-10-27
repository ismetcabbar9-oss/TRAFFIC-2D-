class_name MistakeMeter
extends Control
## Row of pips showing wrong moves left: full = available, grey = used.

@export var pip_radius := 15.0
@export var spacing := 12.0

var total := 3
var left := 3

var _pop := {} ## pip index -> scale while animating


func set_counts(p_left: int, p_total: int) -> void:
	var lost := left > p_left
	total = p_total
	left = clampi(p_left, 0, p_total)
	custom_minimum_size = Vector2(total * (pip_radius * 2.0 + spacing) - spacing, pip_radius * 2.0 + 8.0)
	if lost:
		_animate_loss(left)
	queue_redraw()


func _animate_loss(index: int) -> void:
	var tween := create_tween()
	tween.tween_method(func(s: float): _set_pop(index, s), 1.7, 1.0, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_pop(index: int, s: float) -> void:
	_pop[index] = s
	queue_redraw()


func _draw() -> void:
	var y := size.y * 0.5
	var start := (size.x - (total * (pip_radius * 2.0 + spacing) - spacing)) * 0.5
	for i in total:
		var center := Vector2(start + pip_radius + i * (pip_radius * 2.0 + spacing), y)
		var r: float = pip_radius * _pop.get(i, 1.0)
		var available := i < left
		draw_circle(center + Vector2(0, 3), r, Color(0, 0, 0, 0.18))
		draw_circle(center, r, UiStyle.DANGER if available else UiStyle.MUTED)
		draw_circle(center, r * 0.62, Color.WHITE if available else Color("e9ecf2"))
		draw_circle(center, r * 0.42, UiStyle.DANGER if available else UiStyle.MUTED)
