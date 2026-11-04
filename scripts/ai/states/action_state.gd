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


func enter(_previous: StringName) -> void:
	_action = unit.planned_action
	_effects.clear()
	_elapsed = 0.0
	_next_effect = 0
	if _action == null:
		machine.transition_to(&"idle")
		return
	# 防御性保护：同一个动作在冷却中绝不允许重复进入，避免一次技能释放两次。
	if unit.action_cooldown(_action) > 0.001:
		machine.transition_to(&"idle")
		return
	if not unit.has_mana(_action):
		machine.transition_to(&"idle")
		return

	unit.spend_mana(_action)
	_direction = unit.planned_direction
	if _direction.length_squared() < 0.0001:
		if unit.has_live_target():
			_direction = (unit.target.global_position - unit.global_position).normalized()
		else:
			_direction = Vector2(float(unit.facing), 0.0)
	_direction = _direction.normalized()
	unit.planned_direction = _direction
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
	_effects = _action.effects.duplicate()
	_effects.sort_custom(func(a: ActionEffectDefinition, b: ActionEffectDefinition) -> bool:
		return a.trigger_frame < b.trigger_frame
	)
	unit.start_action_cooldown(_action)
	if unit.battle != null and unit.battle.has_method("register_action_cast"):
		unit.battle.register_action_cast(unit, _action)


func update(delta: float) -> void:
	if not unit.alive or _action == null:
		return
	_elapsed += delta
	if _action.advance_speed > 0.0:
		unit.advance_step(_direction, _action.advance_speed, delta)

	var fps := 10.0
	if unit.definition.sprite_frames != null and unit.definition.sprite_frames.has_animation(_action.animation):
		fps = unit.definition.sprite_frames.get_animation_speed(_action.animation)
	while _next_effect < _effects.size():
		var effect := _effects[_next_effect]
		var trigger_time := float(maxi(effect.trigger_frame, 0)) / maxf(fps * unit.visual.speed_scale, 0.01)
		if trigger_time > _elapsed:
			break
		unit.resolve_action_effect(_action, effect)
		_next_effect += 1

	if _elapsed >= _duration + 0.04:
		unit.visual.speed_scale = 1.0
		machine.transition_to(&"idle")


func exit() -> void:
	unit.visual.speed_scale = 1.0
