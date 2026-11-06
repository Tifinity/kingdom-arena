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
	var preferred: Vector2 = unit.battle.clamp_unit_position(unit.target.global_position + Vector2(side * forward, lateral))
	var candidates: Array[Vector2] = [preferred, unit.global_position]
	for offset in [-100.0, -50.0, 50.0, 100.0]:
		candidates.append(unit.battle.clamp_unit_position(preferred + Vector2(0.0, offset)))
	for offset in [-40.0, 40.0]:
		candidates.append(unit.battle.clamp_unit_position(preferred + Vector2(side * offset, 0.0)))
	var nearby_units: Array[Unit] = unit.battle.living_units()
	var best := preferred
	var best_cost := INF
	for point in candidates:
		var cost := absf(point.distance_to(unit.target.global_position) - stop) / stop * 4.0
		cost += point.distance_to(preferred) * 0.004
		cost += point.distance_to(unit.global_position) * 0.002
		if point == unit.global_position:
			cost -= 0.25
		for other in nearby_units:
			if other == unit:
				continue
			var separation := point.distance_to(other.global_position)
			if other.team == unit.team:
				cost += maxf(0.0, 1.0 - separation / (unit.body_radius + other.body_radius + 20.0)) * 2.0
			elif unit.definition.is_ranged():
				cost += maxf(0.0, 1.0 - separation / maxf(unit.attack_range * 0.55, 90.0)) * 3.0
			elif unit.hp_ratio() < 0.45 and other != unit.target:
				cost += maxf(0.0, 1.0 - separation / 120.0)
		if cost < best_cost:
			best_cost = cost
			best = point
	return best


func should_kite(unit: Unit) -> bool:
	if not unit.definition.is_ranged() or not unit.has_live_target():
		return false
	return unit.distance_to_target() < unit.attack_range * kite_ratio
