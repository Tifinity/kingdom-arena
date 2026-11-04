class_name ActionEffectDefinition
extends Resource

## 通用动作效果。当前实现 DAMAGE / PROJECTILE / VISUAL 三类，
## 其余枚举为位移、护盾、状态、召唤等后续扩展预留。

enum Kind { DAMAGE, PROJECTILE, VISUAL, HEAL, SHIELD, STATUS, DISPLACE, SUMMON, GUARD }
enum Shape { SINGLE, CIRCLE, CONE, SELF, RECT }

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

## 状态/格挡类效果的持续时间。
@export var duration: float = 0.0

## 投射物类型：0 无，1 箭矢，2 法术。
@export var projectile_kind: int = 0

## 投射物、AOE、治疗等视觉场景；可选。
@export var effect_scene: PackedScene
