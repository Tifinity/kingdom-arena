class_name UnitBrain
extends Node

## OODA 行为大脑：观察（Observe）→ 判断（Orient/Judge）→ 决策（Decide）→ 行动（Act）。
##
## 大脑只负责“想”，不直接改动画或位置；它把目标与意图写给 Unit，
## 由 StateMachine 中当前状态节点负责“做”。这样 AI 与表现/动画解耦，
## 行动由 ActionPlan 选择，具体动画/效果由 UnitActionState 执行。

enum Intent { IDLE, ADVANCE, ACTION, KITE }

const THINK_INTERVAL := 0.16
const INTENT_LABELS := {
	Intent.IDLE: "待机",
	Intent.ADVANCE: "推进",
	Intent.ACTION: "行动",
	Intent.KITE: "拉开距离",
}

@export var enabled := true

var unit: Unit
var intent: int = Intent.IDLE
var intent_reason := ""
var target: Unit
var planned_action: CombatActionDefinition
var planned_direction := Vector2.ZERO
var planned_target_count := 0
var observation: Dictionary = {}
var judgment: Dictionary = {}

var last_observe_text := "尚未观察"
var last_judge_text := "尚未判断"
var last_decide_text := "尚未决策"
var last_action_text := "等待战斗开始"

var _think_left := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_unit: Unit) -> void:
	unit = p_unit
	_rng.randomize()
	_think_left = 0.0


func _physics_process(delta: float) -> void:
	if not enabled or unit == null or not unit.initialized or not unit.alive:
		return
	if not unit.battle_active():
		return
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = THINK_INTERVAL
	think()


func force_think() -> void:
	_think_left = 0.0
	if enabled and unit != null and unit.alive:
		think()


func think() -> void:
	if unit == null or unit.battle == null or not unit.alive:
		return
	# 动作/受击/死亡期间不再改写计划，避免 OODA 文本和实际执行的动作不一致。
	if unit.state_machine != null and unit.state_machine.current_name in [&"action", &"hurt", &"death"]:
		return
	if unit.is_stunned():
		return
	_observe()
	_judge()
	_decide()
	_act()


func intent_label() -> String:
	return INTENT_LABELS.get(intent, "待机")


# --- O：观察 ------------------------------------------------------------

func _observe() -> void:
	var enemies: Array = []
	var allies: Array = []
	var nearest: Unit = null
	var nearest_distance := INF
	var total_distance := 0.0
	var low_hp_enemy: Unit = null

	for other in unit.battle.living_units():
		if other == unit:
			continue
		if other.team == unit.team:
			allies.append(other)
			continue
		enemies.append(other)
		var distance := unit.global_position.distance_to(other.global_position)
		total_distance += distance
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = other
		if low_hp_enemy == null or other.hp_ratio() < low_hp_enemy.hp_ratio():
			low_hp_enemy = other

	observation = {
		"enemies": enemies,
		"allies": allies,
		"nearest": nearest,
		"nearest_distance": nearest_distance,
		"average_distance": total_distance / maxf(enemies.size(), 1.0),
		"low_hp_enemy": low_hp_enemy,
		"own_hp_ratio": unit.hp_ratio(),
	}

	if enemies.is_empty():
		last_observe_text = "视野内没有敌人"
	elif nearest != null:
		last_observe_text = "敌 %d 人 / 友 %d 人 · 最近 %s %.0fpx · 自身 %d%%" % [
			enemies.size(), allies.size(), nearest.definition.display_name,
			nearest_distance, roundi(unit.hp_ratio() * 100.0),
		]


# --- O：判断 ------------------------------------------------------------

func _judge() -> void:
	var enemies: Array = observation.get("enemies", [])
	if enemies.is_empty():
		target = null
		judgment = {"close_threats": 0, "threat": 0.0, "score": 0.0}
		last_judge_text = "没有可交战目标"
		return

	var best: Unit = null
	var best_score := -INF
	var close_threats := 0
	var threat_radius := maxf(unit.attack_range * 1.2, 190.0)

	for enemy in enemies:
		var distance: float = unit.global_position.distance_to(enemy.global_position)
		var score := _score_target(enemy, distance)
		if distance <= threat_radius:
			close_threats += 1
		if score > best_score:
			best_score = score
			best = enemy

	target = best
	var threat := clampf(float(close_threats) / 4.0 + (1.0 - unit.hp_ratio()) * 0.55, 0.0, 1.0)
	judgment = {
		"target": best,
		"score": best_score,
		"close_threats": close_threats,
		"threat": threat,
	}
	last_judge_text = "优先 %s · 评分 %.2f · 近身威胁 %d 人" % [
		best.definition.display_name if best != null else "无", best_score, close_threats,
	]


func random_score() -> float:
	return _rng.randf()


func _score_target(enemy: Unit, distance: float) -> float:
	if unit.definition.behavior_profile != null and unit.definition.behavior_profile.targeting != null:
		return unit.definition.behavior_profile.targeting.score_target(self, enemy, distance)
	# 距离、残血、输出威胁构成基础分；职业关系与当前目标粘性做修正。
	var score := 0.0
	score += (1.0 - clampf(distance / 1000.0, 0.0, 1.0)) * 0.50
	score += (1.0 - enemy.hp_ratio()) * 0.25
	score += clampf(enemy.definition.damage_per_second() / 140.0, 0.0, 1.0) * 0.12

	if unit.definition.role == "突袭" and enemy.definition.is_ranged():
		score += 0.18
	if unit.definition.is_ranged() and enemy.definition.role == "坦克":
		score -= 0.08
	if unit.has_live_target() and enemy == unit.target:
		score += 0.08
	score += _rng.randf() * 0.02
	return clampf(score, 0.0, 1.0)


func _should_kite() -> bool:
	if unit.definition.behavior_profile != null and unit.definition.behavior_profile.movement != null:
		return unit.definition.behavior_profile.movement.should_kite(unit)
	if not unit.definition.is_ranged() or not unit.has_live_target():
		return false
	return unit.distance_to_target() < unit.attack_range * 0.42


# --- D：决策 ------------------------------------------------------------

func _decide() -> void:
	intent = Intent.IDLE
	intent_reason = "等待战机"
	planned_action = null
	planned_direction = Vector2.ZERO
	planned_target_count = 0

	if target == null or not is_instance_valid(target) or not target.alive:
		target = null
		intent_reason = "没有可攻击目标"
		last_decide_text = "%s：%s" % [INTENT_LABELS[intent], intent_reason]
		return

	var plan := _select_action()
	if plan != null:
		planned_action = plan.action
		intent = Intent.ACTION
		intent_reason = "使用 %s（%s）" % [planned_action.display_name, planned_action.category_label()]
	elif _should_kite():
		intent = Intent.KITE
		intent_reason = "距离过近，后撤拉开射程"
	elif unit.is_target_in_range(6.0):
		intent_reason = "所有可用动作都在冷却，等待时机"
	else:
		intent = Intent.ADVANCE
		intent_reason = "向目标推进，等待动作就绪"

	last_decide_text = "%s：%s" % [INTENT_LABELS[intent], intent_reason]


## 决策层的核心：从该单位所有 Action 中选一个当前可用的、优先级最高的动作。
func _select_action() -> ActionPlan:
	var best_plan: ActionPlan = null
	var best_score := -INF
	var best_priority := -999
	# 决策阶段先让 Unit 指向候选目标，动作范围和 AOE 数量都基于这个目标计算。
	unit.target = target
	for action in unit.actions:
		if action == null:
			continue
		if not unit.is_action_ready(action) or not unit.has_mana(action):
			continue
		if unit.summoned and _contains_summon(action):
			continue

		# 目标类型与硬性条件
		var action_target: Unit = target
		var action_direction := Vector2.ZERO
		var target_count := 0
		match action.target_mode:
			CombatActionDefinition.TargetMode.ENEMY:
				if not unit.has_live_target() or not unit.is_target_in_action_range(action, 4.0):
					continue
			CombatActionDefinition.TargetMode.SELF:
				if unit.hp_ratio() < action.min_self_hp_ratio or unit.hp_ratio() > action.max_self_hp_ratio:
					continue
				if action.requires_wounded_ally and not _has_wounded_ally():
					continue
				action_target = unit
			CombatActionDefinition.TargetMode.DIRECTION:
				if not unit.has_live_target():
					continue
				var best_dir := _best_direction_for(action)
				target_count = int(best_dir.get("count", 0))
				if target_count < maxi(action.min_targets, 1):
					continue
				action_direction = best_dir.get("direction", Vector2.ZERO)
			_:
				continue

		# 行动价值：基础优先级 + situational utility
		var score := float(action.priority)
		for effect in action.effects:
			if effect.kind != ActionEffectDefinition.Kind.DAMAGE:
				continue
			if effect.shape == ActionEffectDefinition.Shape.CONE or effect.shape == ActionEffectDefinition.Shape.CIRCLE:
				score += _count_targets_in_effect(action, effect) * 1.5
			elif effect.shape == ActionEffectDefinition.Shape.RECT and action.target_mode == CombatActionDefinition.TargetMode.DIRECTION:
				score += target_count * 2.0
		# 防御动作在生命越低时越紧急。
		if action.category == CombatActionDefinition.Category.DEFENSE:
			score += (1.0 - unit.hp_ratio()) * 25.0

		# 分数相同则用 action.priority 决胜；仍相同则保留 actions 数组中的先后顺序。
		if score > best_score + 0.001 or (
			absf(score - best_score) <= 0.001 and action.priority > best_priority
		):
			best_score = score
			best_priority = action.priority
			planned_direction = action_direction
			planned_target_count = target_count
			best_plan = ActionPlan.create(action, action_target, action_direction)
	return best_plan


## 在 360° 方向上搜索直线矩形内敌人数最多的方向。
func _contains_summon(action: CombatActionDefinition) -> bool:
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.SUMMON:
			return true
	return false


func _best_direction_for(action: CombatActionDefinition) -> Dictionary:
	var rect_effect: ActionEffectDefinition = null
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.DAMAGE and effect.shape == ActionEffectDefinition.Shape.RECT:
			rect_effect = effect
			break
	if rect_effect == null or unit.battle == null:
		return {}

	var directions: Array[Vector2] = []
	if unit.has_live_target():
		directions.append((target.global_position - unit.global_position).normalized())
	for index in 36:
		directions.append(Vector2.from_angle(TAU * float(index) / 36.0))

	var best_direction := Vector2.ZERO
	var best_count := -1
	for direction in directions:
		if direction.length_squared() < 0.0001:
			continue
		var count: int = unit.battle.units_in_rect(
			unit, direction, rect_effect.length, rect_effect.width
		).size()
		if count > best_count:
			best_count = count
			best_direction = direction
	return {"direction": best_direction, "count": best_count}


func _has_wounded_ally() -> bool:
	if unit.battle == null:
		return false
	for ally in unit.battle.living_units():
		if ally.team == unit.team and ally.hp < ally.max_hp - 0.5:
			return true
	return false


func _count_targets_in_effect(_action: CombatActionDefinition, effect: ActionEffectDefinition) -> int:
	if unit.battle == null:
		return 0
	var direction := Vector2(float(unit.facing), 0.0)
	if target != null:
		direction = (target.global_position - unit.global_position).normalized()
	if effect.shape == ActionEffectDefinition.Shape.CONE:
		return unit.battle.units_in_cone(unit, direction, effect.radius, effect.half_angle).size()
	if effect.shape == ActionEffectDefinition.Shape.CIRCLE:
		var center := target.global_position if target != null else unit.global_position
		return unit.battle.units_in_circle(unit, center, effect.radius).size()
	return 0


# --- A：行动 ------------------------------------------------------------

func _act() -> void:
	unit.target = target
	unit.intent = intent
	unit.intent_reason = intent_reason
	unit.planned_action = planned_action
	unit.planned_direction = planned_direction

	var valid_target := target != null and is_instance_valid(target) and target.alive
	var target_name: String = target.definition.display_name if valid_target else "无"
	match intent:
		Intent.ACTION:
			if planned_action != null and planned_action.target_mode == CombatActionDefinition.TargetMode.SELF:
				last_action_text = "%s → 自身（持续 %.1fs）" % [
					planned_action.display_name, planned_action.action_duration,
				]
			elif planned_action != null and planned_action.target_mode == CombatActionDefinition.TargetMode.DIRECTION:
				last_action_text = "%s → 选定方向（%d 名敌人）" % [
					planned_action.display_name, planned_target_count,
				]
			elif planned_action != null:
				last_action_text = "%s → %s（冷却 %.2fs）" % [
					planned_action.display_name, target_name, unit.action_cooldown(planned_action),
				]
			else:
				last_action_text = "没有可执行动作"
		Intent.ADVANCE:
			last_action_text = "移动 → %s（距离 %.0fpx）" % [target_name, unit.distance_to_target()]
		Intent.KITE:
			last_action_text = "后撤，重新拉开与 %s 的距离" % target_name
		_:
			last_action_text = "原地待机，持续观察"
