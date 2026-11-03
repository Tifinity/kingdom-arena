class_name UnitBrain
extends Node

## OODA 行为大脑：观察（Observe）→ 判断（Orient/Judge）→ 决策（Decide）→ 行动（Act）。
##
## 大脑只负责“想”，不直接改动画或位置；它把目标与意图写给 Unit，
## 由 StateMachine 中当前状态节点负责“做”。这样 AI 与表现/动画解耦，
## 后续增加技能时只需要扩展决策分支与攻击状态的动作配置。

enum Intent { IDLE, ADVANCE, ATTACK, KITE }

const THINK_INTERVAL := 0.16
const INTENT_LABELS := {
	Intent.IDLE: "待机",
	Intent.ADVANCE: "推进",
	Intent.ATTACK: "攻击",
	Intent.KITE: "拉开距离",
}

@export var enabled := true

var unit: Unit
var intent: int = Intent.IDLE
var intent_reason := ""
var target: Unit
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


func _score_target(enemy: Unit, distance: float) -> float:
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
	if not unit.definition.is_ranged() or not unit.has_live_target():
		return false
	return unit.distance_to_target() < unit.attack_range * 0.42


# --- D：决策 ------------------------------------------------------------

func _decide() -> void:
	intent = Intent.IDLE
	intent_reason = "等待战机"

	if target == null or not is_instance_valid(target) or not target.alive:
		target = null
		intent_reason = "没有可攻击目标"
	elif unit.is_target_in_range(6.0):
		if unit.attack_cooldown <= 0.0:
			intent = Intent.ATTACK
			intent_reason = "目标进入攻击距离，普攻就绪"
		elif _should_kite():
			intent = Intent.KITE
			intent_reason = "冷却中且被近身，先后撤拉开距离"
		else:
			intent_reason = "目标在攻击距离内，等待攻击冷却"
	elif _should_kite():
		intent = Intent.KITE
		intent_reason = "距离过近，后撤拉开射程"
	else:
		intent = Intent.ADVANCE
		intent_reason = "向目标推进"

	last_decide_text = "%s：%s" % [INTENT_LABELS[intent], intent_reason]


# --- A：行动 ------------------------------------------------------------

func _act() -> void:
	unit.target = target
	unit.intent = intent
	unit.intent_reason = intent_reason

	var valid_target := target != null and is_instance_valid(target) and target.alive
	var target_name: String = target.definition.display_name if valid_target else "无"
	match intent:
		Intent.ATTACK:
			last_action_text = "普通攻击 → %s（冷却 %.2fs）" % [target_name, unit.attack_cooldown]
		Intent.ADVANCE:
			last_action_text = "移动 → %s（距离 %.0fpx）" % [target_name, unit.distance_to_target()]
		Intent.KITE:
			last_action_text = "后撤，重新拉开与 %s 的距离" % target_name
		_:
			last_action_text = "原地待机，持续观察"
