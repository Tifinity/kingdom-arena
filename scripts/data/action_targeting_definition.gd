class_name ActionTargetingDefinition
extends Resource

## 候选目标的选择规则；命中范围仍由 ActionEffectDefinition.shape 决定。

enum Selection { ALL, FARTHEST }

@export_enum("全部候选:0", "最远敌人:1") var selection: int = Selection.ALL
