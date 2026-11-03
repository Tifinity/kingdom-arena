# 技能、范围与行为差异：什么时候该拆场景？

> **实现状态（2026-11）**：`CombatActionDefinition`、`ActionEffectDefinition`、
> 统一 `ActionState`、`UnitBrain._select_action()` 与骑士·火焰斩击已落地。
> 下文把 `AttackState` 称为通用 Action 执行器；文中部分迁移步骤是后续扩展方向。

结论先说：

> **技能范围、动画、帧数、冷却、目标优先级、技能释放顺序，都不需要为每个英雄拆独立场景。**
> 这些是“数据 + 策略”的差异，应该放进 Resource，而不是复制 22 个 `unit.tscn`。
>
> **只有当英雄的节点结构真的不同**（多段模型、坐骑、额外碰撞盒、召唤物挂点、独立动画系统等），
> 才需要专用场景；即使如此，也应该**继承/组合**共享单位场景，而不是复制整套状态机。

---

## 1. 先分清四类东西

| 类别 | 适合放在哪里 | 例子 |
| --- | --- | --- |
| 节点结构 / 可复用表现 | `.tscn` | 单位骨架、血条、投射物、AOE 圈、召唤特效 |
| 数值 / 动作参数 / 目标权重 | `.tres` Resource | 技能范围、动画名、起手时间、伤害倍率、优先级权重 |
| 通用行为 | 共享脚本 | StateMachine、ActionState、Brain 主循环 |
| 真正独有的行为 | 小型策略资源或继承场景 | 特殊目标规则、召唤阶段、变身阶段 |

一句话：**场景负责“长什么样、由哪些节点组成”，资源负责“参数和差异”，脚本负责“通用规则”。**

---

## 2. 推荐结构

### 2.1 Unit 仍然是共享场景

保持当前结构不变：

```text
scenes/battle/unit.tscn
├─ Shadow / TeamRing / SelectionRing
├─ Visual (AnimatedSprite2D)
├─ HealthBar
├─ Brain
└─ StateMachine
   ├─ Idle
   ├─ Move
   ├─ Action
   ├─ Hurt
   └─ Death
```

`UnitDefinition` 负责把“这个英雄”的一切数据注入进来。

### 2.2 UnitDefinition 增加三个扩展位

```gdscript
class_name UnitDefinition
extends Resource

# 原有：基础属性、SpriteFrames、头像、缩放……

## 这个英雄的全部主动动作；第 0 个可以继续作为普攻。
@export var actions: Array[CombatActionDefinition] = []

## 索敌权重、后撤阈值、职业偏好等“打法”。
@export var behavior: BehaviorProfile

## 可选：只有节点结构确实不同才覆盖；默认 null 使用共享 unit.tscn。
@export var unit_scene: PackedScene
```

`unit_scene` 是逃生舱，不是默认做法。当前项目已经实现这个字段：
[Battle._spawn_lineups()](../scripts/battle/battle.gd) 和
[HeroLab._spawn_preview()](../scripts/debug/hero_lab.gd) 会优先使用
`definition.unit_scene`，为空才加载共享 `unit.tscn`。

### 2.3 每个技能 = 一个 CombatActionDefinition

```gdscript
class_name CombatActionDefinition
extends Resource

enum TargetType { ENEMY, ALLY, SELF, POINT }
enum Delivery { MELEE, PROJECTILE, AOE, BUFF }

@export var action_id: StringName
@export var display_name: String
@export var animation: StringName = &"attack_01"  # 指向该英雄 SpriteFrames 的动画名

@export var windup := 0.3          # 起手到命中
@export var range := 80.0          # 施法/攻击距离
@export var min_range := 0.0       # 最小距离（远程近身不能放）
@export var cooldown := 1.0
@export var mana_cost := 0.0
@export var damage_ratio := 1.0

@export var target_type: TargetType = TargetType.ENEMY
@export var delivery: Delivery = Delivery.MELEE
@export var projectile_scene: PackedScene
@export var effect_scene: PackedScene
@export var radius := 0.0          # AOE 半径
@export var priority := 0          # 技能选择优先级
```

这样一来：

- **不同技能范围**：改 `range` / `min_range`，不用改场景。
- **不同动画帧**：动画帧仍在每个英雄的 `SpriteFrames` 里；
  动作只引用动画名，帧数和时长由 SpriteFrames 决定。
- **不同起手/命中节奏**：改 `windup`；需要精确命中帧时再加 `hit_frame` 字段，
  由 `ActionState` 按帧数换算时间。
- **不同伤害/冷却/蓝耗**：改字段。
- **不同投射物/爆炸**：引用不同的可复用 effect/projectile 场景。

`UnitActionState` 不再写死 `attack_01`，而是接受一个 `CombatActionDefinition`：

```gdscript
func begin_action(action: CombatActionDefinition) -> void:
    _action = action
    _duration = duration_for(action.animation)
    _windup = action.windup
    unit.attack_range = action.range
    unit.play_animation(action.animation, true)
```

当前 MVP 只是一个特例：`action = basic_attack`，动画名 `attack_01`。

### 2.4 不同英雄的“优先打谁” = BehaviorProfile

目标选择逻辑继续放在 `UnitBrain._judge()`，但权重从硬编码变成资源：

```gdscript
class_name BehaviorProfile
extends Resource

@export var distance_weight := 0.50
@export var low_hp_weight := 0.25
@export var threat_weight := 0.12
@export var sticky_weight := 0.08
@export var kite_ratio := 0.42

## 职业偏好：例如 { "突袭": { "射手": 0.2, "法师": 0.2 } }
@export var role_bonus: Dictionary = {}

## 是否优先后排；也可以扩展成命名策略。
@export var prefer_backline := false

## 技能行为规则，见下一节。
@export var action_rules: Array[ActionRule] = []
```

例子：

- **狼人 / 兽人骑兵**：`prefer_backline = true`，对射手/法师的 `role_bonus` 高，
  距离权重略低 → 会主动绕过前排切后排。
- **弓箭手**：`kite_ratio` 更大，坦克目标权重为负 → 优先打脆皮、被贴脸时更早后撤。
- **死灵法师**：远程权重高，但技能规则优先召唤/暗影法术。

`UnitBrain` 只做通用评分，不写 `if unit_id == "werewolf"` 这种分支。

### 2.5 技能释放顺序 = ActionRule 数据

“先加血还是先输出”“AOE 什么时候放”也属于数据，不应该变成每个英雄一套状态机。

```gdscript
class_name ActionRule
extends Resource

@export var action: CombatActionDefinition
@export var priority := 0
@export var self_hp_below := 1.0
@export var target_hp_below := 1.0
@export var min_enemies_in_radius := 0
@export var require_target_role: String = ""
```

决策时可以按 priority 排序，选择第一条满足条件的动作：

```gdscript
# 伪代码
for rule in behavior.action_rules:
    if rule.matches(brain.observation):
        return Intent.ACTION(rule.action)

return Intent.ATTACK(basic_attack)
```

如果规则复杂到数据表达不了（例如“保护血量最低的友军直到其脱离战斗”），
再为这个英雄提供一个 **BehaviorStrategy** 资源/脚本，让 Brain 委托给它；
仍然不需要复制单位场景或整套 FSM。

---

## 3. 什么时候该拆独立场景？

| 需求 | 是否需要独立单位场景 | 推荐做法 |
| --- | --- | --- |
| 不同技能范围/动画/帧数/冷却 | 否 | CombatActionDefinition + SpriteFrames |
| 不同目标优先级 | 否 | BehaviorProfile |
| 不同技能释放顺序 | 否 | ActionRule / BehaviorStrategy |
| 新投射物/AOE/召唤特效 | 否 | 新建可复用 effect/projectile 场景，动作引用 |
| 多段模型、坐骑、武器挂点 | **是** | 继承 `unit.tscn`，加挂点节点，`unit_scene` 指向它 |
| 额外碰撞盒/受击区域 | **是** | 继承场景，加 Area2D/Shape |
| 独有动画系统（AnimationPlayer/Spine） | **是** | 继承/自定义 Visual 子场景 |
| 独有状态需要额外节点（如召唤柱、变身形态） | **可能需要** | 继承场景 + 增加状态节点；共享状态仍复用 |
| 完全不同的 AI 架构 | 极少 | 先尝试 BehaviorStrategy；确实不同再专用场景 |

关键：**“技能不同”不是拆场景的理由，“节点结构不同”才是。**

---

## 4. 具体例子

### 弓箭手：穿透箭

```text
resources/actions/archer_piercing_shot.tres
  animation = &"attack_02"
  range = 420
  windup = 0.42
  cooldown = 6.0
  delivery = PROJECTILE
  projectile_scene = res://scenes/fx/piercing_arrow.tscn
  priority = 10
```

- 只是新动作资源 + 投射物场景；
- `SpriteFrames` 已有 `attack_02`；
- 弓箭手的 `UnitDefinition` 的 `actions` 加上它；
- 试炼场可以增加“技能”按钮，直接预览 `attack_02`。

### 法师：范围火球

```text
fireball.tres
  animation = attack_02
  delivery = AOE
  radius = 140
  effect_scene = explosion.tscn
  action_rules: 当范围内敌人 ≥ 2 时优先使用
```

- 爆点判定、AOE 圈、爆炸特效都是独立可复用场景；
- 法师仍然共用 `unit.tscn`；
- 不需要法师专属状态机。

### 死灵法师：召唤

```text
summon.tres
  animation = summon
  delivery = BUFF
  effect_scene = summon_effect.tscn
  cooldown = 12
```

- 召唤物由 effect 场景或 Battle 生成；
- 若召唤需要“持续施法/打断”这类独特阶段，再增加一个通用 `ChannelState`
  或给死灵法师一个继承场景 + 专属状态节点。

### 狼人：优先切后排

```text
werewolf_behavior.tres
  distance_weight = 0.32
  role_bonus = { "突袭": { "射手": 0.28, "法师": 0.28 } }
  prefer_backline = true
```

- 不新增状态、不新增场景，只换行为资源。

---

## 5. 状态机怎么演进

保持状态机通用，按“动作类型”扩展而不是按“英雄”扩展：

```text
Idle
Move
Action (普攻/技能)
Skill  (由 CombatActionDefinition 驱动)
Hurt
Death
```

`Skill` 可以是复用 `Action` 的参数化版本；只有确实需要独立阶段（引导、变身、召唤阶段）时，
才拆成 `Channel`、`Transform`、`Summon` 这类**通用状态**。

如果某个英雄必须有专属状态节点：

1. 新建继承场景 `scenes/battle/units/necromancer.tscn`，继承 `unit.tscn`；
2. 在它的 StateMachine 下加一个 `SummonState` 节点；
3. `UnitDefinition.unit_scene` 指向该场景；
4. 共享的 Idle/Move/Action/Hurt/Death 仍然复用，不复制逻辑。

这样即使有 3~5 个英雄需要特殊结构，也不会出现 22 份 FSM。

---

## 6. Hero Lab 的扩展方向

当前 [英雄试炼场](../scenes/debug/hero_lab.tscn) 已支持动作播放和 1v1。接技能后建议增加：

- 动作列表改为“技能列表”，按 `actions` 显示名称/冷却/蓝耗；
- 播放技能动画并显示范围圈（`range` / `radius`）；
- 显示目标评分明细，方便调 `BehaviorProfile`；
- 切换行为资源与对手，观察“优先打谁”的差异；
- 一键进入真实 1v1，用 OODA 观察镜验证。

这样调一个英雄只改资源、在试炼场里即时验证，不用复制场景。

---

## 7. 建议的迁移顺序

1. **抽出 CombatActionDefinition**
   - 先把当前普攻包装成一个 action；
   - `UnitDefinition` 增加 `actions`；
   - `ActionState` 读取 action；
   - 行为与现在完全一致，测试保持通过。
2. **抽出 BehaviorProfile**
   - 把 `_score_target` 的权重搬到资源；
   - 默认值与当前代码一致；
   - 逐个英雄调参。
3. **增加 Skill/ChannelState 与 ActionRule**
   - 先做 2~3 个通用技能效果场景；
   - 再给英雄填 actions。
4. **最后才考虑 `unit_scene`**
   - 只有确实需要额外节点时才覆盖；
   - 继承 `unit.tscn`，不复制状态机。
5. **测试与数据校验**
   - 每个 action 引用存在的动画；
   - range / min_range / cooldown 合法；
   - 每个英雄至少有一个可用动作。

---

## 8. 不推荐的做法

- 22 个英雄 22 个完整 `unit.tscn`：改血条/受击/寻路要改 22 次。
- 每个英雄一套 `if unit_id == ...` 分支塞进 Brain。
- 为每个技能复制一个状态机。
- 把技能范围写进场景节点、把动画帧数写进代码。
- 让“技能范围不同”成为拆场景的理由。

---

## 9. 最终判断

| 变化 | 放哪里 |
| --- | --- |
| 技能范围、动画名、起手、冷却、蓝耗、伤害倍率 | `CombatActionDefinition` |
| 动画帧本身 | 英雄的 `SpriteFrames` |
| 优先攻击谁 | `BehaviorProfile` |
| 技能释放条件/顺序 | `ActionRule` / `BehaviorStrategy` |
| 新投射物、AOE、召唤特效 | 独立可复用 `.tscn` |
| 多段模型、挂点、碰撞盒、独有节点结构 | 继承 `unit.tscn` 的专用场景，`unit_scene` 覆盖 |
| 独有状态节点 | 继承场景 + 新增通用状态；共享 FSM 不复制 |

**结论：绝大多数“不同技能、不同范围、不同动画、不同集火逻辑”都应通过资源和策略解决；
场景只在结构需要不同时按需拆分，并且优先继承/组合共享单位场景。**
