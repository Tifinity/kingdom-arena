class_name CombatActionDefinition
extends Resource

## 一个角色可执行的完整动作：普攻、技能、护盾、突进等都复用这个结构。
## 决策层只负责选 ActionPlan；ActionState 负责按 animation/effects 执行。

enum Category { BASIC, SKILL, DEFENSE, MOVEMENT, SUPPORT }
enum TargetMode { ENEMY, ALLY, SELF, POINT, DIRECTION }

@export var action_id: StringName
@export var display_name := "行动"
@export_enum("普攻:0", "技能:1", "防御:2", "位移:3", "辅助:4") var category: int = Category.BASIC
@export_enum("敌人:0", "友军:1", "自身:2", "地点:3", "方向:4") var target_mode: int = TargetMode.ENEMY

@export var animation: StringName = &"attack_01"
@export var animation_speed := 1.0
@export var action_range := 80.0
@export var min_range := 0.0
@export var cooldown := 1.0
@export var mana_cost := 0.0
## 动作固定持续时间；大于动画时长时会保持动作状态。
@export var action_duration := 0.0
## 可选的自施法血量条件（比例 0~1），用于防御动作。
@export var min_self_hp_ratio := 0.0
@export var max_self_hp_ratio := 1.0
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
