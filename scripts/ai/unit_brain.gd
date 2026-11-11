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
var planned_target: Unit
var planned_direction := Vector2.ZERO
var planned_point := Vector2.ZERO
var planned_has_point := false
var planned_target_count := 0
var plan_score := 0.0
var plan_reason := ""
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
	if not unit.can_act():
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

	var previous_target: Unit = target if is_instance_valid(target) and target.alive else null
	var previous_score := -INF
	var best: Unit = null
	var best_score := -INF
	var close_threats := 0
	var threat_radius := maxf(unit.attack_range * 1.2, 190.0)

	for enemy in enemies:
		var distance: float = unit.global_position.distance_to(enemy.global_position)
		var score := _score_target(enemy, distance)
		if enemy == previous_target:
			previous_score = score
		if distance <= threat_radius:
			close_threats += 1
		if score > best_score:
			best_score = score
			best = enemy

	# 微小评分波动不换目标，避免每次思考都重新转身。
	if previous_target != null and best != previous_target and previous_score >= best_score - 0.12:
		best = previous_target
		best_score = previous_score
	var forced := unit.status_controller.forced_target() if unit.status_controller != null else null
	if forced != null and enemies.has(forced):
		best = forced
		best_score = _score_target(forced, unit.global_position.distance_to(forced.global_position))
	else:
		forced = null
	target = best
	var threat := clampf(float(close_threats) / 4.0 + (1.0 - unit.hp_ratio()) * 0.55, 0.0, 1.0)
	judgment = {
		"target": best,
		"score": best_score,
		"close_threats": close_threats,
		"threat": threat,
	}
	last_judge_text = ("被嘲讽 → %s" % forced.definition.display_name) if forced != null else (
		"优先 %s · 评分 %.2f · 近身威胁 %d 人" % [
			best.definition.display_name if best != null else "无", best_score, close_threats,
		])


func random_score() -> float:
	return _rng.randf()


func _score_target(enemy: Unit, distance: float) -> float:
	var score := 0.0
	if unit.definition.behavior_profile != null and unit.definition.behavior_profile.targeting != null:
		score = unit.definition.behavior_profile.targeting.score_target(self, enemy, distance)
	else:
		score = (1.0 - clampf(distance / 1000.0, 0.0, 1.0)) * 0.50
		score += (1.0 - enemy.hp_ratio()) * 0.25
		score += clampf(enemy.definition.damage_per_second() / 140.0, 0.0, 1.0) * 0.12
	# 队友正在集火时协助；后排被贴身追击时优先保护。
	for ally in observation.get("allies", []):
		if not is_instance_valid(ally) or not ally.alive:
			continue
		if ally.has_live_target() and ally.target == enemy:
			score += 0.07
			if ally.state_machine.current_name == &"action" and enemy.hp <= ally.attack_damage * 1.2:
				score -= 0.18
		if enemy.has_live_target() and enemy.target == ally and ally.definition.is_ranged() and enemy.global_position.distance_to(ally.global_position) < 180.0:
			score += 0.35
	return score


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
	planned_target = null
	planned_direction = Vector2.ZERO
	planned_point = Vector2.ZERO
	planned_has_point = false
	planned_target_count = 0
	plan_score = 0.0
	plan_reason = ""

	if target == null or not is_instance_valid(target) or not target.alive:
		target = null
		intent_reason = "没有可攻击目标"
		last_decide_text = "%s：%s" % [INTENT_LABELS[intent], intent_reason]
		return

	var plan := _select_action()
	if plan != null:
		planned_action = plan.action
		planned_target = plan.target
		planned_point = plan.point
		planned_has_point = plan.has_point
		if planned_action.target_mode in [CombatActionDefinition.TargetMode.ENEMY, CombatActionDefinition.TargetMode.POINT]:
			target = plan.target
		intent = Intent.ACTION
		intent_reason = "使用 %s（%s，%s）" % [planned_action.display_name, planned_action.category_label(), plan_reason]
	elif _should_kite():
		intent = Intent.KITE
		intent_reason = "距离过近，后撤拉开射程"
	elif unit.is_target_in_range(6.0):
		intent_reason = "所有可用动作都在冷却，等待时机"
	else:
		intent = Intent.ADVANCE
		intent_reason = "向目标推进，等待动作就绪"

	last_decide_text = "%s：%s" % [INTENT_LABELS[intent], intent_reason]


## 对每个可用动作和目标组合评分；施法目标由动作收益决定。
func _select_action() -> ActionPlan:
	var best_plan: ActionPlan = null
	var best_score := -INF
	var enemies: Array = observation.get("enemies", [])
	var forced := unit.status_controller.forced_target() if unit.status_controller != null else null
	for action in unit.actions:
		if action == null:
			continue
		if not unit.is_action_ready(action) or not unit.has_mana(action):
			continue
		if forced != null and (not action.is_offensive() or action.target_mode == CombatActionDefinition.TargetMode.SELF):
			continue
		if unit.summoned and _contains_summon(action):
			continue
		var candidates: Array[Unit] = []
		var direction := Vector2.ZERO
		var cluster: Dictionary = {}
		match action.target_mode:
			CombatActionDefinition.TargetMode.ENEMY:
				if forced != null:
					candidates.append(forced)
				elif action.select_farthest():
					var farthest: Unit = null
					for enemy in enemies:
						if farthest == null or unit.global_position.distance_squared_to(enemy.global_position) > unit.global_position.distance_squared_to(farthest.global_position):
							farthest = enemy
					if farthest != null:
						candidates.append(farthest)
				elif action.targeting != null and action.targeting.selection == ActionTargetingDefinition.Selection.LOWEST_HP_ENEMY:
					var lowest := _lowest_hp_enemy_in_range(action, enemies)
					if lowest != null:
						candidates.append(lowest)
				else:
					for enemy in enemies:
						candidates.append(enemy)
			CombatActionDefinition.TargetMode.SELF:
				if not _self_area_has_enemy(action):
					continue
				candidates.append(unit)
			CombatActionDefinition.TargetMode.ALLY:
				var allies: Array[Unit] = [unit]
				for ally in observation.get("allies", []):
					allies.append(ally)
				if action.targeting != null and action.targeting.selection == ActionTargetingDefinition.Selection.LOWEST_HP_ALLY:
					var lowest: Unit = null
					for ally in allies:
						if not ally.alive or ally.hp >= ally.max_hp - 0.5:
							continue
						if action.action_range > 0.0 and unit.global_position.distance_to(ally.global_position) > action.action_range + ally.body_radius:
							continue
						if lowest == null or ally.hp_ratio() < lowest.hp_ratio():
							lowest = ally
					if lowest != null:
						candidates.append(lowest)
				else:
					candidates.append_array(allies)
			CombatActionDefinition.TargetMode.POINT:
				if action.select_densest_cluster():
					var radius := 0.0
					for effect in action.effects:
						if effect.shape == ActionEffectDefinition.Shape.CIRCLE:
							radius = maxf(radius, effect.radius)
					cluster = ActionTargetQuery.densest_circle_point(unit, enemies, radius, action.action_range)
					if int(cluster.get("count", 0)) < maxi(action.min_targets, 1):
						continue
					candidates.append(cluster["anchor"] as Unit)
				elif forced != null:
					candidates.append(forced)
				else:
					for enemy in enemies:
						candidates.append(enemy)
					for ally in observation.get("allies", []):
						candidates.append(ally)
					candidates.append(unit)
			CombatActionDefinition.TargetMode.DIRECTION:
				if forced != null:
					direction = (forced.global_position - unit.global_position).normalized()
					candidates.append(forced)
				else:
					var best_dir := _best_direction_for(action)
					if int(best_dir.get("count", 0)) < maxi(action.min_targets, 1):
						continue
					direction = best_dir.get("direction", Vector2.ZERO)
					candidates.append(target)
			_:
				continue
		for candidate in candidates:
			if candidate == null or not is_instance_valid(candidate) or not candidate.alive:
				continue
			var candidate_direction := direction
			if action.select_farthest():
				candidate_direction = (candidate.global_position - unit.global_position).normalized()
			var candidate_point: Vector2 = cluster.get("point", candidate.global_position) if not cluster.is_empty() else (candidate.global_position if action.target_mode == CombatActionDefinition.TargetMode.POINT else Vector2.ZERO)
			var candidate_has_point := action.target_mode == CombatActionDefinition.TargetMode.POINT
			if not cluster.is_empty():
				candidate_direction = (candidate_point - unit.global_position).normalized()
			if not ActionActivation.reason(unit, action, candidate, candidate_direction, candidate_point, candidate_has_point).is_empty():
				continue
			var evaluation := _evaluate_cluster_plan(action, cluster) if not cluster.is_empty() else _evaluate_plan(action, candidate, candidate_direction)
			var score: float = evaluation.score
			if score > best_score + 0.001:
				best_score = score
				planned_direction = candidate_direction
				planned_point = candidate_point
				planned_has_point = candidate_has_point
				planned_target_count = int(evaluation.hits)
				plan_score = score
				plan_reason = evaluation.reason
				best_plan = ActionPlan.create(action, candidate, candidate_direction, candidate_point, candidate_has_point)
	return best_plan


## 动作自己指定“范围内最低血量敌人”时，只把该目标交给评分；
## 距离过滤与 ActionActivation 保持一致，避免选到无法施放的远处残血目标。
func _lowest_hp_enemy_in_range(action: CombatActionDefinition, enemies: Array) -> Unit:
	var lowest: Unit = null
	var aoe_reach := unit.action_aoe_reach(action)
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var distance := unit.global_position.distance_to(enemy.global_position)
		if distance < action.min_range:
			continue
		if action.movement_kind() != ActionMovementDefinition.Kind.CHARGE:
			var reach: float
			if aoe_reach > 0.0:
				reach = (aoe_reach + enemy.body_radius + 6.0) * unit.AOE_CAST_BUFFER
			else:
				reach = action.action_range + enemy.body_radius + unit.body_radius * 0.35 + 6.0
			if distance > reach:
				continue
		if lowest == null or enemy.hp_ratio() < lowest.hp_ratio():
			lowest = enemy as Unit
	return lowest


func _evaluate_cluster_plan(action: CombatActionDefinition, cluster: Dictionary) -> Dictionary:
	var count := int(cluster.get("count", 0))
	var threat := float(cluster.get("threat", 0.0))
	var point: Vector2 = cluster.get("point", unit.global_position)
	var shield_ratio := 0.0
	var shield_cap := 0.0
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.SHIELD:
			shield_ratio = effect.shield_per_target_ratio
			shield_cap = effect.shield_max_ratio
	var shield_gain := minf(float(count) * shield_ratio, shield_cap) * 10.0
	var score := float(action.priority) + float(count) * 4.0 + threat * 2.0 + shield_gain
	score += (1.0 - unit.hp_ratio()) * 10.0
	score -= unit.global_position.distance_to(point) / 250.0
	if count == 1 and threat < 1.0 and unit.hp_ratio() > 0.7:
		score -= 6.0
	return {"score": score, "hits": count,
		"reason": "预计嘲讽 %d 人，评分 %.1f" % [count, score]}


func _evaluate_plan(action: CombatActionDefinition, candidate: Unit, direction: Vector2) -> Dictionary:
	var damage_by_target: Dictionary = {}
	var victims_by_id: Dictionary = {}
	var support := 0.0
	for effect in action.effects:
		if effect.kind == ActionEffectDefinition.Kind.DAMAGE or effect.kind == ActionEffectDefinition.Kind.PROJECTILE:
			for victim in _plan_victims(action, effect, candidate, direction):
				var key := victim.get_instance_id()
				victims_by_id[key] = victim
				damage_by_target[key] = float(damage_by_target.get(key, 0.0)) + unit.attack_damage * maxf(effect.damage_ratio, 0.0)
		elif effect.kind == ActionEffectDefinition.Kind.HEAL:
			for ally in ActionTargetQuery.allies(unit, effect, candidate, direction):
				support += minf(ally.max_hp - ally.hp, effect.heal_amount + unit.attack_damage * effect.heal_ratio) / maxf(unit.attack_damage, 1.0)
		elif effect.kind == ActionEffectDefinition.Kind.STATUS:
			var status_definition := StatusCatalog.definition_for_effect(effect)
			if status_definition != null:
				if status_definition.has_tag(&"control"):
					support += 1.0
				elif status_definition.has_tag(&"dot"):
					support += 0.35
		elif effect.kind == ActionEffectDefinition.Kind.SHIELD:
			var nearby: int = unit.battle.units_in_circle(unit, unit.global_position, effect.radius).size()
			var shield_cap := maxf(effect.shield_max_ratio, effect.shield_self_ratio)
			var shield_gain: float = minf(
				unit.max_hp * (effect.shield_self_ratio + effect.shield_per_target_ratio * nearby),
				maxf(0.0, unit.max_hp * shield_cap - unit.shield))
			support += shield_gain / maxf(unit.attack_damage, 1.0)
	var expected_damage := 0.0
	var kills := 0
	for key in damage_by_target:
		var victim: Unit = victims_by_id[key]
		var dealt: float = float(damage_by_target[key]) * (1.0 - clampf(victim.armor, 0.0, 0.8))
		var remaining_hp := maxf(0.0, victim.hp - _committed_ally_damage(victim))
		expected_damage += minf(remaining_hp, dealt) / maxf(unit.attack_damage, 1.0)
		if remaining_hp > 0.0 and dealt >= remaining_hp:
			kills += 1
	var score := float(action.priority) + expected_damage * 1.2 + float(kills) * 1.0 + support * 1.5
	if candidate != unit:
		score += _score_target(candidate, unit.global_position.distance_to(candidate.global_position)) * 2.0
		if action.movement_kind() == ActionMovementDefinition.Kind.TELEPORT and action.preferred_min_range > 0.0:
			if unit.global_position.distance_to(candidate.global_position) >= action.preferred_min_range:
				score += 3.0
	if action.category == CombatActionDefinition.Category.DEFENSE:
		score += (1.0 - unit.hp_ratio()) * 25.0
	if action.mana_cost >= unit.max_mana - 0.001:
		score -= 0.8
		if victims_by_id.size() == 1 and candidate != unit and candidate.hp - _committed_ally_damage(candidate) <= unit.attack_damage:
			score -= 12.0
	return {"score": score, "hits": victims_by_id.size(),
		"reason": "预计命中 %d 人，评分 %.1f" % [victims_by_id.size(), score]}


func _committed_ally_damage(victim: Unit) -> float:
	var incoming := 0.0
	for ally in observation.get("allies", []):
		if not is_instance_valid(ally) or not ally.alive or not ally.has_live_target() or ally.target != victim:
			continue
		if ally.state_machine.current_name != &"action" or ally.planned_action == null:
			continue
		for effect in ally.planned_action.effects:
			if (effect.kind == ActionEffectDefinition.Kind.DAMAGE or effect.kind == ActionEffectDefinition.Kind.PROJECTILE) and effect.shape == ActionEffectDefinition.Shape.SINGLE:
				incoming += ally.attack_damage * effect.damage_ratio * (1.0 - clampf(victim.armor, 0.0, 0.8))
	return incoming


func _plan_victims(action: CombatActionDefinition, effect: ActionEffectDefinition, candidate: Unit, direction: Vector2) -> Array[Unit]:
	if action.movement_kind() == ActionMovementDefinition.Kind.CHARGE:
		var path_effect := effect.duplicate() as ActionEffectDefinition
		path_effect.length = unit.global_position.distance_to(candidate.global_position)
		return ActionTargetQuery.enemies(unit, path_effect, candidate, direction)
	return ActionTargetQuery.enemies(unit, effect, candidate, direction,
		candidate.global_position if action.target_mode == CombatActionDefinition.TargetMode.POINT else Vector2.ZERO,
		action.target_mode == CombatActionDefinition.TargetMode.POINT)


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
		var count: int = ActionTargetQuery.enemies(unit, rect_effect, target, direction).size()
		if count > best_count:
			best_count = count
			best_direction = direction
	return {"direction": best_direction, "count": best_count}


func _self_area_has_enemy(action: CombatActionDefinition) -> bool:
	if unit.battle == null:
		return false
	for effect in action.effects:
		if effect.shape != ActionEffectDefinition.Shape.CIRCLE or not effect.center_on_self:
			continue
		if (effect.kind == ActionEffectDefinition.Kind.DAMAGE
				or effect.kind == ActionEffectDefinition.Kind.STATUS
				or effect.kind == ActionEffectDefinition.Kind.DISPLACE):
			return not ActionTargetQuery.enemies(unit, effect, unit, Vector2.ZERO).is_empty()
	return true


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
	unit.planned_target = planned_target
	unit.planned_direction = planned_direction
	unit.planned_point = planned_point
	unit.planned_has_point = planned_has_point

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
