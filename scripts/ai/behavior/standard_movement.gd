class_name StandardMovement
extends MovementStrategy

## 通用阵型移动：围绕目标占据错开的侧向位置；远程可以后撤。

@export var preferred_range_ratio := 1.0
@export var lateral_span := 50.0
@export var forward_ratio := 0.92
@export var flank_y_bias := 0.0
@export var kite_ratio := 0.42
@export var kite_stop_ratio := 0.72


func desired_position(unit: Unit) -> Vector2:
	if not unit.has_live_target() or unit.battle == null:
		return unit.global_position
	var stop := maxf(unit.target_reach(-18.0) * preferred_range_ratio, 54.0)
	var span := minf(lateral_span, stop * 0.36)
	var lateral := (2.0 - float(unit.slot)) / 2.0 * span + flank_y_bias
	var forward := sqrt(maxf(stop * stop - lateral * lateral, 0.0)) * forward_ratio
	var side := -1.0 if unit.team == 0 else 1.0
	return unit.battle.clamp_unit_position(
		unit.target.global_position + Vector2(side * forward, lateral)
	)


func should_kite(unit: Unit) -> bool:
	if not unit.definition.is_ranged() or not unit.has_live_target():
		return false
	return unit.distance_to_target() < unit.attack_range * kite_ratio
