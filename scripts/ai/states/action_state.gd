class_name UnitActionState
extends UnitState

## 统一的行动状态：执行 Brain 选出的 ActionPlan 中的 CombatActionDefinition。
## 普攻、技能、未来的护盾/突进都走这里；状态机不区分 Attack 和 Skill。

var _action: CombatActionDefinition
var _cast: ActionCast
var _visual_start_y := 0.0
var _leap_distance := 0.0


func enter(_previous: StringName) -> void:
	_action = unit.planned_action
	if _action == null:
		machine.transition_to(&"idle")
		return
	var cast_target := unit.action_target(_action)
	var has_point := unit.planned_has_point and _action.target_mode == CombatActionDefinition.TargetMode.POINT
	var reason := ActionActivation.reason(unit, _action, cast_target, unit.planned_direction, unit.planned_point, has_point)
	if not reason.is_empty():
		machine.transition_to(&"idle")
		return
	var plan := ActionPlan.create(_action, cast_target, unit.planned_direction, unit.planned_point, has_point)
	if _action.movement_kind() == ActionMovementDefinition.Kind.TELEPORT:
		if not unit.has_live_target() or not unit.is_target_in_action_range(_action, 0.0) or unit.distance_to_target() < _action.min_range:
			machine.transition_to(&"idle")
			return

	_cast = ActionCast.create(plan)
	if _action.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT:
		_cast.point = unit.battle.clamp_unit_position(_cast.point)
		_leap_distance = unit.global_position.distance_to(_cast.point)
	unit.current_cast = _cast
	unit.spend_mana(_action)
	unit.begin_action_effects()
	if _action.movement_kind() == ActionMovementDefinition.Kind.TELEPORT:
		var departure: Vector2 = unit.global_position
		var approach: Vector2 = (_cast.target.global_position - departure).normalized()
		if approach.length_squared() < 0.0001:
			approach = Vector2(float(unit.facing), 0.0)
		var gap: float = _cast.target.body_radius + unit.body_radius + _action.movement_gap()
		unit.position = unit.battle.clamp_unit_position(_cast.target.global_position - approach * gap)
		unit.battle.spawn_hit_spark(departure, Color("#c264e8"), 1.6)
		unit.battle.spawn_hit_spark(unit.get_hit_point(), Color("#c264e8"), 1.8)
	var direction := _cast.direction
	if _action.movement_kind() == ActionMovementDefinition.Kind.TELEPORT:
		direction = (_cast.target.global_position - unit.global_position).normalized()
	elif direction.length_squared() < 0.0001:
		if _cast.target != null and is_instance_valid(_cast.target) and _cast.target.alive:
			direction = (_cast.target.global_position - unit.global_position).normalized()
		else:
			direction = Vector2(float(unit.facing), 0.0)
	_cast.direction = direction.normalized()
	unit.planned_direction = _cast.direction
	if _action.movement_kind() == ActionMovementDefinition.Kind.CHARGE and unit.has_live_target():
		_cast.charge_destination = _cast.target.global_position
	unit.face_direction(_cast.direction.x)
	unit.visual.speed_scale = maxf(_action.animation_speed, 0.05)
	_visual_start_y = unit.visual.position.y
	unit.play_animation(_action.animation, true)

	var frames := 1
	var fps := 10.0
	if unit.definition.sprite_frames != null and unit.definition.sprite_frames.has_animation(_action.animation):
		frames = unit.definition.sprite_frames.get_frame_count(_action.animation)
		fps = unit.definition.sprite_frames.get_animation_speed(_action.animation)
	_cast.duration = maxf(
		float(frames) / maxf(fps * unit.visual.speed_scale, 0.01),
		_action.action_duration
	)
	if _action.movement_kind() == ActionMovementDefinition.Kind.CHARGE and _action.movement_speed() > 0.0:
		_cast.duration = maxf(_cast.duration, unit.global_position.distance_to(_cast.charge_destination) / _action.movement_speed())
	elif _action.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT and _action.movement_speed() > 0.0:
		var speed_factor := maxf(unit.status_controller.modify_stat(&"move_speed", 1.0), 0.05)
		_cast.duration = maxf(_cast.duration, unit.global_position.distance_to(_cast.point) / (_action.movement_speed() * speed_factor) + 0.12)
	# 同一帧可能有多个效果（伤害 → 眩晕 → 击退）。Godot 的 sort_custom 不是稳定排序，
	# 这里用原始下标做第二排序键，保证数据里“先伤害、后状态”的顺序不会被交换。
	var ordered: Array = []
	for effect_index in _action.effects.size():
		ordered.append([_action.effects[effect_index], effect_index])
	ordered.sort_custom(func(a: Array, b: Array) -> bool:
		var a_frame := int(a[0].trigger_frame)
		var b_frame := int(b[0].trigger_frame)
		if a_frame != b_frame:
			return a_frame < b_frame
		return int(a[1]) < int(b[1])
	)
	for entry in ordered:
		_cast.effects.append(entry[0] as ActionEffectDefinition)
	unit.start_action_cooldown(_action)
	if unit.battle != null and unit.battle.has_method("register_action_cast"):
		unit.battle.register_action_cast(unit, _action)


func update(delta: float) -> void:
	if not unit.alive or _cast == null:
		return
	_cast.elapsed += delta
	if _action.movement_kind() == ActionMovementDefinition.Kind.CHARGE and _action.movement_speed() > 0.0:
		var previous := unit.global_position
		var remaining := _cast.charge_destination - previous
		if remaining.length_squared() > 0.01:
			unit.advance_step(remaining.normalized(), minf(_action.movement_speed() * delta, remaining.length()) / maxf(delta, 0.0001), delta)
		_charge_hit_segment(previous, unit.global_position)
	elif _action.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT and _action.movement_speed() > 0.0:
		var remaining := _cast.point - unit.global_position
		if remaining.length_squared() > 1.0:
			unit.advance_step(remaining.normalized(), minf(_action.movement_speed() * delta, remaining.length()) / maxf(delta, 0.0001), delta)
		if _action.movement.leap_height > 0.0:
			var travel_ratio := 1.0 - clampf(unit.global_position.distance_to(_cast.point) / maxf(_leap_distance, 1.0), 0.0, 1.0)
			unit.visual.position.y = _visual_start_y - sin(travel_ratio * PI) * _action.movement.leap_height
	elif _action.movement_kind() == ActionMovementDefinition.Kind.ADVANCE and _action.movement_speed() > 0.0:
		var step_distance := _action.movement_speed() * delta
		if _action.movement_distance() > 0.0:
			step_distance = minf(step_distance, maxf(0.0, _action.movement_distance() - _cast.advanced_distance))
		if step_distance > 0.0:
			var before := unit.global_position
			unit.advance_step(_cast.direction, step_distance / maxf(delta, 0.0001), delta)
			_cast.advanced_distance += before.distance_to(unit.global_position)

	var fps := 10.0
	if unit.definition.sprite_frames != null and unit.definition.sprite_frames.has_animation(_action.animation):
		fps = unit.definition.sprite_frames.get_animation_speed(_action.animation)
	while _cast.next_effect < _cast.effects.size():
		var effect := _cast.effects[_cast.next_effect]
		var trigger_time := float(maxi(effect.trigger_frame, 0)) / maxf(fps * unit.visual.speed_scale, 0.01)
		if trigger_time > _cast.elapsed:
			break
		if _action.movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT \
				and unit.global_position.distance_to(_cast.point) > 18.0 \
				and _cast.elapsed < _cast.duration + 0.4:
			break
		if not (_action.movement_kind() == ActionMovementDefinition.Kind.CHARGE and effect.kind == ActionEffectDefinition.Kind.DAMAGE):
			unit.resolve_action_effect(_action, effect)
		_cast.next_effect += 1

	if _cast.elapsed >= _cast.duration + 0.04 \
			and (_cast.next_effect >= _cast.effects.size() or _cast.elapsed >= _cast.duration + 0.4):
		unit.visual.speed_scale = 1.0
		machine.transition_to(&"idle")


func _charge_hit_segment(start: Vector2, finish: Vector2) -> void:
	if unit.battle == null:
		return
	var segment := finish - start
	var length_sq := segment.length_squared()
	for effect in _cast.effects:
		if effect.kind != ActionEffectDefinition.Kind.DAMAGE:
			continue
		for victim in unit.battle.living_units():
			if victim.team == unit.team or _cast.charge_hits.has(victim.get_instance_id()):
				continue
			var ratio := clampf((victim.global_position - start).dot(segment) / maxf(length_sq, 0.0001), 0.0, 1.0)
			var nearest := start + segment * ratio
			if victim.global_position.distance_to(nearest) <= effect.width * 0.5 + victim.body_radius:
				_cast.charge_hits[victim.get_instance_id()] = true
				unit.hit_by_action(victim, effect)
				if victim.alive:
					victim.apply_knockback(start, effect.knockback)


func exit() -> void:
	unit.visual.speed_scale = 1.0
	unit.visual.position.y = _visual_start_y
	unit.current_cast = null
	_cast = null
