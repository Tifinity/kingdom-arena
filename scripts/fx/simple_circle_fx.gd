extends Node2D

## 简单的圆圈提示：怒吼显示施法范围，减速状态显示目标脚下的圆圈。
@export var radius := 160.0
@export var lifetime := 0.0
@export var ring_color := Color(0.58, 0.80, 1.0, 0.85)

var _elapsed := 0.0


func _ready() -> void:
	if lifetime <= 0.0:
		var owner_unit := get_parent().get_parent() as Unit
		if owner_unit != null:
			radius = owner_unit.body_radius + 10.0
	queue_redraw()


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	global_position = source.global_position
	radius = effect.radius
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if lifetime > 0.0 and _elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 if lifetime <= 0.0 else 1.0 - _elapsed / lifetime
	var pulse := 1.0 + 0.025 * sin(_elapsed * 12.0)
	var color := ring_color
	color.a *= alpha
	draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 64, color, 3.0, true)
