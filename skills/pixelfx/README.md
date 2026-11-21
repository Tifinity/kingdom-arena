# pixelfx skill（本地安装）

上游：[patch-gg/pixelfx](https://github.com/patch-gg/pixelfx)（MIT）。`SKILL.md` 为原样拷贝，
改动它会给后续升级带来冲突；要改行为请在上游仓库里改，再重新拷贝。

## 本地环境

- 将 pixelfx 检出放在游戏仓库的相邻目录 `../pixelfx`。
- 在 pixelfx 检出中运行 `node tools/render.mjs fire/torch` 自检。工具链只用 Node，联系表输出到 `records/<category>/<id>/contact.png`。GIF 和 MP4 预览需要 ffmpeg。

## DSH 如何发现它

DSH 的技能发现根目录（见 skill-filesystem）：

| 顺序 | 根目录 |
|---|---|
| 100 | `<项目>/.dsh/skills` |
| 200 | `<项目>/.agents/skills` |
| 400 | `~/.dsh/skills` |
| 500 | `~/.agents/skills` |

因此 `.dsh/skills/pixelfx` 是指向本目录（`../../skills/pixelfx`）的相对符号链接，
`skills/pixelfx` 才是唯一真源。移动或重命名本目录后，重建该链接即可。

## 升级

```bash
cp ../pixelfx/skills/pixelfx/SKILL.md skills/pixelfx/SKILL.md
```
