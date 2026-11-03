# 单位 AI：OODA 决策 + 有限状态机

本文记录 `王国竞技场` MVP 的单位行为设计。目标不是“让单位互殴”，而是把
**感知、判断、执行**拆成可观察、可测试、可扩展的三层：

```text
每 0.16s ─────────────┐
                      ▼
              ┌───────────────┐
              │  UnitBrain    │  OODA：观察 → 判断 → 决策 → 行动
              │  （想）        │  只写 target / intent / 文本
              └───────┬───────┘
                      │ 目标 + 意图
                      ▼
每物理帧 ────> ┌───────────────┐
              │ UnitStateMachine │  当前状态节点执行
              │ Idle/Move/      │  动画、移动、起手、伤害
              │ Attack/Hurt/    │
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

决策树（优先级从高到低）：

```text
没有敌人               -> 待机
目标无效               -> 待机，等待下次观察重新选目标
目标在攻击距离内
  ├─ 普攻冷却就绪      -> 攻击
  ├─ 自身远程且被贴脸  -> 拉开距离（KITE）
  └─ 其他              -> 待机，等待冷却
目标在攻击距离外
  ├─ 自身远程且被贴脸  -> 拉开距离
  └─ 其他              -> 推进
```

远程“被贴脸”阈值是 `自身攻击距离 × 0.42`。例如弓箭手射程 340px，
敌人在 143px 内时会后撤；移动状态在距离达到 72% 射程后停下重新攻击。
近战没有后撤，只有推进与攻击。

决策结果写入：

```gdscript
unit.target = target
unit.intent = Intent.ATTACK / ADVANCE / KITE / IDLE
unit.intent_reason = "目标进入攻击距离，普攻就绪"
```

HUD 展示：

```text
攻击：目标进入攻击距离，普攻就绪
```

### 4. Act 行动

Brain 不直接移动或播放动画，只写 `Unit` 的目标与意图。真正执行的是状态机当前状态：

- `IdleState`：面向目标、播 idle；根据意图切到 `move` / `attack`。
- `MoveState`：按意图推进或后撤；接近时计算个人战斗位。
- `AttackState`：播攻击动画，起手计时到点后结算伤害/生成投射物。
- `HurtState`：播受击，短暂僵直后回 idle。
- `DeathState`：播死亡、淡出、释放。

HUD 展示：

```text
普通攻击 → 死灵法师（冷却 0.00s）
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
   ├─ Attack  (Node + attack_state.gd)
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
                 ┌──────────────── 攻击冷却中就绪 ────────────────┐
                 ▼                                                │
  ┌────────┐  意图推进/后撤   ┌────────┐   进入攻击距离+就绪   ┌────────┐
  │  Idle  │ ───────────────> │  Move  │ ─────────────────────> │ Attack │
  │  待机  │ <─────────────── │  移动  │ <───────────────────── │  攻击  │
  └────────┘   意图待机/到位  └────────┘      动画/冷却结束       └────────┘
      ▲   ▲                         │                               │
      │   │                         │                               │
      │   └──────── 僵直结束 ───────┼────────── 大伤害打断 ─────────┤
      │                             ▼                               ▼
      │                     ┌────────────┐                  （攻击结束回 Idle）
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
| Idle | 重置动画速度，播 `idle` | 面向目标；读 `brain.intent` | 攻击就绪 → Attack；推进/后撤 → Move |
| Move | 播 `move` | 朝个人战斗位移动/后撤；面向移动方向或目标 | 到位/失去目标/意图待机 → Idle；可攻击 → Attack |
| Attack | 面向目标，播 `attack_01`；根据起手时间调整动画速度 | 累计时间；到 `attack_windup` 时结算一次伤害 | 动画时长结束 → Idle |
| Hurt | 强制打断当前动作，播 `hurt` | 累计 0.26s | 时间到 → Idle |
| Death | 停用大脑、隐藏血条与队伍环、播 `death` | 无（由 Tween 淡出） | 淡出结束 → `queue_free()` |

### 受击保护

如果每次受击都打断，5v5 混战会变成“永久硬直”。MVP 使用两条保护：

- 只有单次伤害 ≥ `最大生命 × 6.5%` 才触发受击；
- 触发后 `_flinch_cooldown = 1.05s`，期间再受伤只掉血、不再硬直。

更小的伤害只触发 0.09s 的红色闪烁，不打断动作。

### 攻击节奏

`AttackState` 不使用固定延迟，而是把 SpriteFrames 的动画帧率、起手时间统一换算：

```text
base_duration   = 帧数 / 动画速度
target_duration = clamp(base_duration, 0.36, 0.75)
target_duration = max(target_duration, attack_windup + 0.16)
speed_scale     = base_duration / target_duration
命中时刻         = attack_windup（可被受击/死亡打断）
冷却             = 1 / attack_speed（命中时开始计时）
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

## 四、扩展技能的路径

当前 `AttackState` 只接入了 `attack_01` 普攻，但它是“动作参数化”的。加技能可以按以下步骤：

1. **数据**：为技能增加 `CombatAction` 资源（或扩展 `UnitDefinition`），至少包含
   `animation`、`windup`、`damage_ratio`、`cooldown`、`range`、`projectile`、`mana_cost`。
2. **决策**：在 `UnitBrain._decide()` 中，攻击/推进之前插入技能条件，例如
   “蓝量足够且目标是低血量 → SKILL”；`Intent` 增加 `SKILL`。
3. **状态**：新增 `SkillState` 节点，或让 `AttackState.enter()` 接收 action 参数：
   - 播技能动画；
   - 在起手帧生成 AOE/投射物/治疗；
   - 设置技能冷却与蓝耗；
   - 结束后回 Idle。
4. **UI**：在 `battle_hud.tscn` 增加蓝条/技能冷却条，观察镜的行动行显示技能名。
5. **素材**：素材包已包含 `attack_02`、`attack_03`、`block`、`summon` 等动画，
   `SpriteFrames` 生成时已保留这些片段（`resources/visuals/*.tres`），可直接用。

MVP 不接入技能，是为了先验证“观察/判断/决策/行动 + 状态机 + 资源驱动”这条主链路。

---

## 五、调试与测试

- **OODA 观察镜**：战斗中点击任意单位，左下角实时显示：
  状态徽章、生命、目标、冷却、观察文本、判断文本、决策文本、行动文本。
- **暂停/变速**：`空格`暂停、`F`变速，便于观察 AI 在某一帧的选择。
- **自动化测试**：
  - `tests/test_runner.tscn` 91 项检查；
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
- 技能、控制链、驱散等复杂状态未实现，但状态机与动作参数已经预留了扩展位。
