# 技能系统与数值调整

每名单位 3 主动 + 1 被动的设计及逐项完成状态见 [单位技能追踪表](SKILL_ROSTER.md)。

圣殿骑士「圣光裁决」的金色冲击波位于 `scenes/fx/templar_judgement_wave.tscn`，由动作伤害效果的 `effect_scene` 在斩击结算帧生成。波纹从施法者向施法方向扩散，宽度和最远距离直接读取同一效果的 `half_angle`、`radius`；特效只负责表现，不重复造成伤害。

圣殿骑士原格挡动作已改为满蓝大招「圣盾守护」，数值在 `resources/actions/knight_templar_block.tres`：`move_02` 动画以最高 850px/s 冲向 340px 内敌群最密集的可达位置；抵达后对周围 160px 敌人施加 2.5 秒嘲讽，每名命中的敌人提供最大生命 12% 的护盾，最多 48%，持续 4 秒。嘲讽期间敌人的下一次决策和攻击目标被锁定到圣殿骑士，已经开始的动作不会被打断。位置搜索先最大化覆盖人数，再优先保护正在被追击的友军，最后选择更靠近敌群中心的位置。落地结界和目标头顶标记分别由 `scenes/fx/aegis_ring.tscn`（pixelfx `holy/aegis-ring`，金色光点钻进地面、结界滚开、光柱与盾徽升起后碎成光屑）、`scenes/fx/taunt_mark.tscn` 呈现。原满蓝技「圣光裁决」改为 0 蓝普通技能，CD12、扇形 1.5 AD。

牧师「圣光弹」位于 `resources/actions/priest_holy_bolt.tres`，使用 `HOLY_BOLT` 投射物和 `assets/fx/pixelfx/holy_laser_bolt.png`；「祈福」与「圣光普照」使用 `LOWEST_HP_ALLY` 目标规则，默认选择范围内生命比例最低的受伤友军。治疗量由 `heal_amount + 攻击力 × heal_ratio` 计算，`PriestGrace` 被动在目标生命低于 40% 时把治疗量提高 20%；战斗中可在观察镜里看到「恩泽 · 被动 · 常驻」。

骑士的被动资源位于 `resources/passives/knight_morale.tres`，引用两份 20 秒的属性状态：护甲加 0.05（5 个百分点）与攻击力加 5。`UnitDefinition.passive` 决定单位是否拥有被动；战斗倒计时结束时由 `Unit.on_battle_started()` 施加，状态到期自动恢复基础值。调数值时改对应的 `resources/status/knight_morale_armor.tres`、`resources/status/knight_morale_attack.tres` 的 `base_power` 和 `duration`；被动描述中的占位符会按资源当前数值重新渲染。
剑士「追击步」位于 `resources/actions/swordsman_chase_step.tres`：动作选择范围内血量比例最低的敌人，朝其方向以 `ADVANCE` 位移 160 像素，不造成伤害，随后施加 `swordsman_chase_haste` 状态（`attack_speed` 乘区 ×1.10，持续 4 秒）。`Unit.start_action_cooldown()` 对普攻使用 `current_attack_interval()`，因此攻速 buff/debuff 会直接改变实际出手间隔；状态资源的 `power` 是乘区，`1.10` 表示 +10%。

剑士「热诚决斗」位于 `resources/passives/swordsman_zeal_duel.tres`：`PassiveDefinition.skill_hit_stacks_status` 指向 `swordsman_zeal` 状态，每次**技能伤害命中**施加一层；状态使用 `STACK` 叠加、持续 6 秒、上限 5 层，每层提供 5% 攻速。满 5 层时，`ZealDuelBehavior.modify_damage()` 让每次动作伤害额外 +5。普攻不叠层，DoT 周期伤害也不叠层；动作目标规则可用 `ActionTargetingDefinition.Selection.LOWEST_HP_ENEMY` 指定“范围内最低血量敌人”。

精锐兽人「狂怒」位于 `resources/passives/elite_orc_rage.tres`：`PassiveDefinition.hp_threshold` 为 0.5，`hp_threshold_status` 指向不会自然到期的 `persistent` 状态 `elite_orc_rage`。`Unit` 在 `heal()` / `take_damage()` 结算后调用 `sync_conditional_passives()`，生命低于 50% 时施加、回到 50% 以上时移除；状态以 `StatModifierBehavior` 把 `attack_damage` 乘 1.5，并用 `lifesteal_bonus` 提供 0.1 吸血。伤害扣除护甲与护盾后，`Unit._apply_lifesteal()` 按实际伤害的该比例回复攻击者生命。状态特效 `scenes/fx/rage_status.tscn` 是 pixelfx `status/seething` 的“纯光环”版：导出时用空角色遮罩跳过替身身体，只保留怒纹、蒸汽、应激线和红光，精灵表由 `tools/export_rage_status.mjs` 生成。


骑士格挡使用通用 `GUARD` 效果；成功格挡后的奖励护盾由 `resources/actions/knight_block.tres` 的 `guard_reward_shield_ratio` 和 `guard_reward_shield_duration` 控制。其他单位可用不同奖励、格挡时长、触发条件与冷却形成差异，不需要在单位脚本中写分支。

重甲兽人的「格挡」不再使用 `GUARD`，而是 `SHIELD` 效果的 `shield_self_ratio = 0.2`：低血量时立即获得最大生命 20% 的护盾，持续 4 秒，期间不再免疫伤害。它的被动资源 `resources/passives/armored_orc_regen.tres` 使用 `hp_regen_ratio_per_second = 0.02`，由 `Unit._physics_process()` 每帧按最大生命比例回复，生命上限与回复比例都会实时参与计算。

| 单位 | 格挡定位 | 状态 |
| --- | --- | --- |
| 骑士 | 挡住伤害后获得自身最大生命 8% 护盾，持续 3 秒 | 已实现 |
| 圣殿骑士 | 圣盾守护：冲入敌群、范围嘲讽并按敌人数获得护盾 | 已实现，替代原格挡 |
| 重甲兽人 | 举盾立即获得自身最大生命 20% 护盾，持续 4 秒，不再免伤 | 已实现，替代原格挡 |
| 兽人骑兵 | 格挡时间略长，但冷却更长；脱离格挡后加速切入 | 设计建议，未实现 |
| 骷髅 | 低血量时维持较长格挡，不产生额外护盾 | 设计建议，未实现 |

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
| 骑士双连斩 | `resources/actions/knight_cleave.tres` 中两个伤害效果的 `damage_ratio`，当前为 1.2、1.5；`trigger_frame` 为 4、7 |
| 格挡成功奖励 | 格挡效果的 `guard_reward_shield_ratio`、`guard_reward_shield_duration`，仅实际挡住伤害才在格挡结束时给护盾 |
| 自施固定护盾 | `SHIELD` 效果的 `shield_self_ratio` 与 `duration`；按命中人数叠加仍用 `shield_per_target_ratio` / `shield_max_ratio` |
| 穿透护盾 | 伤害/投射物效果的 `ignore_shield = true`，伤害仍受护甲影响 |
| 开战被动 | `UnitDefinition.passive` 指向被动资源；状态资源的 `base_power`、`duration` 控制属性加成和持续时间 |
| 常驻生命回复 | 被动的 `hp_regen_ratio_per_second`，0.02 表示每秒回复最大生命的 2% |
| 低血量被动与吸血 | 被动的 `hp_threshold`、`hp_threshold_status`；状态行为的 `stat`/`mode` 与 `lifesteal_bonus` |
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
