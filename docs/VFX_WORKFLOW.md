# 特效工作流：pixelfx → Godot

1. 用 `node tools/list.mjs <关键词>` 在 pixelfx 中找参考，先渲染对照。做新稿时按 pixelfx 的 `docs/AUTHORING.md` 定义调色板、时间轴、原点和分层。
2. 渲染联系表及连续动作，检查实尺寸可读性、关键帧和循环接缝，再修改重看。用 pixelfx 的 `tools/check.mjs` 校验特效源（自定义效果可用薄模块导出 `meta`、`draw`、`drawBack`、`act` 供检查）。
3. 将生成的透明图集放在 `assets/fx/pixelfx/`；提交可复现的源或库效果 ID 和导出脚本。Godot 用最近邻采样，按图集帧率和原点播放，必要时拆前后景。特效不参与伤害、范围、状态或冷却结算。
4. 在英雄试炼场看实机位置、尺度、遮挡和状态结束；状态类至少验证施加时开始、移除时停止。

## 示例：盔甲护身

`tools/armor_guard_fx.mjs` 保存特效源。`tools/export_armor_guard_fx.mjs` 以脚底 `(36, 47)` 为原点，以 24 FPS 把 15 帧扣合和 60 帧环绕合入前后两张图集；Godot 重复播放环绕段，扣合段不重播。

从游戏仓库根目录运行（Node.js 18+，`ffmpeg` 可选，用于 GIF）：

```sh
PIXELFX_DIR=/path/to/pixelfx node tools/export_armor_guard_fx.mjs /tmp/armor-guard-preview
PIXELFX_DIR=/path/to/pixelfx node tools/export_armor_guard_fx.mjs
godot --path . res://tools/armor_guard_capture.tscn --resolution 1600x900
```


## 四名单位的技能资源

`tools/export_roster_skill_fx.mjs` 记录骷髅弓箭手、史莱姆、牧师和法师使用的 pixelfx 效果 ID、调色和取帧。牧师圣光弹的圆形弹芯、柔和尾迹和循环时序在 `tools/holy_bolt_fx.mjs`。可单独运行 `node tools/export_roster_skill_fx.mjs --effect holy_bolt` 重生成弹道资源。范围脉冲源在 `tools/roster_ground_pulse.mjs`，Godot 按技能的结算半径将它贴到战场地面。弹道和命中场景以序列帧原点分别对齐武器与目标，并在英雄试炼场按实际比例检查。

祈福使用 pixelfx 的 `holy/heal`。图集仅保留花瓣、光环和粒子，跳过角色重绘层。Godot 以受治疗者的脚底为起点，按立绘高度与体宽缩放光环。可用 `node tools/export_roster_skill_fx.mjs --effect blessing` 重新导出。

圣光普照参考 pixelfx 的 `holy/heal-aoe`（Healing ring）。`tools/sanctuary_fx.mjs` 将向外扩散的光环与治疗十字合成一张俯视图集。Godot 以治疗结算点为中心，按技能半径缩放后贴在战场地面，由场景相机投影。试炼场把显示裁在后墙内侧的地面。可用 `node tools/export_roster_skill_fx.mjs --effect sanctuary` 重新导出。

火球术的弹体沿用 pixelfx 的 `fire/fireball`，放大火核并加长拖尾，可用 `node tools/export_roster_skill_fx.mjs --effect fireball` 重生成。落地复用火焰命中序列，在同一落点叠加与结算半径一致的 pixelfx 地面脉冲。可用 `node tools/export_roster_skill_fx.mjs --effect fire_landing` 重新导出脉冲图集。

冰封术的冰壳改编自 pixelfx 的 `ice/freeze`。按竞技场的 1.5 秒冰冻节奏重新取帧，图集保留冰壳和碎冰层，由 Godot 按目标脚底和立绘尺寸定位。冰冻结束时播放碎冰。可运行 `node tools/export_freeze_status_fx.mjs` 重生成图集，传入预览目录可生成联系表和动图。

雷暴用 pixelfx 的 `lightning/storm-cloud` 与 `lightning/lightning-strike`。`tools/wizard_storm_cloud_fx.mjs` 改编了前者的云团密度与光照，生成错落的云顶、波浪状云底和云内闪光。落雷图集取单次主雷击的短帧段。Godot 在固定圆域上方播放云层，每次结算时把闪电接到实际落点。范围圈图集使用本项目的地面脉冲。用 `node tools/export_lightning_storm_fx.mjs` 可重生成三个图集，传入预览目录可生成联系表和动图。雷声用 `node tools/export_roster_skill_audio.cjs roster_thunder_strike` 重生成。

`assets/audio/skills/sources.json` 的 `roster_` 记录使用 Jsfxr Pro 参数格式。导出脚本用 Jsfxr 1.4.1 的合成器渲染各层，按设定的时间偏移和峰值合成 WAV。参数可以在 [Jsfxr Pro](https://pro.sfxr.me/) 中编辑。

```sh
PIXELFX_DIR=../pixelfx node tools/export_roster_skill_fx.mjs /tmp/roster-fx-preview
PIXELFX_DIR=../pixelfx node tools/export_roster_skill_fx.mjs
npm install --prefix /tmp/arena-sfx jsfxr@1.4.1
JSFXR_DIR=/tmp/arena-sfx/node_modules/jsfxr node tools/export_roster_skill_audio.cjs
```
