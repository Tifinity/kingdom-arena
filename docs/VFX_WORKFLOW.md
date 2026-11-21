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
