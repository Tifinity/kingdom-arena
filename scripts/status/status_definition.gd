class_name StatusDefinition
extends Resource

## 异常状态的数据定义：描述“是什么、持续多久、怎么叠加、由谁执行”。
## 运行时剩余时间/层数等状态不放在这里，避免多个单位共享同一份 Resource 时互相污染。

enum StackPolicy {
	REFRESH,     ## 刷新剩余时间，不叠层；例如眩晕
	EXTEND,      ## 在剩余时间上继续延长
	STRONGEST,   ## 只保留最强的一次；例如流血、燃烧、减速
	STACK,       ## 叠层；例如中毒
	INDEPENDENT, ## 每次施加都创建独立实例
}

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D

## 语义标签，用于 UI、免疫、驱散和状态间交互，例如 control / dot / fire / poison。
@export var tags: Array[StringName] = []

@export var duration := 1.0
## true 时状态不会自然到期，由施加者按条件手动移除（例如狂怒的低血量状态）。
@export var persistent := false
## 0 表示不进行周期结算。
@export var tick_interval := 0.0
@export var max_stacks := 1
@export var stack_policy := StackPolicy.REFRESH
## true 时，不同来源各自拥有独立实例；false 时同 id 共享一个实例。
@export var source_scoped := false
## 施加时没有显式 power 时使用的默认值。
@export var base_power := 0.0

## 具体行为策略：控制、DoT、属性修改或自定义 Behavior。
@export var behavior: StatusBehavior
## 可选的状态表现场景；由 UnitStatusController 创建和释放。
@export var vfx_scene: PackedScene
## true 时特效锚定在单位原点（脚底），忽略血条位置与 vfx_offset。
@export var vfx_at_origin := false
## 相对于单位血条的偏移。
@export var vfx_offset := Vector2(0.0, -22.0)


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
