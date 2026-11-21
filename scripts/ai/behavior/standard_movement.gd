class_name StandardMovement
extends MovementStrategy

## 从交战目标周围挑选可攻击、少拥挤的位置。策略资源只保存参数。
const FORMATION_BANDS := [0, -1, 1, -2, 2]
const MELEE_ANGLES := [0.0, -42.0, 42.0, -84.0, 84.0, -126.0, 126.0, 180.0]
const RANGED_ANGLES := [0.0, -25.0, 25.0, -50.0, 50.0]
const RETREAT_ANGLES := [-38.0, 38.0, 0.0, -72.0, 72.0, -108.0, 108.0]

@export var preferred_range_ratio := 1.0
@export var lateral_span := 50.0
@export var forward_ratio := 0.92
@export var flank_y_bias := 0.0
@export var kite_ratio := 0.42
@export var kite_stop_ratio := 0.72


func desired_position(unit: Unit) -> Vector2:
	if not unit.has_live_target() or unit.battle == null:
		return unit.global_position
	if unit.battle.training_mode:
		return _training_position(unit)

	var ranged := unit.definition.is_ranged()
	var reach := unit.basic_target_reach()
	var stop := maxf(unit.basic_target_reach(-8.0) * preferred_range_ratio * forward_ratio, 1.0)
	var center := unit.target.global_position
	var front := Vector2.LEFT if unit.team == 0 else Vector2.RIGHT
	var band: float = FORMATION_BANDS[posmod(unit.slot, FORMATION_BANDS.size())]
	var preferred_angle := band * lateral_span * (0.30 if ranged else 0.63)
	if unit.definition.role == "坦克":
		preferred_angle *= 0.55
	var default_side := -1.0 if band < 0.0 else 1.0
	preferred_angle += default_side * flank_y_bias * 2.0
	var preferred := front.rotated(deg_to_rad(preferred_angle * front.x))
	var nearby: Array[Unit] = unit.battle.living_units()
	var current := unit.global_position
	var choices: Array[Vector2] = []
	for angle in RANGED_ANGLES if ranged else MELEE_ANGLES:
		var sample := center + front.rotated(deg_to_rad(angle * front.x)) * stop
		var point: Vector2 = unit.battle.clamp_unit_position(sample)
		if point.distance_to(center) >= stop * 0.76:
			choices.append(point)
	if current.distance_to(center) <= reach:
		choices.append(current)

	var best := current
	var best_cost := INF
	for point in choices:
		var offset := point - center
		var cost := current.distance_to(point) * 0.010
		cost += absf(offset.length() - stop) * (0.07 if ranged else 0.11)
		cost += absf(preferred.angle_to(offset)) * (2.0 if ranged else 1.8)
		cost += _crowding_cost(unit, point, nearby)
		if unit.brain.movement_target == unit.target and not unit.brain.is_retreating:
			cost += minf(point.distance_to(unit.brain.movement_destination) * 0.016, 2.2)
		if point == current:
			cost -= 1.45
		if cost < best_cost:
			best_cost = cost
			best = point
	return best


func retreat_position(unit: Unit, threat: Unit) -> Vector2:
	var current := unit.global_position
	var away := threat.global_position.direction_to(current)
	if away.is_zero_approx():
		away = Vector2.LEFT if unit.team == 0 else Vector2.RIGHT
	var needed := unit.kite_stop_distance() - current.distance_to(threat.global_position)
	var retreat_step := clampf(needed * 1.55, 84.0, 225.0)
	var nearby: Array[Unit] = unit.battle.living_units()
	var best := current
	var best_score := _retreat_safety(unit, current, nearby) + 5.0
	var side := -1.0 if posmod(unit.slot, 2) == 0 else 1.0
	for angle in RETREAT_ANGLES:
		var offset := away.rotated(deg_to_rad(angle * side)) * retreat_step
		var point: Vector2 = unit.battle.clamp_unit_position(current + offset)
		if point.distance_squared_to(current) < 32.0 * 32.0:
			continue
		var score := _retreat_safety(unit, point, nearby)
		# 预留下一步的撤退空间，避免贴边以后只会沿被截断的方向跑。
		score -= (current + offset).distance_to(point) * 0.25
		if angle != 0.0:
			score += 12.0
		if unit.brain.is_retreating and unit.brain.movement_target == threat:
			score -= minf(point.distance_to(unit.brain.movement_destination) * 0.16, 26.0)
		if score > best_score:
			best_score = score
			best = point
	return best


func _crowding_cost(unit: Unit, point: Vector2, nearby: Array[Unit]) -> float:
	var cost := 0.0
	for other in nearby:
		if other == unit or other == unit.target:
			continue
		var clearance := unit.body_radius + other.body_radius
		var separation := point.distance_to(other.global_position)
		cost += maxf(0.0, 1.0 - separation / (clearance + 20.0)) * 8.0
		if other.team == unit.team:
			var spacing := clearance + 56.0
			cost += maxf(0.0, 1.0 - separation / spacing) * 5.0
			if other.brain.has_movement_goal():
				var reserved_distance := point.distance_to(other.brain.movement_destination)
				cost += maxf(0.0, 1.0 - reserved_distance / spacing) * 8.0
		elif unit.definition.is_ranged() or unit.hp_ratio() < 0.45:
			var threat_range := maxf(unit.attack_range * 0.48, 95.0)
			cost += maxf(0.0, 1.0 - separation / threat_range) * 7.0
	return cost


func _retreat_safety(unit: Unit, point: Vector2, nearby: Array[Unit]) -> float:
	var safest_gap := unit.kite_stop_distance()
	var cost := 0.0
	for other in nearby:
		if other == unit:
			continue
		var distance := point.distance_to(other.global_position)
		var clearance := unit.body_radius + other.body_radius
		if other.team != unit.team:
			safest_gap = minf(safest_gap, distance - other.body_radius * 0.5)
		else:
			cost += maxf(0.0, clearance + 24.0 - distance) * 0.7
	return safest_gap - cost


func _training_position(unit: Unit) -> Vector2:
	var stop := maxf(unit.basic_target_reach(-18.0) * preferred_range_ratio, 54.0)
	var span := minf(lateral_span, stop * 0.36)
	var lateral := (2.0 - float(unit.slot)) / 2.0 * span + flank_y_bias
	var forward := sqrt(maxf(stop * stop - lateral * lateral, 0.0)) * forward_ratio
	var side := -1.0 if unit.team == 0 else 1.0
	return unit.battle.clamp_unit_position(unit.target.global_position + Vector2(side * forward, lateral))


func should_kite(unit: Unit) -> bool:
	if not unit.definition.is_ranged() or not unit.has_live_target():
		return false
	if unit.battle.training_mode:
		return unit.distance_to_target() < unit.attack_range * kite_ratio
	var threat: Unit = unit.brain.observation.get("nearest")
	if not is_instance_valid(threat) or not threat.alive:
		return false
	var ratio := kite_stop_ratio if unit.brain.is_retreating else kite_ratio
	return unit.global_position.distance_to(threat.global_position) < unit.attack_range * ratio


func get_kite_stop_ratio() -> float:
	return kite_stop_ratio
