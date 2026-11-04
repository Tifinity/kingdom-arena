class_name UnitDefinition
extends Resource

## 一个英雄单位的静态数据。
##
## 场景/动画/数值全部作为资源持有：运行时只负责把资源挂到单位场景上，
## 战斗逻辑不内嵌任何具体英雄的数值。

enum Faction { KINGDOM, LEGION }
enum AttackKind { MELEE, RANGED }
enum ProjectileKind { NONE, ARROW, MAGIC }

const FACTION_NAMES := {
	Faction.KINGDOM: "王国",
	Faction.LEGION: "荒野",
}

@export_group("身份")
@export var unit_id: StringName
@export var display_name: String = "英雄"
@export var title: String = ""
@export_enum("王国:0", "荒野:1") var faction: int = Faction.KINGDOM
@export var role: String = "战士"
## 名册排序，数值越小越靠前。
@export var roster_order: int = 0
@export_multiline var description: String = ""

@export_group("基础属性")
@export var max_hp: float = 500.0
@export var attack_damage: float = 50.0
## 每秒普通攻击次数。
@export var attack_speed: float = 1.0
@export var attack_range: float = 80.0
@export var move_speed: float = 120.0
## 0.1 表示减免 10% 伤害。
@export_range(0.0, 0.8, 0.01) var armor: float = 0.0
## 攻击动画起手到伤害结算的时间。
@export var attack_windup: float = 0.3

@export_group("资源")
@export var max_mana := 100.0
@export var mana_regen := 8.0

@export_group("行为")
## 索敌/移动策略；为空时使用默认加权索敌与通用阵型移动。
@export var behavior_profile: UnitBehaviorProfile

@export_group("动作")
## 该单位可执行的全部 Action（普通攻击、技能、防御、位移……）。
## 决策层从这些动作中选择 ActionPlan；ActionState 负责执行。
@export var actions: Array[CombatActionDefinition] = []

@export_group("攻击表现")
@export_enum("近战:0", "远程:1") var attack_kind: int = AttackKind.MELEE
@export_enum("无:0", "箭矢:1", "法术:2") var projectile_kind: int = ProjectileKind.NONE
@export var attack_animation: StringName = &"attack_01"

@export_group("视觉")
## 可选：该英雄的专用场景。为空时使用共享的 scenes/battle/unit.tscn。
## 只有节点结构确实不同的英雄才需要覆盖；技能/数值/动画差异不要用它。
@export var unit_scene: PackedScene
## 每个英雄的视觉子场景：精灵位置、缩放、血条、脚底/命中点等。
## 为空时回退到基础视觉场景；手工调整后 build_assets 不会覆盖已存在文件。
@export var visual_scene: PackedScene
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D
@export var visual_scale: float = 4.0
## 100x100 帧内脚底相对画布中心向下的像素数，用于把精灵贴到地面上。
@export var foot_offset: float = 7.0
## 待机时的角色像素高度（100x100 帧内），用于血条与选中框定位。
@export var character_height: float = 24.0
## 用于点击命中、单位分离与血条宽度的碰撞半径。
@export var body_radius: float = 30.0
@export var accent_color: Color = Color("#f0b36b")


func attack_interval() -> float:
	return 1.0 / maxf(attack_speed, 0.05)


func damage_per_second() -> float:
	return attack_damage * attack_speed


## 用于阵容面板的粗略战力值，只做展示，不参与战斗结算。
func power_rating() -> int:
	return int(round(max_hp * 0.2 + damage_per_second() * 8.0 + armor * 400.0))


func is_ranged() -> bool:
	return attack_kind == AttackKind.RANGED


func faction_label() -> String:
	return FACTION_NAMES.get(faction, "未知")


func stat_line() -> String:
	return "生命 %d · 攻击 %d · 攻速 %.2f/s" % [roundi(max_hp), roundi(attack_damage), attack_speed]
