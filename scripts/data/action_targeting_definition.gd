class_name ActionTargetingDefinition
extends Resource

## 候选目标的选择规则；命中范围仍由 ActionEffectDefinition.shape 决定。

enum Selection { ALL, FARTHEST, DENSEST_CLUSTER, LOWEST_HP_ENEMY, LOWEST_HP_ALLY, LOWEST_ARMOR_ENEMY, LOWEST_CURRENT_HP_ENEMY }

@export_enum("全部候选:0", "最远敌人:1", "最密集敌群:2", "范围内最低血量比例敌人:3", "最低血量友军:4", "范围内最低护甲敌人:5", "范围内最低当前血量敌人:6") var selection: int = Selection.ALL
