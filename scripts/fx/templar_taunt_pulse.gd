extends Node2D

## 圣盾守护落地时的范围提示；只绘制光环，不参与命中结算。
var radius := 160.0
var life := 0.42
var elapsed := 0.0


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	if not is_instance_valid(source) or effect == null:
		queue_free()
		return
	global_position = source.global_position
	radius = maxf(effect.radius, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / life, 0.0, 1.0)
	var front := lerpf(18.0, radius, 1.0 - pow(1.0 - progress, 2.0))
	var fade := 1.0 - progress
	draw_circle(Vector2.ZERO, front, Color(1.0, 0.78, 0.27, 0.06 * fade))
	draw_arc(Vector2.ZERO, front, 0.0, TAU, 48, Color(1.0, 0.56, 0.13, 0.32 * fade), 17.0, true)
	draw_arc(Vector2.ZERO, front, 0.0, TAU, 48, Color(1.0, 0.90, 0.52, 0.85 * fade), 5.0, true)
	draw_arc(Vector2.ZERO, maxf(1.0, front - 25.0), 0.0, TAU, 48,
		Color(1.0, 0.75, 0.25, 0.27 * fade), 3.0, true)
