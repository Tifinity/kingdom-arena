class_name CombatActionDefinition
extends Resource

## 一个角色可执行的完整动作：普攻、技能、护盾、突进等都复用这个结构。
## 决策层只负责选 ActionPlan；ActionState 负责按 animation/effects 执行。

enum Category { BASIC, SKILL, DEFENSE, MOVEMENT, SUPPORT }
enum TargetMode { ENEMY, ALLY, SELF, POINT, DIRECTION }

@export var action_id: StringName
@export var display_name := "行动"
@export_multiline var description := ""
@export_enum("普攻:0", "技能:1", "防御:2", "位移:3", "辅助:4") var category: int = Category.BASIC
@export_enum("敌人:0", "友军:1", "自身:2", "地点:3", "方向:4") var target_mode: int = TargetMode.ENEMY

@export var animation: StringName = &"attack_01"
@export var animation_speed := 1.0
@export var action_range := 80.0
@export var min_range := 0.0
## 偏好的目标最小距离；只影响评分，近身目标仍可作为后备目标。
@export var preferred_min_range := 0.0
@export var cooldown := 1.0
@export var mana_cost := 0.0
## 动作固定持续时间；大于动画时长时会保持动作状态。
@export var action_duration := 0.0
## 可选的自施法血量条件（比例 0~1），用于防御动作。
@export var min_self_hp_ratio := 0.0
@export var max_self_hp_ratio := 1.0
@export_group("旧版位移兼容")
## 旧动作资源使用的字段；新动作请配置下方 movement/targeting。
@export var advance_speed := 0.0
@export var advance_distance := 0.0
@export var teleport_to_target := false
@export var teleport_gap := 10.0
@export var charge_to_farthest := false
@export var charge_speed := 0.0
@export_group("使用条件")
## DIRECTION/AOE 动作至少需要命中的敌人数，0/1 表示无额外限制。
@export var min_targets := 1
## 治疗/辅助动作只在存在受伤队友时参与决策。
@export var requires_wounded_ally := false
## 多个动作同时可用时，决策层的偏好权重。
@export var priority := 0

@export_group("目标与位移")
@export var targeting: ActionTargetingDefinition
@export var movement: ActionMovementDefinition

@export var effects: Array[ActionEffectDefinition] = []


func movement_kind() -> int:
	if movement != null:
		return movement.kind
	if charge_to_farthest:
		return ActionMovementDefinition.Kind.CHARGE
	if teleport_to_target:
		return ActionMovementDefinition.Kind.TELEPORT
	if advance_speed > 0.0:
		return ActionMovementDefinition.Kind.ADVANCE
	return ActionMovementDefinition.Kind.NONE


func movement_speed() -> float:
	if movement != null:
		return movement.speed
	return charge_speed if charge_to_farthest else advance_speed


func movement_distance() -> float:
	return movement.distance if movement != null else advance_distance


func movement_gap() -> float:
	return movement.target_gap if movement != null else teleport_gap


func select_farthest() -> bool:
	if targeting != null:
		return targeting.selection == ActionTargetingDefinition.Selection.FARTHEST
	return charge_to_farthest


func select_densest_cluster() -> bool:
	return targeting != null and targeting.selection == ActionTargetingDefinition.Selection.DENSEST_CLUSTER


func category_label() -> String:
	match category:
		Category.BASIC: return "普攻"
		Category.SKILL: return "技能"
		Category.DEFENSE: return "防御"
		Category.MOVEMENT: return "位移"
		Category.SUPPORT: return "辅助"
	return "行动"


func is_offensive() -> bool:
	return category == Category.BASIC or category == Category.SKILL


func is_enemy_targeted() -> bool:
	return target_mode == TargetMode.ENEMY


func detail_text(attack_damage: float = -1.0) -> String:
	var parts: Array[String] = []
	var damage_counts: Dictionary = {}
	var damage_parts: Array[String] = []
	var rendered_description := description
	var has_damage_placeholder := false
	var damage_index := 0
	for effect in effects:
		match effect.kind:
			ActionEffectDefinition.Kind.DAMAGE, ActionEffectDefinition.Kind.PROJECTILE:
				var shape := "单体"
				match effect.shape:
					ActionEffectDefinition.Shape.CIRCLE: shape = "范围"
					ActionEffectDefinition.Shape.CONE: shape = "扇形"
					ActionEffectDefinition.Shape.RECT: shape = "直线"
				var formula := _damage_formula(effect.damage_ratio, attack_damage)
				var placeholder := "{damage_%d}" % damage_index
				if rendered_description.contains(placeholder):
					rendered_description = rendered_description.replace(placeholder, formula)
					has_damage_placeholder = true
				damage_index += 1
				var damage_text := "%s%s伤害" % [shape, formula]
				if not damage_counts.has(damage_text):
					parts.append(damage_text)
					damage_parts.append(damage_text)
					damage_counts[damage_text] = 0
				damage_counts[damage_text] += 1
			ActionEffectDefinition.Kind.HEAL:
				parts.append("治疗友军")
			ActionEffectDefinition.Kind.SHIELD:
				parts.append("每命中一名敌人获得 %.0f%% 最大生命护盾，最多 %.0f%%，持续 %.0f 秒" % [
					effect.shield_per_target_ratio * 100.0, effect.shield_max_ratio * 100.0, effect.duration])
			ActionEffectDefinition.Kind.GUARD:
				parts.append("格挡 %.1f 秒" % effect.duration)
				rendered_description = rendered_description.replace("{guard_duration}", _number_text(effect.duration))
				rendered_description = rendered_description.replace("{guard_reward_shield_percent}", _number_text(effect.guard_reward_shield_ratio * 100.0))
				rendered_description = rendered_description.replace("{guard_reward_shield_duration}", _number_text(effect.guard_reward_shield_duration))
				if effect.guard_reward_shield_ratio > 0.0:
					parts.append("成功格挡后获得 %.0f%% 最大生命护盾，持续 %.1f 秒" % [effect.guard_reward_shield_ratio * 100.0, effect.guard_reward_shield_duration])
			ActionEffectDefinition.Kind.SUMMON:
				parts.append("召唤 %d 名单位" % effect.summon_count)
			ActionEffectDefinition.Kind.STATUS:
				var status_definition := StatusCatalog.definition_for_effect(effect)
				var status_name := status_definition.display_name if status_definition != null else "状态"
				var status_text := "附加%s %.1f 秒" % [status_name, effect.status_duration]
				if effect.shape == ActionEffectDefinition.Shape.CIRCLE and effect.center_on_self:
					status_text = "周围 %.0fpx %s" % [effect.radius, status_text]
				if effect.status_stacks > 1:
					status_text += " ×%d" % effect.status_stacks
				parts.append(status_text)
			ActionEffectDefinition.Kind.DISPLACE:
				parts.append("击退 %.0f 像素" % effect.knockback)
	if movement_kind() == ActionMovementDefinition.Kind.ADVANCE:
		parts.push_front("突进 %.0f 像素" % movement_distance() if movement_distance() > 0.0 else "边移动边攻击")
	if movement_kind() == ActionMovementDefinition.Kind.CHARGE:
		parts.push_front("冲向最远敌人")
	if movement_kind() == ActionMovementDefinition.Kind.TELEPORT:
		parts.push_front("闪现到目标身前")
	if movement_kind() == ActionMovementDefinition.Kind.DASH_TO_POINT:
		parts.push_front("冲向敌群密集处")
	for index in parts.size():
		if damage_counts.has(parts[index]) and damage_counts[parts[index]] > 1:
			parts[index] += " ×%d" % damage_counts[parts[index]]
	for index in damage_parts.size():
		if damage_counts[damage_parts[index]] > 1:
			damage_parts[index] += " ×%d" % damage_counts[damage_parts[index]]
	if not description.is_empty():
		if rendered_description.contains("{total_damage}"):
			var total_ratio := 0.0
			for effect in effects:
				if effect.kind == ActionEffectDefinition.Kind.DAMAGE or effect.kind == ActionEffectDefinition.Kind.PROJECTILE:
					total_ratio += effect.damage_ratio
			rendered_description = rendered_description.replace("{total_damage}", _damage_formula(total_ratio, attack_damage))
			has_damage_placeholder = true
		if attack_damage >= 0.0 and not has_damage_placeholder and not damage_parts.is_empty():
			rendered_description += " 基础伤害：%s。" % "、".join(PackedStringArray(damage_parts))
		return rendered_description
	return "、".join(PackedStringArray(parts)) if not parts.is_empty() else category_label()


func _damage_formula(damage_ratio: float, attack_damage: float) -> String:
	if attack_damage < 0.0:
		return "%.0f%%攻击" % (damage_ratio * 100.0)
	var damage := attack_damage * maxf(damage_ratio, 0.0)
	var rounded := snappedf(damage, 0.001)
	var value := str(roundi(rounded)) if is_equal_approx(rounded, float(roundi(rounded))) else str(rounded)
	return "%s（AD × %s）" % [value, str(damage_ratio)]


func _number_text(value: float) -> String:
	var rounded := snappedf(value, 0.001)
	return str(roundi(rounded)) if is_equal_approx(rounded, float(roundi(rounded))) else str(rounded)
