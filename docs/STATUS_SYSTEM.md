# 异常状态系统

> 状态表现图标目前使用 `assets/status/*.png` 占位，后续直接替换同名图片即可。

## 分层

```text
ActionEffectDefinition
  └─ status_id / status_kind
        ↓ 由 StatusCatalog 解析
StatusDefinition（resources/status/*.tres）
  ├─ tags / 持续时间 / 叠加规则 / 图标
  ├─ behavior（Control / Dot / StatModifier / 自定义）
  └─ vfx_scene
        ↓ 施加
StatusInstance（每次施加的运行时实例）
        ↓ 由
UnitStatusController（单位节点）
  ├─ 叠加、Tick、属性修正、VFX
  ├─ can_move / can_act / can_use_skill
  └─ changed 信号 → HUD 状态图标
```

核心原则：

- **Definition 是共享数据**，不保存剩余时间、层数或来源。
- **Instance 保存一次施加的运行时状态**，包括 source、remaining、stacks、tick_accum。
- **Behavior 决定状态如何生效**，Controller 只负责公共生命周期。
- **Unit/FSM 不判断具体状态名**，只查询 `can_move / can_act / can_use_skill`。

## 当前状态与叠加规则

| 状态 | id | tags | 行为 | 叠加规则 | 关键参数 |
| --- | --- | --- | --- | --- | --- |
| 眩晕 | `stun` | control / stun | ControlBehavior | 刷新，不叠层 | 0.9~1 秒，打断动作 |
| 减速 | `slow` | debuff / slow | StatModifierBehavior | 只取最强（倍率最低） | 默认 0.55 倍移速 |
| 流血 | `bleed` | dot / bleed / physical | DotBehavior | 只取最强 DPS | 0.5 秒 Tick，吃护甲 |
| 燃烧 | `burn` | dot / burn / fire | DotBehavior | 只取最强 DPS | 0.5 秒 Tick，无视护甲 |
| 中毒 | `poison` | dot / poison | DotBehavior | 叠层，上限 5 层 | 按最大生命值，无视护甲/护盾；满层立即结算剩余全部伤害并移除 |

### 叠加规则实现

- `REFRESH`：`remaining = max(remaining, duration)`，例如眩晕。
- `STRONGEST`：比较 `power`，只保留更强的一次；流血/燃烧是更高 DPS，减速是更低的移速倍率。
- `STACK`：增加层数并刷新持续时间；达到 `max_stacks` 时调用 Behavior 的 `on_max_stacks()`。
- 中毒的 `on_max_stacks()` 计算“剩余 Tick 数 × 当前每 Tick 伤害”，立即结算后移除状态。

## 扩展新状态

1. 在 `resources/status/` 新增一个 `StatusDefinition` 资源。
2. 选择已有 Behavior：
   - 控制：`ControlBehavior`
   - 持续伤害：`DotBehavior`
   - 属性修改：`StatModifierBehavior`
3. 需要独特机制时，新增一个 `StatusBehavior` 子类，并实现 `on_apply / on_tick / on_expire / on_max_stacks`。
4. 在 `StatusDefinition.icon` 配置图标，在 `vfx_scene` 配置可选表现。
5. 技能中通过 `ActionEffectDefinition.status_id` 引用，例如 `&"poison"`。

旧数据仍可使用 `status_kind`（0 眩晕、1 减速、2 流血、3 燃烧），`StatusCatalog` 会自动映射到对应 definition。

## 代码位置

```text
scripts/autoload/status_catalog.gd
scripts/status/status_definition.gd
scripts/status/status_instance.gd
scripts/status/status_behavior.gd
scripts/status/unit_status_controller.gd
scripts/status/behaviors/control_behavior.gd
scripts/status/behaviors/dot_behavior.gd
scripts/status/behaviors/stat_modifier_behavior.gd
resources/status/*.tres
assets/status/*.png          # 占位图标
```

## 战斗内表现

- 被眩晕的单位会立即中断动作、进入受击动画，头顶显示三颗金色星星。
- 流血、燃烧、中毒目前通过 HUD 状态图标显示；后续可在 `StatusDefinition.vfx_scene` 添加对应特效。
- HUD 在 OODA 观察镜的生命值下方显示状态图标、叠层和剩余时间提示。
