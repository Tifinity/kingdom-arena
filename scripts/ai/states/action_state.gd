class_name UnitActionState
extends UnitState

## 统一的行动状态：执行 Brain 选出的 ActionPlan 中的 CombatActionDefinition。
## 普攻、技能、未来的护盾/突进都走这里；状态机不区分 Attack 和 Skill。

var _action: CombatActionDefinition
var _effects: Array[ActionEffectDefinition] = []
var _elapsed := 0.0
var _duration := 0.4
var _next_effect := 0
var _direction := Vector2.RIGHT
var _charge_destination := Vector2.ZERO
var _charge_hits: Dictionary = {}
var _advanced_distance := 0.0


func enter(_previous: StringName) -> void:
	_action = unit.planned_action
	_effects.clear()
	_elapsed = 0.0
	_next_effect = 0
	_charge_hits.clear()
	_advanced_distance = 0.0
	if _action == null:
		machine.transition_to(&"idle")
		return
	# 被硬控期间即使是旧计划也不能开始新动作。
	if not unit.can_act():
		machine.transition_to(&"hurt", true)
		return
	if _action.category != CombatActionDefinition.Category.BASIC and not unit.can_use_skill():
		machine.transition_to(&"idle")
		return
	# 防御性保护：同一个动作在冷却中绝不允许重复进入，避免一次技能释放两次。
	if unit.action_cooldown(_action) > 0.001:
		machine.transition_to(&"idle")
		return
	if not unit.has_mana(_action):
		machine.transition_to(&"idle")
		return
	if _action.teleport_to_target:
		if not unit.has_live_target() or not unit.is_target_in_action_range(_action, 0.0) or unit.distance_to_target() < _action.min_range:
			machine.transition_to(&"idle")
			return

	unit.spend_mana(_action)
	unit.begin_action_effects()
	if _action.teleport_to_target:
		var departure: Vector2 = unit.global_position
		var approach: Vector2 = (unit.target.global_position - departure).normalized()
		if approach.length_squared() < 0.0001:
			approach = Vector2(float(unit.facing), 0.0)
		var gap: float = unit.target.body_radius + unit.body_radius + _action.teleport_gap
		unit.position = unit.battle.clamp_unit_position(unit.target.global_position - approach * gap)
		unit.battle.spawn_hit_spark(departure, Color("#c264e8"), 1.6)
		unit.battle.spawn_hit_spark(unit.get_hit_point(), Color("#c264e8"), 1.8)
	_direction = unit.planned_direction
	if _action.teleport_to_target:
		_direction = (unit.target.global_position - unit.global_position).normalized()
	elif _direction.length_squared() < 0.0001:
		if unit.has_live_target():
			_direction = (unit.target.global_position - unit.global_position).normalized()
		else:
			_direction = Vector2(float(unit.facing), 0.0)
	_direction = _direction.normalized()
	unit.planned_direction = _direction
	if _action.charge_to_farthest and unit.has_live_target():
		_charge_destination = unit.target.global_position
	unit.face_direction(_direction.x)
	unit.visual.speed_scale = maxf(_action.animation_speed, 0.05)
	unit.play_animation(_action.animation, true)

	var frames := 1
	var fps := 10.0
	if unit.definition.sprite_frames != null and unit.definition.sprite_frames.has_animation(_action.animation):
		frames = unit.definition.sprite_frames.get_frame_count(_action.animation)
		fps = unit.definition.sprite_frames.get_animation_speed(_action.animation)
	_duration = maxf(
		float(frames) / maxf(fps * unit.visual.speed_scale, 0.01),
		_action.action_duration
	)
	if _action.charge_to_farthest and _action.charge_speed > 0.0:
		_duration = maxf(_duration, unit.global_position.distance_to(_charge_destination) / _action.charge_speed)
	_effects.clear()
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
		_effects.append(entry[0] as ActionEffectDefinition)
	unit.start_action_cooldown(_action)
	if unit.battle != null and unit.battle.has_method("register_action_cast"):
		unit.battle.register_action_cast(unit, _action)


func update(delta: float) -> void:
	if not unit.alive or _action == null:
		return
	_elapsed += delta
	if _action.charge_to_farthest and _action.charge_speed > 0.0:
		var previous := unit.global_position
		var remaining := _charge_destination - previous
		if remaining.length_squared() > 0.01:
			unit.advance_step(remaining.normalized(), minf(_action.charge_speed * delta, remaining.length()) / maxf(delta, 0.0001), delta)
		_charge_hit_segment(previous, unit.global_position)
	elif _action.advance_speed > 0.0:
		var step_distance := _action.advance_speed * delta
		if _action.advance_distance > 0.0:
			step_distance = minf(step_distance, maxf(0.0, _action.advance_distance - _advanced_distance))
		if step_distance > 0.0:
			var before := unit.global_position
			unit.advance_step(_direction, step_distance / maxf(delta, 0.0001), delta)
			_advanced_distance += before.distance_to(unit.global_position)

	var fps := 10.0
	if unit.definition.sprite_frames != null and unit.definition.sprite_frames.has_animation(_action.animation):
		fps = unit.definition.sprite_frames.get_animation_speed(_action.animation)
	while _next_effect < _effects.size():
		var effect := _effects[_next_effect]
		var trigger_time := float(maxi(effect.trigger_frame, 0)) / maxf(fps * unit.visual.speed_scale, 0.01)
		if trigger_time > _elapsed:
			break
		if not (_action.charge_to_farthest and effect.kind == ActionEffectDefinition.Kind.DAMAGE):
			unit.resolve_action_effect(_action, effect)
		_next_effect += 1

	if _elapsed >= _duration + 0.04:
		unit.visual.speed_scale = 1.0
		machine.transition_to(&"idle")


func _charge_hit_segment(start: Vector2, finish: Vector2) -> void:
	if unit.battle == null:
		return
	var segment := finish - start
	var length_sq := segment.length_squared()
	for effect in _effects:
		if effect.kind != ActionEffectDefinition.Kind.DAMAGE:
			continue
		for victim in unit.battle.living_units():
			if victim.team == unit.team or _charge_hits.has(victim.get_instance_id()):
				continue
			var ratio := clampf((victim.global_position - start).dot(segment) / maxf(length_sq, 0.0001), 0.0, 1.0)
			var nearest := start + segment * ratio
			if victim.global_position.distance_to(nearest) <= effect.width * 0.5 + victim.body_radius:
				_charge_hits[victim.get_instance_id()] = true
				unit.hit_by_action(victim, _action, effect)
				if victim.alive:
					victim.apply_knockback(start, effect.knockback)


func exit() -> void:
	unit.visual.speed_scale = 1.0
