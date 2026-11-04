class_name ActionEffectDefinition
extends Resource

## 通用动作效果。当前实现 DAMAGE / PROJECTILE / VISUAL 三类，
## 其余枚举为位移、护盾、状态、召唤等后续扩展预留。

enum Kind { DAMAGE, PROJECTILE, VISUAL, HEAL, SHIELD, STATUS, DISPLACE, SUMMON, GUARD }
enum Shape { SINGLE, CIRCLE, CONE, SELF, RECT }
enum StatusKind { STUN, SLOW, BLEED }

@export var kind: int = Kind.DAMAGE
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

## 状态效果：0 眩晕，1 减速，2 流血。
@export var status_kind: int = StatusKind.STUN
@export var status_duration: float = 0.0
## 减速为速度倍率；流血为每秒伤害。
@export var status_power: float = 0.0

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

## 投射物、AOE、治疗等视觉场景；可选。
@export var effect_scene: PackedScene
