class_name ActionTargetQuery
extends RefCounted

## AI 估算与实际结算共用的目标形状查询。


static func enemies(source: Unit, effect: ActionEffectDefinition, target: Unit, direction: Vector2, point := Vector2.ZERO, use_point := false) -> Array[Unit]:
	return _collect(source, effect, target, direction, point, use_point, false)


static func allies(source: Unit, effect: ActionEffectDefinition, target: Unit, direction: Vector2, point := Vector2.ZERO, use_point := false) -> Array[Unit]:
	return _collect(source, effect, target, direction, point, use_point, true)


## 在可到达区域内寻找覆盖最多敌人的圆形施法点；同人数时优先救援被追击友军，再靠近敌群中心。
static func densest_circle_point(source: Unit, enemies: Array, radius: float, max_distance: float) -> Dictionary:
	if not is_instance_valid(source) or source.battle == null or radius <= 0.0 or max_distance <= 0.0:
		return {}
	var candidates: Array[Vector2] = [source.global_position]
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			candidates.append(enemy.global_position)
	for left_index in enemies.size():
		var left: Unit = enemies[left_index]
		if not is_instance_valid(left) or not left.alive:
			continue
		for right_index in range(left_index + 1, enemies.size()):
			var right: Unit = enemies[right_index]
			if not is_instance_valid(right) or not right.alive:
				continue
			for third_index in range(right_index + 1, enemies.size()):
				var third: Unit = enemies[third_index]
				if is_instance_valid(third) and third.alive:
					candidates.append((left.global_position + right.global_position + third.global_position) / 3.0)
			var offset := right.global_position - left.global_position
			var distance := offset.length()
			if distance < 0.001:
				continue
			candidates.append((left.global_position + right.global_position) * 0.5)
			var left_radius := radius + left.body_radius
			var right_radius := radius + right.body_radius
			if distance > left_radius + right_radius or distance < absf(left_radius - right_radius):
				continue
			var along := (left_radius * left_radius - right_radius * right_radius + distance * distance) / (2.0 * distance)
			var sideways := sqrt(maxf(0.0, left_radius * left_radius - along * along))
			var direction := offset / distance
			var midpoint := left.global_position + direction * along
			var normal := Vector2(-direction.y, direction.x) * sideways
			candidates.append(midpoint + normal)
			candidates.append(midpoint - normal)
	var best_count := 0
	var best_threat := -1.0
	var best_spread := INF
	var best_distance := INF
	var best_point := source.global_position
	var best_anchor: Unit = null
	for raw_point in candidates:
		var point: Vector2 = source.battle.clamp_unit_position(raw_point)
		var offset := point - source.global_position
		if offset.length() > max_distance:
			point = source.battle.clamp_unit_position(source.global_position + offset.normalized() * max_distance)
		var count := 0
		var threat := 0.0
		var spread := 0.0
		var anchor: Unit = null
		var anchor_distance := INF
		for enemy in enemies:
			if not is_instance_valid(enemy) or not enemy.alive:
				continue
			var enemy_distance: float = point.distance_to(enemy.global_position)
			if enemy_distance > radius + enemy.body_radius:
				continue
			count += 1
			spread += enemy_distance * enemy_distance
			if enemy_distance < anchor_distance:
				anchor = enemy
				anchor_distance = enemy_distance
			if enemy.has_live_target() and enemy.target.team == source.team:
				threat += 2.0 if enemy.target.definition.is_ranged() else 1.0
				threat += 1.0 - enemy.target.hp_ratio()
		var travel := source.global_position.distance_to(point)
		if count > best_count or (count == best_count and (threat > best_threat + 0.001
				or (is_equal_approx(threat, best_threat) and (spread < best_spread - 0.01
					or (is_equal_approx(spread, best_spread) and travel < best_distance))))):
			best_count = count
			best_threat = threat
			best_spread = spread
			best_distance = travel
			best_point = point
			best_anchor = anchor
	return {"point": best_point, "count": best_count, "anchor": best_anchor, "threat": best_threat}


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
