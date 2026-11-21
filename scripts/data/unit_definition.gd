class_name UnitDefinition
extends Resource

## 一个英雄单位的静态数据。
##
## 场景/动画/数值全部作为资源持有：运行时只负责把资源挂到单位场景上，
## 战斗逻辑不内嵌任何具体英雄的数值。

enum Faction { HUMAN, WILDERNESS, MONSTER }
enum AttackKind { MELEE, RANGED }
enum ProjectileKind { NONE, ARROW, MAGIC, ICE, FIREBALL, GHOSTFIRE, HOLY_BOLT }

const FACTION_NAMES := {
	Faction.HUMAN: "人类",
	Faction.WILDERNESS: "荒野",
	Faction.MONSTER: "怪物",
}

@export_group("身份")
@export var unit_id: StringName
@export var display_name: String = "英雄"
@export var title: String = ""
@export_enum("人类:0", "荒野:1", "怪物:2") var faction: int = Faction.HUMAN
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
## 新入场单位的初始蓝量；剑士为 50，其余现有英雄为 0。
@export var starting_mana := 0.0
@export var mana_regen := 8.0

@export_group("行为")
## 索敌/移动策略；为空时使用默认加权索敌与通用阵型移动。
@export var behavior_profile: UnitBehaviorProfile
## 训练靶：不移动、不死亡，也不会损失生命，只记录实际受到的伤害。
## 试炼场的稻草人使用该标记，正常名册单位保持关闭。
@export var training_dummy := false

@export_group("动作")
## 该单位可执行的全部 Action（普通攻击、技能、防御、位移……）。
## 决策层从这些动作中选择 ActionPlan；ActionState 负责执行。
@export var actions: Array[CombatActionDefinition] = []
@export var passive: PassiveDefinition

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


## 调试/Hero Lab：同时修改定义与基础 Action，供后续生成的单位使用。
func apply_stat_override(stats: Dictionary) -> void:
	var old_range := attack_range
	if stats.has("max_hp"):
		max_hp = maxf(1.0, float(stats["max_hp"]))
	if stats.has("attack_damage"):
		attack_damage = maxf(1.0, float(stats["attack_damage"]))
	if stats.has("attack_speed"):
		attack_speed = clampf(float(stats["attack_speed"]), 0.05, 20.0)
	if stats.has("attack_range"):
		attack_range = clampf(float(stats["attack_range"]), 10.0, 2000.0)
	if stats.has("armor"):
		armor = clampf(float(stats["armor"]), 0.0, 0.8)
	if stats.has("move_speed"):
		move_speed = clampf(float(stats["move_speed"]), 10.0, 800.0)
	if stats.has("mana_regen"):
		mana_regen = clampf(float(stats["mana_regen"]), 0.0, 100.0)
	if stats.has("max_mana"):
		max_mana = maxf(0.0, float(stats["max_mana"]))
		starting_mana = minf(starting_mana, max_mana)
	if stats.has("starting_mana"):
		starting_mana = clampf(float(stats["starting_mana"]), 0.0, max_mana)
	var new_interval := attack_interval()
	for index in actions.size():
		var action := actions[index]
		if action == null or action.category != CombatActionDefinition.Category.BASIC:
			continue
		var copy: CombatActionDefinition = action.duplicate()
		copy.cooldown = new_interval
		if is_equal_approx(action.action_range, old_range):
			copy.action_range = attack_range
		actions[index] = copy


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


func skill_description_text() -> String:
	var lines: Array[String] = []
	for action in actions:
		if action == null or action.category == CombatActionDefinition.Category.BASIC:
			continue
		var mana_text := "满蓝" if action.mana_cost >= max_mana - 0.001 else ("蓝 %.0f" % action.mana_cost if action.mana_cost > 0.0 else "0 蓝")
		lines.append("%s｜%s｜CD %.0f 秒：%s" % [action.display_name, mana_text, action.cooldown, action.detail_text(attack_damage)])
	if passive != null:
		lines.append("%s｜被动：%s" % [passive.display_name, passive.detail_text()])
	return "\n".join(PackedStringArray(lines))
