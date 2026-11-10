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
var guard_time := 0.0
var guard_blocked_hit := false
var guard_reward_shield_ratio := 0.0
var guard_reward_shield_duration := 0.0
var shield := 0.0
var shield_time := 0.0
var summoned := false
var last_heal_amount := 0.0
## 兼容旧测试/UI 的只读视图；真实状态数据在 StatusController 的 StatusInstance 里。
var stun_time: float:
	get:
		return status_controller.remaining(&"stun") if status_controller != null else 0.0
var slow_time: float:
	get:
		return status_controller.remaining(&"slow") if status_controller != null else 0.0
var slow_factor: float:
	get:
		return status_controller.modify_stat(&"move_speed", 1.0) if status_controller != null else 1.0
var bleed_time: float:
	get:
		return status_controller.remaining(&"bleed") if status_controller != null else 0.0
var burn_time: float:
	get:
		return status_controller.remaining(&"burn") if status_controller != null else 0.0
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
var planned_target: Unit
var planned_direction := Vector2.ZERO
var planned_point := Vector2.ZERO
var planned_has_point := false
var current_cast: ActionCast
var action_cooldowns: Dictionary = {}
var is_selected := false
var initialized := false
var preview_mode := false

var intent: int = 0
var intent_reason := ""
var last_damage_source: Unit

var _flash_left := 0.0
var _current_animation: StringName = &""

var shadow: Sprite2D
var team_ring: UnitTeamRing
var selection_ring: UnitSelectionRing
var visual: AnimatedSprite2D
var health_bar: UnitHealthBar
@onready var visual_host: Node2D = $VisualHost
@onready var status_controller: UnitStatusController = $StatusController
@onready var brain: UnitBrain = $Brain
@onready var state_machine: UnitStateMachine = $StateMachine

## 兼容旧测试/表现代码；眩晕 VFX 现在由 StatusController 根据 StatusDefinition 创建。
var stun_fx: StunStars:
	get:
		return status_controller.get_vfx(&"stun") as StunStars if status_controller != null else null


func setup(p_battle: Node, p_team: int, p_slot: int, p_definition: UnitDefinition) -> void:
	battle = p_battle
	team = p_team
	slot = p_slot
	definition = p_definition
	accent_color = p_definition.accent_color

	max_hp = p_definition.max_hp
	hp = max_hp
	shield = 0.0
	shield_time = 0.0
	guard_time = 0.0
	guard_blocked_hit = false
	guard_reward_shield_ratio = 0.0
	guard_reward_shield_duration = 0.0
	current_cast = null
	planned_target = null
	planned_point = Vector2.ZERO
	planned_has_point = false
	max_mana = p_definition.max_mana
	mana = clampf(p_definition.starting_mana, 0.0, max_mana)
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

	var visual_scene: PackedScene = p_definition.visual_scene
	if visual_scene == null:
		push_warning("UnitDefinition %s 没有 visual_scene，使用骑士视觉场景回退" % p_definition.unit_id)
		visual_scene = load("res://scenes/units/knight_visual.tscn")
	var visual_root := visual_scene.instantiate()
	visual_host.add_child(visual_root)
	visual = visual_root.get_node("Body")
	shadow = visual_root.get_node("Shadow")
	team_ring = visual_root.get_node("TeamRing")
	selection_ring = visual_root.get_node("SelectionRing")
	health_bar = visual_root.get_node("HealthBar")

	visual.flip_h = team == 1
	visual.speed_scale = 1.0

	team_ring.setup(GameState.team_color(team), p_definition.body_radius * 0.9)
	selection_ring.setup(p_definition.body_radius * 1.35)
	selection_ring.set_combat_ranges(attack_range, _max_action_range())
	selection_ring.visible = false

	health_bar.setup(p_definition.body_radius * 1.65, GameState.team_color(team))
	health_bar.set_ratio(1.0)
	health_bar.set_shield_ratio(0.0)
	status_controller.setup(self)
	brain.setup(self)
	state_machine.setup(self)
	if p_definition.training_dummy:
		# 训练靶没有生命条和 AI；仍保留受击闪烁与状态表现，方便观察技能。
		health_bar.hide()
		team_ring.setup(Color("#d8b877"), p_definition.body_radius * 0.9)
		brain.enabled = false
	initialized = true


func is_training_dummy() -> bool:
	return definition != null and definition.training_dummy


## 调试用：不挂 Battle，只把一名英雄的资源和场景初始化好，停在 idle。
## Hero Lab / 单英雄场景可以用它手动预览任意动画，不经过 AI 和状态机。
func setup_preview(p_definition: UnitDefinition) -> void:
	setup(null, 0, 0, p_definition)
	preview_mode = true
	brain.enabled = false
	state_machine.set_physics_process(false)
	visual.speed_scale = 1.0
	play_animation(&"idle", true)


func on_battle_started() -> void:
	if not alive or definition == null or definition.passive == null:
		return
	for status in definition.passive.battle_start_statuses:
		if status != null:
			status_controller.apply(status, self)


func current_attack_damage() -> float:
	return status_controller.modify_stat(&"attack_damage", attack_damage) if status_controller != null else attack_damage


func current_armor() -> float:
	return clampf(status_controller.modify_stat(&"armor", armor), 0.0, 0.8) if status_controller != null else armor


## 攻速会受 buff/debuff 的 attack_speed 乘区影响；基础普攻冷却使用当前值。
func current_attack_speed() -> float:
	var speed := 1.0 / maxf(attack_interval, 0.001)
	if status_controller != null:
		speed = status_controller.modify_stat(&"attack_speed", speed)
	return maxf(speed, 0.05)


func current_attack_interval() -> float:
	return 1.0 / current_attack_speed()


func play_preview_animation(animation: StringName) -> bool:
	if not preview_mode:
		return false
	visual.speed_scale = 1.0
	_current_animation = &""
	play_animation(animation, true)
	return _current_animation == animation


## 召唤物出场：先播放自身 summon 动画，再接入正常 Brain/FSM。
func play_summon_intro() -> void:
	if not alive:
		return
	brain.enabled = false
	state_machine.set_physics_process(false)
	visual.speed_scale = 1.0
	play_animation(&"summon", true)
	var duration := _measure_animation(&"summon", 0.45)
	await get_tree().create_timer(maxf(duration, 0.65) + 0.1, false).timeout
	if not alive or not is_inside_tree():
		return
	state_machine.set_physics_process(true)
	brain.enabled = true
	state_machine.transition_to(&"idle", true)


func _process(delta: float) -> void:
	if not alive:
		return
	if _flash_left > 0.0:
		_flash_left = maxf(0.0, _flash_left - delta)
		if _flash_left > 0.0:
			visual.modulate = Color(1.0, 0.58, 0.58, 1.0)
		elif guard_time > 0.0:
			visual.modulate = Color(1.0, 0.88, 0.52, 1.0)
		elif shield > 0.0:
			visual.modulate = Color(0.72, 0.92, 1.0, 1.0)
		elif status_controller.has_status(&"burn"):
			visual.modulate = Color(1.0, 0.65, 0.35, 1.0)
		else:
			visual.modulate = Color.WHITE
	elif guard_time > 0.0:
		visual.modulate = Color(1.0, 0.88, 0.52, 1.0)
	elif shield > 0.0:
		visual.modulate = Color(0.72, 0.92, 1.0, 1.0)
	elif status_controller.has_status(&"burn"):
		visual.modulate = Color(1.0, 0.65, 0.35, 1.0)
	else:
		visual.modulate = Color.WHITE


func _physics_process(delta: float) -> void:
	if not initialized or not alive:
		return
	for key in action_cooldowns.keys():
		action_cooldowns[key] = maxf(0.0, float(action_cooldowns[key]) - delta)
	mana = minf(max_mana, mana + mana_regen * delta)
	if guard_time > 0.0:
		guard_time = maxf(0.0, guard_time - delta)
		if guard_time <= 0.0:
			if guard_blocked_hit:
				apply_shield(max_hp * guard_reward_shield_ratio, guard_reward_shield_duration, maxf(max_hp, shield))
			guard_blocked_hit = false
			guard_reward_shield_ratio = 0.0
			guard_reward_shield_duration = 0.0
	if shield_time > 0.0:
		shield_time = maxf(0.0, shield_time - delta)
		if shield_time <= 0.0:
			shield = 0.0
			health_bar.set_shield_ratio(0.0)


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
	if definition != null and definition.behavior_profile != null and definition.behavior_profile.movement != null:
		return definition.behavior_profile.movement.desired_position(self)
	if not has_live_target():
		return global_position
	var stop := maxf(target_reach(-18.0), 54.0)
	var lateral_span := minf(50.0, stop * 0.36)
	var lateral := (2.0 - float(slot)) / 2.0 * lateral_span
	var forward := sqrt(maxf(stop * stop - lateral * lateral, 0.0)) * 0.92
	var side := -1.0 if team == 0 else 1.0
	return battle.clamp_unit_position(target.global_position + Vector2(side * forward, lateral))


func movement_goal() -> Vector2:
	return desired_combat_position()


func kite_stop_distance() -> float:
	var ratio := 0.72
	if definition != null and definition.behavior_profile != null and definition.behavior_profile.movement != null:
		ratio = definition.behavior_profile.movement.get_kite_stop_ratio()
	return attack_range * ratio


const AOE_CAST_BUFFER := 0.88


## 扇形/矩形/自身圆形等以自身为原点的 AOE，实际命中半径由效果形状决定。
func action_aoe_reach(action: CombatActionDefinition) -> float:
	if action == null:
		return 0.0
	var reach := 0.0
	for effect in action.effects:
		if effect.kind != ActionEffectDefinition.Kind.DAMAGE:
			continue
		if effect.shape == ActionEffectDefinition.Shape.CONE:
			reach = maxf(reach, effect.radius)
		elif effect.shape == ActionEffectDefinition.Shape.RECT:
			reach = maxf(reach, effect.length)
	return reach


func is_target_in_action_range(action: CombatActionDefinition, extra := 0.0, check_min_range := true) -> bool:
	if action == null or not has_live_target():
		return false
	if check_min_range and distance_to_target() < action.min_range:
		return false
	var aoe_reach := action_aoe_reach(action)
	if aoe_reach > 0.0:
		# AOE 选择距离必须和伤害形状一致，并留 12% 施法缓冲。
		var reach := (aoe_reach + target.body_radius + extra) * AOE_CAST_BUFFER
		return distance_to_target() <= reach
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


## 战斗/Hero Lab 调试：把数值直接应用到当前单位，并同步基础攻击 Action/UI。
func apply_debug_stats(stats: Dictionary) -> void:
	if not alive:
		return
	var old_max_hp := max_hp
	var old_range := attack_range
	var old_ratio := hp / max_hp if max_hp > 0.0 else 1.0
	if stats.has("max_hp"):
		max_hp = maxf(1.0, float(stats["max_hp"]))
		hp = clampf(max_hp * old_ratio, 1.0, max_hp)
		if battle != null and battle.has_method("team_max_hp_total"):
			battle.team_max_hp_total[team] += max_hp - old_max_hp
	if stats.has("attack_damage"):
		attack_damage = maxf(1.0, float(stats["attack_damage"]))
	if stats.has("attack_speed"):
		attack_interval = 1.0 / clampf(float(stats["attack_speed"]), 0.05, 20.0)
	if stats.has("attack_range"):
		attack_range = clampf(float(stats["attack_range"]), 10.0, 2000.0)
	if stats.has("armor"):
		armor = clampf(float(stats["armor"]), 0.0, 0.8)
	if stats.has("move_speed"):
		move_speed = clampf(float(stats["move_speed"]), 10.0, 800.0)
	if stats.has("mana_regen"):
		mana_regen = clampf(float(stats["mana_regen"]), 0.0, 100.0)
	if stats.has("max_mana"):
		max_mana = maxf(0.0, float(stats["max_mana"]))
		mana = minf(mana, max_mana)
	for index in actions.size():
		var action := actions[index]
		if action == null or action.category != CombatActionDefinition.Category.BASIC:
			continue
		var copy: CombatActionDefinition = action.duplicate()
		copy.cooldown = attack_interval
		if is_equal_approx(action.action_range, old_range):
			copy.action_range = attack_range
		actions[index] = copy
		action_cooldowns[copy.action_id] = 0.0
	health_bar.set_ratio(hp / max_hp)
	selection_ring.set_combat_ranges(attack_range, _max_action_range())


func action_cooldown(action: CombatActionDefinition) -> float:
	if action == null:
		return 0.0
	return float(action_cooldowns.get(action.action_id, 0.0))


func start_action_cooldown(action: CombatActionDefinition) -> void:
	if action == null:
		return
	var cooldown := action.cooldown
	if action.category == CombatActionDefinition.Category.BASIC:
		cooldown = current_attack_interval()
	action_cooldowns[action.action_id] = maxf(cooldown, 0.0)


func current_action_cooldown() -> float:
	if planned_action != null:
		return action_cooldown(planned_action)
	if not actions.is_empty():
		return action_cooldown(actions[0])
	return 0.0


func can_execute_planned_action() -> bool:
	var cast_target := action_target(planned_action)
	return ActionActivation.reason(self, planned_action, cast_target, planned_direction, planned_point, planned_has_point).is_empty()


## HUD 和动作入口统一取有效目标，避免把已释放的 Unit 传给类型化参数。
func action_target(action: CombatActionDefinition) -> Unit:
	if action == null:
		return null
	if action.target_mode == CombatActionDefinition.TargetMode.SELF:
		return self
	var candidate: Variant = planned_target if action.target_mode == CombatActionDefinition.TargetMode.ALLY else target
	if not is_instance_valid(candidate) or not (candidate is Unit):
		return null
	return candidate as Unit


func battle_active() -> bool:
	return battle != null and battle.battle_active


func move_step(direction: Vector2, delta: float) -> void:
	if direction.length_squared() < 0.0001 or not can_move() or is_training_dummy():
		return
	var speed := status_controller.modify_stat(&"move_speed", move_speed)
	position += direction.normalized() * speed * delta
	position = battle.clamp_unit_position(position)


func advance_step(direction: Vector2, speed: float, delta: float) -> void:
	if direction.length_squared() < 0.0001 or speed <= 0.0 or not can_move() or is_training_dummy():
		return
	var factor := status_controller.modify_stat(&"move_speed", 1.0)
	position += direction.normalized() * speed * factor * delta
	if battle != null:
		position = battle.clamp_unit_position(position)


func is_stunned() -> bool:
	return status_controller != null and status_controller.has_status(&"stun")


func can_move() -> bool:
	return status_controller == null or status_controller.can_move()


func can_act() -> bool:
	return status_controller == null or status_controller.can_act()


func can_use_skill() -> bool:
	return status_controller == null or status_controller.can_use_skill()


## 控制类状态施加时调用：打断当前动作并进入受击姿态。
func interrupt_current_action() -> void:
	if not alive or state_machine == null or state_machine.current_name == &"death":
		return
	if state_machine.current_name == &"hurt":
		play_animation(&"hurt", true)
	else:
		state_machine.transition_to(&"hurt", true)


func is_charging() -> bool:
	return (state_machine != null and state_machine.current_name == &"action"
		and planned_action != null
		and planned_action.movement_kind() in [ActionMovementDefinition.Kind.CHARGE, ActionMovementDefinition.Kind.ADVANCE, ActionMovementDefinition.Kind.DASH_TO_POINT])


func begin_action_effects() -> void:
	if current_cast != null:
		current_cast.hit_targets.clear()


## 记录一次实际造成伤害的命中；技能命中会为“热诚决斗”类被动叠一层。
## DoT 的周期伤害不经过这里，因此不会叠被动。
func register_damage_hit(victim: Unit, is_skill := false) -> void:
	if not alive or not is_skill or victim == null or not is_instance_valid(victim):
		return
	var passive: PassiveDefinition = definition.passive if definition != null else null
	if passive == null or passive.skill_hit_stacks_status == null or status_controller == null:
		return
	status_controller.apply(passive.skill_hit_stacks_status, self)


## 对动作伤害应用状态提供的伤害修正（例如满层热诚的固定额外伤害）。
func apply_status_damage_bonus(base_damage: float, is_basic := false) -> float:
	if status_controller == null:
		return base_damage
	return status_controller.modify_damage(base_damage, is_basic)


func _record_action_hit(victim: Unit) -> void:
	if current_cast != null:
		current_cast.record_hit(victim)


func heal(amount: float, healer: Unit = null) -> void:
	if not alive or amount <= 0.0:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	health_bar.set_ratio(hp / max_hp)
	if hp > before:
		battle.spawn_heal_text(get_hit_point(), hp - before)
		if healer != null:
			healer.last_heal_amount += hp - before


func apply_status(effect: ActionEffectDefinition, source: Unit) -> void:
	if not alive or effect == null or status_controller == null:
		return
	var definition := StatusCatalog.definition_for_effect(effect)
	if definition == null:
		push_warning("未找到状态定义: %s" % effect.status_id)
		return
	var duration := effect.status_duration if effect.status_duration > 0.0 else definition.duration
	var power := effect.status_power if effect.status_power > 0.0 else definition.base_power
	status_controller.apply(definition, source, {
		"duration": duration,
		"power": power,
		"stacks": effect.status_stacks,
	})


func apply_burn(duration: float, dps: float, source: Unit) -> void:
	if not alive or status_controller == null or duration <= 0.0 or dps <= 0.0:
		return
	var definition := StatusCatalog.get_definition(&"burn")
	if definition == null:
		return
	status_controller.apply(definition, source, {"duration": duration, "power": dps})


func hit_by_action(victim: Unit, effect: ActionEffectDefinition) -> void:
	if not is_instance_valid(victim) or not victim.alive:
		return
	var impact := victim.get_hit_point()
	var blocked := victim.is_guarding()
	var is_skill := current_cast != null and current_cast.action.category == CombatActionDefinition.Category.SKILL
	var damage := current_attack_damage() * maxf(effect.damage_ratio, 0.0)
	damage = apply_status_damage_bonus(damage, not is_skill)
	_record_action_hit(victim)
	victim.take_damage(damage, self, impact)
	register_damage_hit(victim, is_skill)
	ActionImpact.apply_on_hit(effect, self, victim, blocked)
	battle.spawn_hit_spark(impact, accent_color, 1.2)
	battle.action_hits += 1


func apply_knockback(origin: Vector2, distance: float) -> void:
	if distance <= 0.0 or is_training_dummy():
		return
	var dir := global_position - origin
	if dir.length_squared() < 0.0001:
		dir = Vector2(float(-facing), 0.0)
	position += dir.normalized() * distance
	if battle != null:
		position = battle.clamp_unit_position(position)


## 执行一个 ActionEffect。ActionState 在动作时间轴的对应帧调用。
func resolve_action_effect(action: CombatActionDefinition, effect: ActionEffectDefinition) -> void:
	if effect == null:
		return
	var damage := current_attack_damage() * maxf(effect.damage_ratio, 0.0)
	var cast_target: Unit = current_cast.target if current_cast != null else target
	if effect.behavior != null:
		effect.behavior.execute(self, current_cast, effect)
	else:
		_resolve_legacy_action_effect(action, effect, damage, cast_target)

	if effect.effect_scene != null and effect.kind != ActionEffectDefinition.Kind.VISUAL:
		_spawn_action_visual(effect)


func _resolve_legacy_action_effect(action: CombatActionDefinition, effect: ActionEffectDefinition, damage: float, cast_target: Unit) -> void:
	match effect.kind:
		ActionEffectDefinition.Kind.DAMAGE:
			_resolve_damage_effect(action, effect, damage)
		ActionEffectDefinition.Kind.PROJECTILE:
			if cast_target != null and is_instance_valid(cast_target) and cast_target.alive and is_target_in_action_range(action, 24.0, false):
				damage = apply_status_damage_bonus(damage, action.category == CombatActionDefinition.Category.BASIC)
				battle.spawn_projectile(self, cast_target, damage, effect.projectile_kind, accent_color, effect)
		ActionEffectDefinition.Kind.VISUAL:
			_spawn_action_visual(effect)
		ActionEffectDefinition.Kind.GUARD:
			apply_guard(effect.duration, effect.guard_reward_shield_ratio, effect.guard_reward_shield_duration)
		ActionEffectDefinition.Kind.SHIELD:
			apply_shield(max_hp * effect.shield_per_target_ratio * (current_cast.hit_targets.size() if current_cast != null else 0),
				effect.duration, max_hp * effect.shield_max_ratio)
		ActionEffectDefinition.Kind.HEAL:
			_resolve_heal_effect(effect)
		ActionEffectDefinition.Kind.STATUS:
			for victim in _effect_victims(effect):
				if effect.requires_action_hit and (current_cast == null or not current_cast.has_hit(victim)):
					continue
				victim.apply_status(effect, self)
				if victim.team != team:
					_record_action_hit(victim)
		ActionEffectDefinition.Kind.DISPLACE:
			for victim in _effect_victims(effect):
				victim.apply_knockback(global_position, effect.knockback)
		ActionEffectDefinition.Kind.SUMMON:
			if battle != null:
				battle.spawn_summons(self, effect.summon_unit_id, effect.summon_count, effect.effect_scene)
		_:
			push_warning("ActionEffect kind %d 尚未实现" % effect.kind)

func _resolve_damage_effect(action: CombatActionDefinition, effect: ActionEffectDefinition, damage: float) -> void:
	var cast_target: Unit = current_cast.target if current_cast != null else target
	if effect.shape == ActionEffectDefinition.Shape.SINGLE:
		if cast_target == null or not is_instance_valid(cast_target) or not cast_target.alive or not is_target_in_action_range(action, 24.0, false):
			return
		if (action.movement_kind() == ActionMovementDefinition.Kind.ADVANCE or action.movement_kind() == ActionMovementDefinition.Kind.TELEPORT) and distance_to_target() > target_reach(24.0):
			return
	var direction := current_cast.direction if current_cast != null else planned_direction
	var point := current_cast.point if current_cast != null else planned_point
	var victims := ActionTargetQuery.enemies(self, effect, cast_target, direction, point,
		current_cast != null and current_cast.has_point)
	if not victims.is_empty():
		damage = apply_status_damage_bonus(damage, action.category == CombatActionDefinition.Category.BASIC)
	for victim in victims:
		var impact := victim.get_hit_point()
		if effect.shape == ActionEffectDefinition.Shape.SINGLE:
			battle.spawn_slash(impact, accent_color, signf(victim.global_position.x - global_position.x))
		elif effect.shape == ActionEffectDefinition.Shape.CONE:
			battle.spawn_hit_spark(impact, Color(1.0, 0.55, 0.18), 1.4)
		elif effect.shape == ActionEffectDefinition.Shape.RECT:
			battle.spawn_hit_spark(impact, accent_color, 1.2)
		_record_action_hit(victim)
		var blocked := victim.is_guarding()
		victim.take_damage(damage, self, impact)
		register_damage_hit(victim, action.category == CombatActionDefinition.Category.SKILL)
		ActionImpact.apply_on_hit(effect, self, victim, blocked)
		if effect.shape == ActionEffectDefinition.Shape.SINGLE and victim.alive and effect.knockback > 0.0:
			victim.apply_knockback(global_position, effect.knockback)
		battle.action_hits += 1


func _effect_victims(effect: ActionEffectDefinition) -> Array[Unit]:
	var cast_target: Unit = current_cast.target if current_cast != null else target
	var direction := current_cast.direction if current_cast != null else planned_direction
	var point := current_cast.point if current_cast != null else planned_point
	if effect.shape == ActionEffectDefinition.Shape.SELF or (current_cast != null and current_cast.action.target_mode == CombatActionDefinition.TargetMode.ALLY):
		return ActionTargetQuery.allies(self, effect, cast_target, direction, point, current_cast.has_point)
	return ActionTargetQuery.enemies(self, effect, cast_target, direction, point,
		current_cast != null and current_cast.has_point)


func _resolve_heal_effect(effect: ActionEffectDefinition) -> void:
	if battle == null:
		return
	var amount := effect.heal_amount + current_attack_damage() * effect.heal_ratio
	var cast_target: Unit = self if current_cast == null or current_cast.action.target_mode == CombatActionDefinition.TargetMode.SELF else current_cast.target
	var point := current_cast.point if current_cast != null else planned_point
	var direction := current_cast.direction if current_cast != null else planned_direction
	for ally in ActionTargetQuery.allies(self, effect, cast_target, direction, point,
		current_cast != null and current_cast.has_point):
		ally.heal(amount, self)


func _spawn_action_visual(effect: ActionEffectDefinition) -> void:
	if effect.effect_scene == null or battle == null:
		return
	battle.spawn_action_effect(effect.effect_scene, self, effect)


func apply_guard(duration: float, reward_shield_ratio := 0.0, reward_shield_duration := 0.0) -> void:
	if not alive:
		return
	if guard_time <= 0.0:
		guard_blocked_hit = false
	guard_time = maxf(guard_time, duration)
	guard_reward_shield_ratio = reward_shield_ratio
	guard_reward_shield_duration = reward_shield_duration


func apply_shield(amount: float, duration: float, cap: float) -> void:
	if not alive or amount <= 0.0 or duration <= 0.0 or cap <= 0.0:
		return
	var before := shield
	shield = minf(shield + amount, maxf(cap, shield))
	shield_time = duration
	health_bar.set_shield_ratio(shield / max_hp)
	if battle != null and shield > before:
		battle.spawn_shield_text(get_hit_point(), shield - before)
		battle.spawn_hit_spark(get_hit_point(), Color("#59d9ff"), 1.8)


func is_guarding() -> bool:
	return guard_time > 0.0


func take_damage(raw_amount: float, source: Unit, hit_position: Variant = null, ignore_armor := false, ignore_shield := false) -> void:
	if not alive or raw_amount <= 0.0:
		return
	if is_training_dummy():
		# 稻草人只记录伤害与飘字，不扣血、不进硬直、不死亡；护甲与格挡照常显示。
		var recorded := raw_amount if ignore_armor else raw_amount * (1.0 - current_armor())
		if recorded <= 0.0:
			return
		_flash_left = 0.09
		visual.modulate = Color(1.0, 0.58, 0.58, 1.0)
		if battle != null:
			battle.on_damage_dealt(self, source, recorded)
		return
	if guard_time > 0.0:
		# 格挡期间完全免伤，也不进入受击硬直。
		guard_blocked_hit = true
		var block_at := get_hit_point() if hit_position == null else Vector2(hit_position)
		_flash_left = 0.09
		visual.modulate = Color(1.0, 0.88, 0.52, 1.0)
		battle.spawn_hit_spark(block_at, Color("#e7c46b"), 1.8)
		battle.spawn_block_text(block_at)
		return
	var amount := raw_amount if ignore_armor else raw_amount * (1.0 - current_armor())
	if shield > 0.0 and not ignore_shield:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		health_bar.set_shield_ratio(shield / max_hp)
		if shield <= 0.0:
			shield_time = 0.0
		if amount <= 0.0:
			battle.spawn_hit_spark(get_hit_point(), Color(0.35, 0.85, 1.0), 1.2)
			return
	hp = maxf(0.0, hp - amount)
	last_damage_source = source
	health_bar.set_ratio(hp / max_hp)
	_flash_left = 0.09
	visual.modulate = Color(1.0, 0.58, 0.58, 1.0)
	battle.on_damage_dealt(self, source, amount)

	if hp <= 0.0:
		die(source)
		return


func die(killer: Unit) -> void:
	if not alive or is_training_dummy():
		return
	alive = false
	hp = 0.0
	guard_time = 0.0
	shield = 0.0
	shield_time = 0.0
	health_bar.set_shield_ratio(0.0)
	if status_controller != null:
		status_controller.clear_all()
	target = null
	planned_target = null
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
	var visual_height := character_height * absf(visual.scale.y) if visual != null else character_height * definition.visual_scale
	return global_position + Vector2(0.0, -visual_height * 0.52)


func get_muzzle_point() -> Vector2:
	var visual_height := character_height * absf(visual.scale.y) if visual != null else character_height * definition.visual_scale
	return global_position + Vector2(
		float(facing) * body_radius * 0.72,
		-visual_height * 0.56
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
		if planned_action.target_mode == CombatActionDefinition.TargetMode.SELF:
			action_text = "%s → 自身（持续 %.1fs）" % [
				planned_action.display_name, planned_action.action_duration,
			]
		elif planned_action.target_mode == CombatActionDefinition.TargetMode.DIRECTION:
			action_text = "%s → 选定方向" % planned_action.display_name
		else:
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
		"guard": "%.1f" % guard_time,
		"shield": "%d" % roundi(shield),
		"shield_time": "%.1f" % shield_time,
		"stun": "%.1f" % stun_time,
		"slow": "%.1f" % slow_time,
		"bleed": "%.1f" % bleed_time,
		"statuses": status_controller.snapshot() if status_controller != null else [],
		"alive": alive,
	}
