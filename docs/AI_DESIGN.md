# 单位 AI：OODA 决策 + 有限状态机

> **当前实现状态（2026-11）**：Attack/Skill 已统一为一个 `Action` 状态。
> 每个单位持有 `actions: Array[CombatActionDefinition]`；`UnitBrain._select_action()`
> 选择 `ActionPlan`，由 `UnitActionState` 按动画帧执行 effects。
> 骑士·火焰斩击（`attack_03`，扇形 AOE，30 蓝耗）已作为第一个技能接入。
> 本文保留基础 OODA 与状态机的设计说明，其中旧的 Attack 名称对应现在的 Action。

本文记录 `王国竞技场` MVP 的单位行为设计。目标不是“让单位互殴”，而是把
**感知、判断、执行**拆成可观察、可测试、可扩展的三层：

```text
每 0.16s ─────────────┐
                      ▼
              ┌───────────────┐
              │  UnitBrain    │  OODA：观察 → 判断 → 决策 → 行动
              │  （想）        │  选择 ActionPlan + 目标
              └───────┬───────┘
                      │ ActionPlan
                      ▼
每物理帧 ────> ┌───────────────┐
              │ UnitStateMachine │  当前状态节点执行
              │ Idle/Move/      │  动画、移动、命中帧、效果
              │ Action/Hurt/    │
              │ Death           │
              └───────────────┘
```

这种拆分带来三个好处：

1. **AI 可解释**：HUD 的 OODA 观察镜直接显示大脑的每一步结果。
2. **表现可替换**：换动画、换特效、加技能状态不会影响判断逻辑。
3. **易测试**：无界面测试可以只跑状态机，也可以整场跑完并检查状态覆盖。

---

## 一、OODA 四阶段

入口：`scripts/ai/unit_brain.gd`，在 `_physics_process` 里按 `THINK_INTERVAL = 0.16s` 节流。

### 1. Observe 观察

每次思考扫描 `Battle.living_units()`：

| 字段 | 含义 |
| --- | --- |
| `enemies` / `allies` | 当前存活敌人/友军数组 |
| `nearest` / `nearest_distance` | 最近的敌人及中心距离 |
| `average_distance` | 敌人平均距离（预留给后续 AOE/撤退判断） |
| `low_hp_enemy` | 血量比例最低的敌人 |
| `own_hp_ratio` | 自身生命比例 |

观察结果不仅用于决策，也格式化成 HUD 的一行文本：

```text
敌 5 人 / 友 4 人 · 最近 重甲兽人 214px · 自身 100%
```

> MVP 没有视野遮挡和地形：所有存活敌人都在观察范围内。后续可加入
> `detection_range`、射线检测或迷雾，只影响 `_observe()`。

### 2. Judge 判断

对每个敌人计算 0~1 的优先级分数：

```text
score = 0.50 × 距离分          # 越近越高
      + 0.25 × 残血分          # 血量越低越高
      + 0.12 × 威胁分          # 目标 DPS / 140，封顶 1
      + 0.18 × 突袭克制        # 自身是“突袭”且目标是远程
      - 0.08 × 射手避坦        # 自身远程且目标是坦克
      + 0.08 × 目标粘性        # 当前目标，减少来回切换
      + 0.02 × 随机扰动        # 避免完全同分时的僵硬
```

同时计算：

- **近身威胁数**：处于 `max(攻击距离 × 1.2, 190px)` 内的敌人数。
- **威胁度**：`clamp(近身威胁 / 4 + (1 - 自身血量比例) × 0.55, 0, 1)`。

HUD 展示：

```text
优先 死灵法师 · 评分 0.78 · 近身威胁 2 人
```

### 3. Decide 决策

决策分两层：

1. `_judge()` 选出优先目标（沿用距离/残血/威胁/职业权重）；
2. `_select_action()` 从该单位的 `actions` 中选出当前可执行的动作：

```text
没有敌人               -> 待机
目标无效               -> 待机，等待下次观察重新选目标
遍历 actions
  ├─ 冷却未就绪        -> 跳过
  ├─ 目标不在动作范围   -> 跳过
  ├─ 目标类型不匹配     -> 跳过
  ├─ 计算 action.priority + AOE 聚集收益
  └─ 选最高分 ActionPlan(action, target)
没有可用 Action
  ├─ 远程被贴脸        -> KITE
  ├─ 目标在攻击距离内   -> 等待冷却
  └─ 其他              -> 推进
```

决策层还会对候选动作做价值评分：

```text
score = action.priority
      + 伤害 AOE 内敌人数 × 1.5
      + 防御动作缺失生命比例 × 25
```

硬条件（冷却、蓝量、距离、目标类型、动作血量阈值）先过滤；分数相同再比较
`priority`，再按 `actions` 数组顺序稳定决胜。一次只提交一个 ActionPlan，
Action 执行期间 Brain 不再改写计划。

当前内核是一个通用的 `ActionPlan`：

```gdscript
unit.target = target
unit.planned_action = plan.action
unit.intent = Intent.ACTION
unit.intent_reason = "使用 火焰斩击（技能）"
```

HUD 展示：

```text
行动：使用 火焰斩击（技能）
```

> 普攻只是 `actions` 中优先级最低、永远可用的一个 Action。技能、护盾、突进、
> 连续攻击都通过同一套选择逻辑参与竞争，不需要新增 Skill 决策层或 Skill 状态。

### 4. Act 行动

Brain 不直接移动或播放动画，只写 `Unit` 的目标与 `ActionPlan`。真正执行的是状态机当前状态：

- `IdleState`：面向目标、播 idle；根据意图切到 `move` / `action`。
- `MoveState`：按意图推进或后撤；接近时计算个人战斗位。
- `ActionState`：读取 `plan.action`，按动画帧触发 effects（伤害/投射物/AOE/视觉），设置动作冷却。
- `HurtState`：播受击，短暂僵直后回 idle。
- `DeathState`：播死亡、淡出、释放。

HUD 展示：

```text
火焰斩击 → 重甲兽人（冷却 7.58s）
移动 → 兽人（距离 182px）
后撤，重新拉开与 狼人 的距离
原地待机，持续观察
```

---

## 二、有限状态机

实现：`scripts/ai/unit_state_machine.gd` + `scripts/ai/states/*.gd`。
五个状态都是 `unit.tscn` 中 `StateMachine` 下的真实节点：

```text
Unit
└─ StateMachine
   ├─ Idle    (Node + idle_state.gd)
   ├─ Move    (Node + move_state.gd)
   ├─ Action  (Node + action_state.gd)
   ├─ Hurt    (Node + hurt_state.gd)
   └─ Death   (Node + death_state.gd)
```

状态基类 `UnitState` 提供：

```gdscript
func enter(previous: StringName) -> void
func exit() -> void
func update(delta: float) -> void
func can_transition(next: StringName) -> bool
```

`UnitStateMachine` 负责：

- `_ready()` 收集子节点状态并注入 `machine`；
- `setup(unit)` 注入单位并进入 `idle`；
- `_physics_process()` 调用当前状态的 `update()`；
- `transition_to(next, force)` 统一 exit/enter 与信号；
- 死亡是终止状态，禁止再切换。

### 状态转换图

```text
                 ┌──────────────── ActionPlan 可用 ──────────────┐
                 ▼                                                │
  ┌────────┐  意图推进/后撤   ┌────────┐   进入动作范围+Plan     ┌────────┐
  │  Idle  │ ───────────────> │  Move  │ ─────────────────────> │ Action │
  │  待机  │ <─────────────── │  移动  │ <───────────────────── │  行动  │
  └────────┘   意图待机/到位  └────────┘      动画/效果结束       └────────┘
      ▲   ▲                         │                               │
      │   │                         │                               │
      │   └──────── 僵直结束 ───────┼────────── 大伤害打断 ─────────┤
      │                             ▼                               ▼
      │                     ┌────────────┐                  （行动结束回 Idle）
      └───── 僵直结束 ───── │    Hurt    │
                            │    受击    │
                            └────────────┘
                                  │
                                  │ 任意状态生命 ≤ 0（强制）
                                  ▼
                            ┌────────────┐
                            │   Death    │  终止，淡出并 queue_free
                            │    死亡    │
                            └────────────┘
```

### 各状态细节

| 状态 | 进入时 | 每帧 | 退出条件 |
| --- | --- | --- | --- |
| Idle | 重置动画速度，播 `idle` | 面向目标；读 `brain.intent` | ActionPlan 可用 → Action；推进/后撤 → Move |
| Move | 播 `move` | 朝个人战斗位移动/后撤；面向移动方向或目标 | 到位/失去目标/意图待机 → Idle；ActionPlan 可用 → Action |
| Action | 面向目标，播放 `plan.action.animation` | 累计动画时间；按 `trigger_frame` 执行 effects | 动画时长结束 → Idle |
| Hurt | 强制打断当前动作，播 `hurt` | 累计 0.26s | 时间到 → Idle |
| Death | 停用大脑、隐藏血条与队伍环、播 `death` | 无（由 Tween 淡出） | 淡出结束 → `queue_free()` |

### 受击保护

如果每次受击都打断，5v5 混战会变成“永久硬直”。MVP 使用两条保护：

- 只有单次伤害 ≥ `最大生命 × 6.5%` 才触发受击；
- 触发后 `_flinch_cooldown = 1.05s`，期间再受伤只掉血、不再硬直。

更小的伤害只触发 0.09s 的红色闪烁，不打断动作。

### 攻击节奏

`UnitActionState` 直接使用动作动画的帧率和 `trigger_frame`：

```text
duration        = 帧数 / (SpriteFrames FPS × animation_speed)
命中时刻         = trigger_frame / (FPS × animation_speed)
效果             = ActionEffectDefinition（伤害/投射物/视觉）
冷却             = action.cooldown（动作开始时设置）
打断             = Hurt / Death 强制切换，已触发的效果不回滚
```

因此 6 帧的士兵和 15 帧的剑士都能在相近的感知节奏内完成一次攻击，而不会因为素材帧数
不同导致攻速失真。

---

## 三、站位与可读性

AI 只决定“打谁”和“推进/后撤”，站位由 `Unit.desired_combat_position()` 统一计算：

```gdscript
stop    = 攻击距离 + 目标半径 + 自身半径 × 0.35 - 18
lateral = (2 - slot) / 2 × min(50, stop × 0.36)   // 槽位 0~4 → +50..-50
forward = sqrt(stop² - lateral²) × 0.92
desired = 目标位置 + (自身阵营方向 × forward, lateral)
```

效果：

- 同侧 5 人自动沿目标周围散开，形成半包围，而不是叠在同一点。
- 远程因为 `stop` 更大，会自然站在后排。
- `Battle._resolve_separation()` 再做一层圆形软分离（每帧把重叠单位推开 38%），
  避免不同队伍挤成一条线。

---

## 四、Action 系统的扩展路径

当前基础已落地：

- `CombatActionDefinition`：动作元数据、目标类型、动画、范围、冷却、优先级、effects；
- `ActionEffectDefinition`：DAMAGE / PROJECTILE / VISUAL；
- `UnitActionState`：统一的行动状态；
- `UnitBrain._select_action()`：从 `unit.actions` 中选 `ActionPlan`；
- 骑士·火焰斩击：`attack_03` 自带的火焰帧 + 扇形 AOE；不再叠加第二套火焰刀光。
- 骑士·格挡：`block` 动画、1 秒 `GUARD` 状态、期间免疫全部伤害；12 秒冷却、20 蓝耗。

继续扩展时：

1. **新技能**：新增一个 `CombatActionDefinition` 资源，加入对应英雄的 `actions`；
2. **护盾/状态**：增加 `SHIELD` / `STATUS` effect 与 Unit 状态组件；
3. **突进/位移**：增加 `DISPLACE` effect 或 action motion；
4. **连续攻击**：同一 Action 配置多个不同 `trigger_frame` 的 DAMAGE；
5. **特殊逻辑**：只有数据表达不了的技能才增加自定义 ActionLogic，不复制单位场景；
6. **UI**：OODA 镜已显示状态/动作名/冷却，可继续扩展冷却条和技能列表。

当前已接入骑士火焰斩击，其他英雄仍只有自动生成的 `basic_attack` Action。
## 五、调试与测试

- **OODA 观察镜**：战斗中点击任意单位，左下角实时显示：
  状态徽章、生命、蓝量、攻击范围、技能范围、目标、冷却和 OODA 文本；
  选中单位的范围环默认关闭，通过右下角「范围」按钮或 `Tab` 开关；
  打开后显示基础攻击范围（蓝圈）和技能范围（橙色虚线圈）。
- **暂停/变速**：`空格`暂停、`F`变速，便于观察 AI 在某一帧的选择。
- **自动化测试**：
  - `tests/test_runner.tscn` 116 项检查；
  - `tools/soak_test.tscn` 8 场随机阵容，检查卡死与胜负分布。
- **可调参数**：
  - `UnitBrain.THINK_INTERVAL`：思考频率；
  - `UnitBrain._score_target()`：目标权重；
  - `Unit._flinch_cooldown`、`take_damage()` 的 6.5% 阈值：受击手感；
  - `Battle._resolve_separation()` 的 0.86 / 0.38：拥挤程度；
  - `Unit.desired_combat_position()` 的 lateral / forward 公式：包围圈宽度；
  - `UnitDefinition` 的 `attack_windup`、`attack_range`、`move_speed`。

---

## 六、已知取舍

- 没有视野、寻路、障碍；AI 是“全图感知 + 直线移动”。
- 目标评分是手调权重，不做学习；对局平衡由数值和阵容决定。
- 投射物锁定目标，不做弹道预判/闪避。
- 远程后撤只按空间向量，不做绕柱或侧移；贴边时会停下。
- 目前只实现火焰斩击与格挡；护盾、位移、召唤等 effect 类型尚未实现。法力仅有基础蓝池、回复与技能消耗。
