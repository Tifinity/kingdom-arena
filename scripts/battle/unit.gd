class_name Unit
extends Node2D

## 战场上的英雄单位。
##
## 职责：承载静态数据与运行时数值、播放动画、执行攻击/移动、
## 接收伤害并驱动有限状态机。决策本身在 UnitBrain（OODA）里，
## 具体状态行为在 StateMachine 的子状态节点里。

signal died(unit: Unit, killer: Unit)

var battle: Node
var definition: UnitDefinition
var team := 0
var slot := 0

var max_hp := 100.0
var hp := 100.0
var max_mana := 100.0
var mana := 100.0
var mana_regen := 8.0
var attack_damage := 10.0
var attack_interval := 1.0
var attack_range := 80.0
var move_speed := 100.0
var armor := 0.0
var attack_windup := 0.3
var attack_anim_duration := 0.4
var body_radius := 30.0
var character_height := 24.0
var projectile_kind := 0
var attack_animation: StringName = &"attack_01"
var accent_color := Color.WHITE

var target: Unit
var alive := true
var facing := 1
var actions: Array[CombatActionDefinition] = []
var planned_action: CombatActionDefinition
var action_cooldowns: Dictionary = {}
var is_selected := false
var initialized := false
var preview_mode := false

var intent: int = 0
var intent_reason := ""
var last_damage_source: Unit

var _flash_left := 0.0
var _flinch_cooldown := 0.0
var _current_animation: StringName = &""

@onready var shadow: Sprite2D = $Shadow
@onready var team_ring: UnitTeamRing = $TeamRing
@onready var selection_ring: UnitSelectionRing = $SelectionRing
@onready var visual: AnimatedSprite2D = $Visual
@onready var health_bar: UnitHealthBar = $HealthBar
@onready var brain: UnitBrain = $Brain
@onready var state_machine: UnitStateMachine = $StateMachine


func setup(p_battle: Node, p_team: int, p_slot: int, p_definition: UnitDefinition) -> void:
	battle = p_battle
	team = p_team
	slot = p_slot
	definition = p_definition
	accent_color = p_definition.accent_color

	max_hp = p_definition.max_hp
	hp = max_hp
	max_mana = p_definition.max_mana
	mana = max_mana
	mana_regen = p_definition.mana_regen
	attack_damage = p_definition.attack_damage
	attack_interval = p_definition.attack_interval()
	attack_range = p_definition.attack_range
	move_speed = p_definition.move_speed
	armor = p_definition.armor
	attack_windup = p_definition.attack_windup
	body_radius = p_definition.body_radius
	character_height = p_definition.character_height
	projectile_kind = p_definition.projectile_kind
	attack_animation = p_definition.attack_animation
	attack_anim_duration = _measure_animation(attack_animation, 0.4)
	actions = p_definition.actions.duplicate()
	action_cooldowns.clear()
	for action in actions:
		if action != null:
			action_cooldowns[action.action_id] = 0.0

	visual.sprite_frames = p_definition.sprite_frames
	visual.scale = Vector2.ONE * p_definition.visual_scale
	visual.position = Vector2(0, -p_definition.foot_offset * p_definition.visual_scale)
	visual.flip_h = team == 1
	visual.speed_scale = 1.0

	shadow.scale = Vector2.ONE * (p_definition.body_radius / 80.0)
	shadow.position = Vector2(0, -1)

	team_ring.setup(GameState.team_color(team), p_definition.body_radius * 0.9)
	selection_ring.setup(p_definition.body_radius * 1.35)
	selection_ring.set_combat_ranges(attack_range, _max_action_range())
	selection_ring.visible = false

	health_bar.setup(p_definition.body_radius * 1.65, GameState.team_color(team))
	health_bar.position = Vector2(0, -character_height * p_definition.visual_scale - 15.0)
	health_bar.set_ratio(1.0)

	brain.setup(self)
	state_machine.setup(self)
	initialized = true


## 调试用：不挂 Battle，只把一名英雄的资源和场景初始化好，停在 idle。
## Hero Lab / 单英雄场景可以用它手动预览任意动画，不经过 AI 和状态机。
func setup_preview(p_definition: UnitDefinition) -> void:
	setup(null, 0, 0, p_definition)
	preview_mode = true
	brain.enabled = false
	state_machine.set_physics_process(false)
	visual.speed_scale = 1.0
	play_animation(&"idle", true)


func play_preview_animation(animation: StringName) -> bool:
	if not preview_mode:
		return false
	visual.speed_scale = 1.0
	_current_animation = &""
	play_animation(animation, true)
	return _current_animation == animation


func _process(delta: float) -> void:
	if _flash_left > 0.0 and alive:
		_flash_left = maxf(0.0, _flash_left - delta)
		if _flash_left > 0.0:
			visual.modulate = Color(1.0, 0.58, 0.58, 1.0)
		else:
			visual.modulate = Color.WHITE


func _physics_process(delta: float) -> void:
	if not initialized or not alive:
		return
	for key in action_cooldowns.keys():
		action_cooldowns[key] = maxf(0.0, float(action_cooldowns[key]) - delta)
	mana = minf(max_mana, mana + mana_regen * delta)
	_flinch_cooldown = maxf(0.0, _flinch_cooldown - delta)


func _measure_animation(animation: StringName, fallback: float) -> float:
	if definition == null or definition.sprite_frames == null:
		return fallback
	if not definition.sprite_frames.has_animation(animation):
		return fallback
	var count := definition.sprite_frames.get_frame_count(animation)
	var speed := definition.sprite_frames.get_animation_speed(animation)
	return float(count) / maxf(speed, 0.01)


func play_animation(animation: StringName, restart := false) -> void:
	if visual.sprite_frames == null:
		return
	var wanted := animation
	if not visual.sprite_frames.has_animation(wanted):
		wanted = &"idle"
		if not visual.sprite_frames.has_animation(wanted):
			return
	if _current_animation == wanted and not restart:
		return
	_current_animation = wanted
	visual.play(wanted)


func current_animation() -> StringName:
	return _current_animation


func face_direction(x: float) -> void:
	if absf(x) > 0.5:
		facing = 1 if x > 0.0 else -1
		visual.flip_h = facing < 0


func face_target() -> void:
	if has_live_target():
		face_direction(target.global_position.x - global_position.x)


func has_live_target() -> bool:
	return target != null and is_instance_valid(target) and target.alive


func distance_to_target() -> float:
	if not has_live_target():
		return INF
	return global_position.distance_to(target.global_position)


func target_reach(extra := 0.0) -> float:
	var target_radius := target.body_radius if has_live_target() else 0.0
	return attack_range + target_radius + body_radius * 0.35 + extra


func is_target_in_range(extra := 0.0) -> bool:
	if not has_live_target():
		return false
	return distance_to_target() <= target_reach(extra)


func desired_stop_distance() -> float:
	return maxf(target_reach(-12.0), 40.0)


## 每名英雄围绕目标占据不同的位置：同排英雄沿 Y 轴错开，
## 避免 5 个人全部挤在同一个攻击点上，也让血条和特效更易读。
func desired_combat_position() -> Vector2:
	if not has_live_target():
		return global_position
	var stop := maxf(target_reach(-18.0), 54.0)
	var lateral_span := minf(50.0, stop * 0.36)
	var lateral := (2.0 - float(slot)) / 2.0 * lateral_span
	var forward := sqrt(maxf(stop * stop - lateral * lateral, 0.0)) * 0.92
	var side := -1.0 if team == 0 else 1.0
	return battle.clamp_unit_position(target.global_position + Vector2(side * forward, lateral))


func is_target_in_action_range(action: CombatActionDefinition, extra := 0.0) -> bool:
	if action == null or not has_live_target():
		return false
	var reach := action.action_range + target.body_radius + body_radius * 0.35 + extra
	return distance_to_target() <= reach


func is_action_ready(action: CombatActionDefinition) -> bool:
	if action == null:
		return false
	return float(action_cooldowns.get(action.action_id, 0.0)) <= 0.0001


func has_mana(action: CombatActionDefinition) -> bool:
	if action == null:
		return true
	return mana + 0.001 >= action.mana_cost


func spend_mana(action: CombatActionDefinition) -> void:
	if action == null:
		return
	mana = maxf(0.0, mana - action.mana_cost)


func action_cooldown(action: CombatActionDefinition) -> float:
	if action == null:
		return 0.0
	return float(action_cooldowns.get(action.action_id, 0.0))


func start_action_cooldown(action: CombatActionDefinition) -> void:
	if action == null:
		return
	action_cooldowns[action.action_id] = maxf(action.cooldown, 0.0)


func current_action_cooldown() -> float:
	if planned_action != null:
		return action_cooldown(planned_action)
	if not actions.is_empty():
		return action_cooldown(actions[0])
	return 0.0


func can_execute_planned_action() -> bool:
	if planned_action == null or not alive or not has_live_target():
		return false
	return is_target_in_action_range(planned_action, 6.0)


func battle_active() -> bool:
	return battle != null and battle.battle_active


func move_step(direction: Vector2, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	position += direction.normalized() * move_speed * delta
	position = battle.clamp_unit_position(position)


## 执行一个 ActionEffect。ActionState 在动作时间轴的对应帧调用。
func resolve_action_effect(action: CombatActionDefinition, effect: ActionEffectDefinition) -> void:
	if effect == null:
		return
	var damage := attack_damage * maxf(effect.damage_ratio, 0.0)
	match effect.kind:
		ActionEffectDefinition.Kind.DAMAGE:
			_resolve_damage_effect(action, effect, damage)
		ActionEffectDefinition.Kind.PROJECTILE:
			if has_live_target() and is_target_in_action_range(action, 24.0):
				battle.spawn_projectile(self, target, damage, effect.projectile_kind, accent_color)
		ActionEffectDefinition.Kind.VISUAL:
			_spawn_action_visual(effect)
		_:
			push_warning("ActionEffect kind %d 尚未实现" % effect.kind)

	if effect.effect_scene != null and effect.kind != ActionEffectDefinition.Kind.VISUAL:
		_spawn_action_visual(effect)


func _resolve_damage_effect(action: CombatActionDefinition, effect: ActionEffectDefinition, damage: float) -> void:
	match effect.shape:
		ActionEffectDefinition.Shape.SINGLE:
			if not has_live_target() or not is_target_in_action_range(action, 24.0):
				return
			var impact := target.get_hit_point()
			battle.spawn_slash(impact, accent_color, signf(target.global_position.x - global_position.x))
			target.take_damage(damage, self, impact)
		ActionEffectDefinition.Shape.CONE:
			var victims: Array = battle.units_in_cone(
				self, Vector2(float(facing), 0.0), effect.radius, effect.half_angle
			)
			for victim in victims:
				victim.take_damage(damage, self, victim.get_hit_point())
				battle.spawn_hit_spark(victim.get_hit_point(), Color(1.0, 0.55, 0.18), 1.4)
		ActionEffectDefinition.Shape.CIRCLE:
			if not has_live_target():
				return
			var center := target.global_position
			for victim in battle.units_in_circle(self, center, effect.radius):
				victim.take_damage(damage, self, victim.get_hit_point())
		_:
			pass


func _spawn_action_visual(effect: ActionEffectDefinition) -> void:
	if effect.effect_scene == null or battle == null:
		return
	battle.spawn_action_effect(effect.effect_scene, self, effect)


func take_damage(raw_amount: float, source: Unit, hit_position: Variant = null) -> void:
	if not alive or raw_amount <= 0.0:
		return
	var amount := raw_amount * (1.0 - clampf(armor, 0.0, 0.8))
	hp = maxf(0.0, hp - amount)
	last_damage_source = source
	health_bar.set_ratio(hp / max_hp)
	_flash_left = 0.09
	visual.modulate = Color(1.0, 0.58, 0.58, 1.0)
	battle.on_damage_dealt(self, source, amount)

	if hp <= 0.0:
		die(source)
		return

	if _flinch_cooldown <= 0.0 and amount >= max_hp * 0.065:
		_flinch_cooldown = 1.05
		state_machine.transition_to(&"hurt", true)


func die(killer: Unit) -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	target = null
	brain.enabled = false
	brain.last_observe_text = "生命归零，已失去感知"
	brain.last_judge_text = "无法继续判断"
	brain.last_decide_text = "死亡：退出战场"
	brain.last_action_text = "播放死亡动画并等待淡出"
	health_bar.hide()
	team_ring.hide()
	selection_ring.hide()
	shadow.modulate = Color(1.0, 1.0, 1.0, 0.4)
	state_machine.transition_to(&"death", true)
	died.emit(self, killer)


func hp_ratio() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


func get_hit_point() -> Vector2:
	return global_position + Vector2(0.0, -character_height * definition.visual_scale * 0.52)


func get_muzzle_point() -> Vector2:
	return global_position + Vector2(
		float(facing) * body_radius * 0.72,
		-character_height * definition.visual_scale * 0.56
	)


func set_selected(value: bool) -> void:
	is_selected = value
	selection_ring.visible = value and alive


func set_range_overlay_visible(value: bool) -> void:
	if selection_ring == null:
		return
	selection_ring.show_combat_ranges = value
	selection_ring.queue_redraw()


func _max_action_range() -> float:
	var result := attack_range
	for action in actions:
		if action != null:
			result = maxf(result, action.action_range)
	return result


func ai_snapshot() -> Dictionary:
	var action_text := brain.last_action_text if brain != null else ""
	if state_machine != null and state_machine.current_name == &"action" and planned_action != null:
		action_text = "%s → %s（冷却 %.2fs）" % [
			planned_action.display_name,
			target.definition.display_name if has_live_target() else "无",
			current_action_cooldown(),
		]
	return {
		"name": definition.display_name if definition != null else "单位",
		"team": team,
		"state": state_machine.display_name() if state_machine != null else "待机",
		"state_key": String(state_machine.current_name) if state_machine != null else "idle",
		"intent": brain.intent_label() if brain != null else "待机",
		"observe": brain.last_observe_text if brain != null else "",
		"judge": brain.last_judge_text if brain != null else "",
		"decide": brain.last_decide_text if brain != null else "",
		"action": action_text,
		"action_name": planned_action.display_name if planned_action != null else "—",
		"target": target.definition.display_name if has_live_target() else "无",
		"hp": "%d / %d" % [roundi(hp), roundi(max_hp)],
		"mana": "%d / %d" % [roundi(mana), roundi(max_mana)],
		"attack_range": "%d" % roundi(attack_range),
		"skill_range": "%d" % roundi(_max_action_range()) if _max_action_range() > attack_range + 0.5 else "—",
		"cooldown": "%.2f" % current_action_cooldown(),
		"alive": alive,
	}
