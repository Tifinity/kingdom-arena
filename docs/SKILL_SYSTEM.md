# 技能系统与数值调整

## 2026-11-08 首轮单位数值粗调

以本机 Hero Lab 已保存的骑士（生命 150、攻击 12、攻速 0.70、护甲 15%）
和剑士（生命 120、攻击 15、攻速 0.80、护甲 5%）为参照，
将这两个基准写回资源，再调整其余 20 名单位的生命、攻击、攻速和护甲。
剑士入场蓝量为 50；其余单位仍为 0。这轮保留其他单位的射程、移速、
技能倍率、蓝耗和技能冷却；攻击力变化会同步影响技能伤害。
所有普攻动作的冷却均与新的攻速同步，死灵法师的鬼火同步为 1.18 秒。
固定值技能按新生命尺度同步调整：牧师群体治疗的固定部分为 20，
狼人的流血每秒伤害为 3。

| 定位 | 本轮取向 | 例子 |
| --- | --- | --- |
| 坦克 | 高生命与护甲，压低持续输出 | 熊人 190 生命、15 攻击、0.60 攻速；兽人骑兵 195 生命、21% 护甲 |
| 战士 | 中等生存与输出；巨剑类保留高单次伤害 | 巨剑骷髅 18 攻击、0.65 攻速；精锐兽人 15 攻击、0.85 攻速 |
| 射手 / 法师 | 依靠射程和技能，以较低生命换输出 | 法师 80 生命、15 攻击；弓箭手 85 生命、11 攻击 |
| 辅助 | 普攻较弱，以治疗技能提供价值 | 牧师 95 生命、8 攻击、0.80 攻速 |
| 突袭 | 生存较低，以机动和爆发补偿 | 蝙蝠 75 生命、10 攻击、1.15 攻速；狼人 115 生命、15 攻击 |

这些是按定位做的首轮数值，不代表阵容胜率已经平衡。初步比较可用
`攻击力 × 攻速` 看普攻输出、`生命 ÷ (1 - 护甲)` 看无治疗时的物理承伤；
实际强度还受技能范围、施法时机、控制、召唤和目标选择影响。
Hero Lab 保存的 `user://hero_stat_overrides.cfg` 会覆盖 `.tres` 基础属性；
如果游戏里看到不同的数值，应先检查该文件或在 Hero Lab 清除对应覆盖。

## 改数值的入口

在 Godot 文件系统面板打开 `resources/units/<英雄 id>.tres`，找到 `actions` 列表，
再打开其中引用的 `resources/actions/<动作 id>.tres`。这个动作文件是技能数值的
主要维护入口，直接在 Inspector 修改并保存即可。

| 想调整的内容 | 位置与字段 |
| --- | --- |
| 技能冷却、蓝耗、施放距离 | 动作 `.tres` 的 `cooldown`、`mana_cost`、`action_range`、`min_range` |
| AI 选择倾向 | 动作 `.tres` 的 `priority`、`preferred_min_range`、`min_targets`、生命条件 |
| 伤害 | 动作内 `effect_*` 的 `damage_ratio`，实际基础伤害为英雄 `attack_damage × damage_ratio` |
| 命中范围 | `effect_*` 的 `shape`、`radius`、`half_angle`、`length`、`width` |
| 命中时机 | `effect_*` 的 `trigger_frame`；从 0 开始计数，受动作动画帧率影响 |
| 治疗、护盾、击退、召唤 | `effect_*` 的 `heal_amount`/`heal_ratio`、`shield_*`、`knockback`、`summon_*` |
| 冲锋、推进、闪现 | 动作内 `movement` 的 `kind`、`speed`、`distance`、`target_gap` |
| 最远目标选择 | 动作内 `targeting.selection`；`FARTHEST` 选最远敌人 |
| 英雄基础属性和回蓝 | `resources/units/<英雄 id>.tres` 的 `attack_damage`、`attack_speed`、`max_mana`、`starting_mana`、`mana_regen` 等 |
| 持续状态的默认规则 | `resources/status/<状态 id>.tres` 的 `duration`、`tick_interval`、`stack_policy`、`max_stacks` 等 |

例如，调枪兵的火焰冲锋：打开 `resources/actions/lancer_flame_pierce.tres`，
改 `cooldown` 和 `mana_cost` 控制释放频率；改 `effect_0.damage_ratio` 控制冲锋伤害，
改 `effect_0.burn_duration` 和 `burn_dps_ratio` 控制燃烧；改 `movement.speed` 控制冲锋速度。
如果要改变这招基础伤害的来源数值，再改 `resources/units/lancer.tres` 的
`attack_damage`，这会同时影响该英雄的其他攻击。

战斗中的 Hero Lab/F2 属性调试会修改英雄属性，适合快速试手感；它不编辑动作资源。
要把技能平衡改动纳入项目，应保存对应的 `.tres` 文件。

布阵页和 Hero Lab 的技能描述按英雄 `attack_damage` 计算每次基础伤害；战斗观察面板
按单位当前攻击力计算。这里显示的是护甲等减伤前的数值。同一动作内相同倍率的多次命中
会合并显示次数。手写 `description` 会自动附加伤害明细；如果要把数值嵌入句子，可使用
`{damage_0}`、`{damage_1}` 等占位符，数字对应动作中伤害/投射物效果的顺序；
`{total_damage}` 显示本动作所有伤害效果的倍率之和，前提是这些效果都命中同一目标。
例如剑士的三连刺使用 `{damage_0}`，其每剑伤害会随着 `attack_damage` 或
`damage_ratio` 的修改自动更新。

`python3 tools/build_assets.py` 默认只补齐缺失的英雄与动作资源，不覆盖已存在的
`.tres`。`--rebuild-actions` 会按 `tools/build_assets.py` 中的技能模板重建全部动作，
覆盖手调技能数值；`--rebuild-units` 会覆盖手调英雄基础数值。仅在有意重置时使用。

## 运行结构

1. `UnitDefinition.actions` 保存静态动作资源；AI 根据目标收益产生 `ActionPlan`。
2. `ActionActivation.reason()` 统一检查行动限制、冷却、蓝耗和目标条件；HUD 使用同一结果。
3. `UnitActionState` 为每次施放创建 `ActionCast`，保存命中集合、已走距离、方向和时间线进度。
4. `ActionTargetQuery` 为 AI 预估和实际效果结算提供相同的圆形、扇形、矩形、单体查询。
5. `ActionEffectDefinition.behavior` 可挂可复用效果策略。现有治疗和召唤已使用独立策略；
   旧动作效果仍由 `kind` 路径执行，便于逐步迁移。
6. `UnitStatusController` 管理持续状态、叠加、周期效果和状态表现。

蓝量在进入动作时扣除，冷却也从进入动作时开始；普通伤害不打断动作。
眩晕等控制效果打断施放时，不返还蓝量或重置冷却。

新增技能时，先在英雄的 `actions` 列表添加动作资源，再配置目标模式、动画、效果与
时间线。友军和地点目标已支持；地点技能的中心取 `ActionPlan.point`，并要求
`has_point = true`，因此坐标原点也是合法的目标点。如果需要一种
新的效果或位移方式，可新增对应 Behavior/策略类，再从动作资源引用。

## 验证

改完技能数值后运行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn
```

涉及目标范围或位移的修改，建议在 Hero Lab 和固定阵容里再看实际命中与表现。
