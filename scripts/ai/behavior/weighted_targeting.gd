class_name WeightedTargeting
extends TargetingStrategy

## 通用加权索敌：距离、残血、输出威胁、职业关系、当前目标粘性。

@export var distance_weight := 0.50
@export var low_hp_weight := 0.25
@export var threat_weight := 0.12
@export var backline_bonus := 0.0
@export var assassin_ranged_bonus := 0.18
@export var ranged_tank_penalty := 0.08
@export var sticky_bonus := 0.08
@export var random_jitter := 0.02


func score_target(brain: UnitBrain, enemy: Unit, distance: float) -> float:
	var unit := brain.unit
	var score := 0.0
	score += (1.0 - clampf(distance / 1000.0, 0.0, 1.0)) * distance_weight
	score += (1.0 - enemy.hp_ratio()) * low_hp_weight
	score += clampf(enemy.definition.damage_per_second() / 140.0, 0.0, 1.0) * threat_weight

	if enemy.definition.is_ranged():
		score += backline_bonus
	if unit.definition.role == "突袭" and enemy.definition.is_ranged():
		score += assassin_ranged_bonus
	if unit.definition.is_ranged() and enemy.definition.role == "坦克":
		score -= ranged_tank_penalty
	if unit.has_live_target() and enemy == unit.target:
		score += sticky_bonus
	score += brain.random_score() * random_jitter
	return clampf(score, 0.0, 1.0)
