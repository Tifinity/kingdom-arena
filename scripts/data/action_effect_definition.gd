class_name ActionEffectDefinition
extends Resource

## 通用动作效果；DAMAGE / PROJECTILE / GUARD / SHIELD 等由 Unit 统一结算。

enum Kind { DAMAGE, PROJECTILE, VISUAL, HEAL, SHIELD, STATUS, DISPLACE, SUMMON, GUARD }
enum Shape { SINGLE, CIRCLE, CONE, SELF, RECT }
enum StatusKind { STUN, SLOW, BLEED, BURN }

@export_enum("伤害:0", "投射物:1", "视觉:2", "治疗:3", "护盾:4", "状态:5", "击退:6", "召唤:7", "格挡:8") var kind: int = Kind.DAMAGE
@export_enum("单体:0", "圆形:1", "扇形:2", "自身:3", "矩形:4") var shape: int = Shape.SINGLE

## 在动作动画的第几帧触发（0 为第一帧）。
@export var trigger_frame: int = 0

## 相对于单位攻击力的倍率。
@export var damage_ratio: float = 1.0

## 圆形/扇形范围的半径。
@export var radius: float = 0.0

## 扇形半角，单位为度。
@export var half_angle: float = 0.0

## 矩形/直线范围：长度与宽度（宽度为全宽）。
@export var length: float = 0.0
@export var width: float = 0.0
## 圆形 AOE 是否以自身为中心（否则以当前目标为中心）。
@export var center_on_self := false

## 状态效果：0 眩晕，1 减速，2 流血，3 燃烧（旧数据兼容）。
@export var status_kind: int = StatusKind.STUN
## 新数据优先使用 status_id 引用 resources/status 下的定义，例如 &"poison"。
@export var status_id: StringName = &""
@export var status_duration: float = 0.0
## 旧语义：减速为速度倍率；流血/燃烧为每秒伤害。新状态由 StatusBehavior 解释。
@export var status_power: float = 0.0
## 状态每秒伤害按施法者当前 AD 的倍率计算；非零时优先于固定 status_power。
@export var status_power_attack_ratio := 0.0
## 施加层数；中毒等可叠层状态使用。
@export var status_stacks := 1
## 状态只作用于本次动作已命中的目标，用于连斩后的流血等效果。
@export var requires_action_hit := false
## 伤害效果命中后附加的火焰 DOT；每秒伤害 = 攻击力 × 倍率。
@export var burn_duration := 0.0
@export var burn_dps_ratio := 0.0

## 护盾效果：每个本次动作命中的不同敌人提供最大生命值的一定比例。
## 护盾总量最多叠加到最大生命值 × shield_max_ratio，duration 控制持续秒数。
@export var shield_per_target_ratio := 0.0
@export var shield_max_ratio := 0.0
## 不依赖命中目标的固定护盾：按自身最大生命比例立即获得（例如重甲兽人的格挡）。
@export var shield_self_ratio := 0.0

## 伤害是否穿透护盾，直接扣除生命（仍然受护甲影响）。
@export var ignore_shield := false

## 格挡成功后的奖励护盾：按最大生命计算，在格挡结束时获得。
@export var guard_reward_shield_ratio := 0.0
@export var guard_reward_shield_duration := 0.0

## 治疗量 = heal_amount + 施法者攻击力 × heal_ratio。
@export var heal_amount: float = 0.0
@export var heal_ratio: float = 0.0

## 召唤单位与数量。
@export var summon_unit_id: StringName
@export var summon_count := 1
## 击退距离。
@export var knockback: float = 0.0

## 状态/格挡类效果的持续时间。
@export var duration: float = 0.0

## 投射物类型：0 无，1 箭矢，2 法术。
@export var projectile_kind: int = 0
## 箭矢沿发射时的方向直线飞行；默认投射物仍追踪目标。
@export var straight_projectile := false

## 投射物、AOE、治疗等视觉场景；可选。
@export var effect_scene: PackedScene

## 新效果优先使用独立 Behavior；为空时兼容旧 kind 结算。
@export var behavior: ActionEffectBehavior
