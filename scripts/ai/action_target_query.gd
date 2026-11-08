class_name ActionTargetQuery
extends RefCounted

## AI 估算与实际结算共用的目标形状查询。


static func enemies(source: Unit, effect: ActionEffectDefinition, target: Unit, direction: Vector2, point := Vector2.ZERO, use_point := false) -> Array[Unit]:
	return _collect(source, effect, target, direction, point, use_point, false)


static func allies(source: Unit, effect: ActionEffectDefinition, target: Unit, direction: Vector2, point := Vector2.ZERO, use_point := false) -> Array[Unit]:
	return _collect(source, effect, target, direction, point, use_point, true)


static func _collect(source: Unit, effect: ActionEffectDefinition, target: Unit, direction: Vector2, point: Vector2, use_point: bool, friendly: bool) -> Array[Unit]:
	var result: Array[Unit] = []
	if source == null or source.battle == null or effect == null:
		return result
	var valid_target := target != null and is_instance_valid(target) and target.alive
	if effect.shape == ActionEffectDefinition.Shape.SELF:
		if friendly:
			result.append(source)
		return result
	if effect.shape == ActionEffectDefinition.Shape.SINGLE:
		if valid_target and (target.team == source.team) == friendly:
			result.append(target)
		return result
	var aim := direction.normalized()
	if aim.length_squared() < 0.0001:
		aim = (target.global_position - source.global_position).normalized() if valid_target else Vector2(float(source.facing), 0.0)
	if aim.length_squared() < 0.0001:
		aim = Vector2(float(source.facing), 0.0)
	var center := source.global_position if effect.center_on_self else (point if use_point else (target.global_position if valid_target else source.global_position))
	var half_angle := deg_to_rad(absf(effect.half_angle))
	var side := Vector2(-aim.y, aim.x)
	var half_width := maxf(effect.width, 1.0) * 0.5
	for victim in source.battle.living_units():
		if (victim.team == source.team) != friendly:
			continue
		var offset: Vector2 = victim.global_position - source.global_position
		match effect.shape:
			ActionEffectDefinition.Shape.CIRCLE:
				if victim.global_position.distance_to(center) <= effect.radius + victim.body_radius:
					result.append(victim)
			ActionEffectDefinition.Shape.CONE:
				if offset.length() <= effect.radius + victim.body_radius and (offset.length_squared() < 0.0001 or absf(aim.angle_to(offset.normalized())) <= half_angle):
					result.append(victim)
			ActionEffectDefinition.Shape.RECT:
				var forward: float = offset.dot(aim)
				if forward >= -victim.body_radius and forward <= effect.length + victim.body_radius and absf(offset.dot(side)) <= half_width + victim.body_radius:
					result.append(victim)
	return result
