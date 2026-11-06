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
## 动作期间沿选定方向前进的速度；0 表示原地。
@export var advance_speed := 0.0
## 动作期间最多前进的距离；0 表示沿用完整动画时长。
@export var advance_distance := 0.0
## 瞬移到所选敌人身前的近战位置，入场时执行。
@export var teleport_to_target := false
@export var teleport_gap := 10.0
## 冲锋：选最远敌人，沿起点到目标位置的线段移动并逐个命中。
@export var charge_to_farthest := false
@export var charge_speed := 0.0
## DIRECTION/AOE 动作至少需要命中的敌人数，0/1 表示无额外限制。
@export var min_targets := 1
## 治疗/辅助动作只在存在受伤队友时参与决策。
@export var requires_wounded_ally := false
## 多个动作同时可用时，决策层的偏好权重。
@export var priority := 0

@export var effects: Array[ActionEffectDefinition] = []


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


func detail_text() -> String:
	if not description.is_empty():
		return description
	var parts: Array[String] = []
	var damage_counts: Dictionary = {}
	for effect in effects:
		match effect.kind:
			ActionEffectDefinition.Kind.DAMAGE, ActionEffectDefinition.Kind.PROJECTILE:
				var shape := "单体"
				match effect.shape:
					ActionEffectDefinition.Shape.CIRCLE: shape = "范围"
					ActionEffectDefinition.Shape.CONE: shape = "扇形"
					ActionEffectDefinition.Shape.RECT: shape = "直线"
				var damage_text := "%s%.0f%%攻击伤害" % [shape, effect.damage_ratio * 100.0]
				if not damage_counts.has(damage_text):
					parts.append(damage_text)
					damage_counts[damage_text] = 0
				damage_counts[damage_text] += 1
			ActionEffectDefinition.Kind.HEAL:
				parts.append("治疗友军")
			ActionEffectDefinition.Kind.SHIELD:
				parts.append("每命中一名敌人获得 %.0f%% 最大生命护盾，最多 %.0f%%，持续 %.0f 秒" % [
					effect.shield_per_target_ratio * 100.0, effect.shield_max_ratio * 100.0, effect.duration])
			ActionEffectDefinition.Kind.GUARD:
				parts.append("格挡 %.1f 秒" % effect.duration)
			ActionEffectDefinition.Kind.SUMMON:
				parts.append("召唤 %d 名单位" % effect.summon_count)
			ActionEffectDefinition.Kind.STATUS:
				var status := ["眩晕", "减速", "流血", "灼烧"]
				parts.append("附加%s %.1f 秒" % [status[clampi(effect.status_kind, 0, 3)], effect.status_duration])
			ActionEffectDefinition.Kind.DISPLACE:
				parts.append("击退 %.0f 像素" % effect.knockback)
	if advance_speed > 0.0:
		parts.push_front("突进 %.0f 像素" % advance_distance if advance_distance > 0.0 else "边移动边攻击")
	if charge_to_farthest:
		parts.push_front("冲向最远敌人")
	if teleport_to_target:
		parts.push_front("闪现到目标身前")
	for index in parts.size():
		if damage_counts.has(parts[index]) and damage_counts[parts[index]] > 1:
			parts[index] += " ×%d" % damage_counts[parts[index]]
	return "、".join(PackedStringArray(parts)) if not parts.is_empty() else category_label()
