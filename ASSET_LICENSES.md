# 素材来源与许可

本项目已公开到 GitHub。第三方素材的使用与授权状态记录如下。
如需单独再分发素材或商用，请以原作者的许可条款和购买凭证为准。

## 1. 角色与投射物：Tiny RPG Character Asset Pack 01 v2.0

- 来源目录（用户于 2026-11 提供）：
  `~/Downloads/Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/`
- 使用范围：
  - 除士兵外的 21 名角色的逐动作 PNG（`Characters(100x100 split)/<角色>/<角色>/*.png`），
    复制到 `assets/characters/<slug>/`，保留待机、行走、攻击、受击、死亡等全部逐动作帧；
  - 箭矢 `Arrow(Projectile)/Arrow01(32x32).png`，复制为 `assets/projectiles/arrow.png`。
  - 法师冰封和火球 `Magic(Projectile)/Wizard_Attack01_Effect.png`、`Wizard_Attack02_Effect.png`，分别复制为 `assets/projectiles/wizard_ice.png`、`wizard_fireball.png`。
- 派生：
  - `assets/portraits/*.png` 由各角色待机动画首帧自动裁切/最近邻放大生成；
  - `assets/projectiles/magic_orb.png`、`assets/ui/soft_shadow.png`、`assets/ui/spark.png`
    由 `tools/build_assets.py` 程序化生成。
- 授权状态：**项目作者已确认该素材包为本人于 itch.io 购买的授权素材，并同意在本项目及其公开 GitHub 仓库中使用。**
  源目录未附许可文件，具体授权范围以 itch.io 购买记录和原作者条款为准。
- 仓库内只保留本项目实际引用的逐动作文件，不包含完整素材包/Aseprite 源文件；
  截图 `artifacts/*.png` 同样只包含项目内使用的素材。
- 请保留购买凭证；不要把完整素材包作为独立资源再分发。若未来要商用或单独分发素材，
  需再次核对原作者条款。

### 士兵无影子动画

- 来源：`~/Downloads/Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc/Characters(100x100)/Soldier/Soldier/Soldier-*.png`。
- 使用范围：士兵待机、行走、三段攻击、受击、死亡共 7 条动画。原付费包中士兵的“Soldier”和“Soldier with shadows”逐动作 PNG 相同；项目和付费包 `Soldier/Soldier` 的 PNG 已换成免费版无影子图，付费包 `Soldier with shadows` 保留原图。

## 2. 字体：Fusion Pixel Font 12px

- 路径：`assets/fonts/fusion-pixel-12px-zh_hans.woff2`
- 来源：TakWolf / fusion-pixel-font（https://github.com/TakWolf/fusion-pixel-font）
- 许可证：SIL Open Font License 1.1
  - `assets/fonts/OFL-fusion-pixel.txt`
  - 内嵌字体许可：`assets/fonts/fusion-pixel-licenses/`（Ark Pixel / Cubic 11 / Galmuri 等）
- 用法：项目全局 UI 字体（`project.godot` 的 `gui/theme/custom_font`），
  字号使用 9 / 10 / 11 / 12 / 14 / 16 / 18 / 20 / 22 / 24 / 26 / 30 / 44 / 52 / 96 等整数，
  导入时关闭抗锯齿、hinting 与亚像素定位以保持像素风清晰。

## 3. 本项目新写内容

- 全部 GDScript、`.tscn`、`.tres`、`.gdshader`（`scripts/`、`scenes/`、`resources/`、`shaders/`、`tests/`、`tools/`）
  为本次新写。
- 程序化生成的图像：头像裁切、法术球、阴影、像素点、项目图标。
- 竞技场背景、UI 面板、法阵、战旗、火把等由 Godot 2D 绘图 API / StyleBoxFlat 运行时绘制。

## 4. 架构参考

实现过程中参考了同机项目《波比竞技场》《部落大战》的工程组织方式（资源驱动数据、
场景拆分、HUD 分层、无界面测试），以及 Godot 官方文档推荐做法；
未复制其业务代码或专有数据。

## Pixelfx 牧师特效

- `assets/fx/pixelfx/holy_laser_bolt.png`：`projectiles/laser-bolt`，holy palette。
- `assets/fx/pixelfx/heal.png`：`holy/heal`，heal palette；仅导出特效层，未包含示例角色。
- `assets/fx/pixelfx/healing_ring.png`：`holy/heal-aoe`（Healing ring）。
- `assets/fx/pixelfx/arrow_rain_volley_back.png`、`arrow_rain_volley_front.png`：`bows/arrow-rain-volley`，25 帧、30 FPS。预警圈与箭矢分层导出，精灵表半径为 70 像素。
- 箭雨导出命令：`PIXELFX_DIR=../pixelfx node tools/pixelfx_split_layers.mjs bows/arrow-rain-volley --out assets/fx/pixelfx/arrow_rain_volley`。
- `assets/fx/pixelfx/archer_piercing_arrow.png`：`bows/piercing-arrow-line`，13 帧、30 FPS。用 pixelfx 的 `node tools/render.mjs bows/piercing-arrow-line --sheet` 导出。
- `assets/fx/pixelfx/slow_step_back.png`、`slow_step_front.png`：`status/slow-step`，48 帧、30 FPS。导出命令为 `PIXELFX_DIR=../pixelfx node tools/pixelfx_split_layers.mjs status/slow-step --out assets/fx/pixelfx/slow_step`。
- `assets/fx/pixelfx/haste_step_back.png`、`haste_step_front.png`：`status/haste-step`，48 帧、30 FPS。导出命令为 `PIXELFX_DIR=../pixelfx node tools/pixelfx_split_layers.mjs status/haste-step --out assets/fx/pixelfx/haste_step`。
- `assets/fx/pixelfx/stat_badges.png`：`status/stat-badges`，12 帧、12 FPS。用 pixelfx 的 `node tools/render.mjs status/stat-badges --sheet` 导出。
- 来源：[patch-gg/pixelfx](https://github.com/patch-gg/pixelfx)，MIT License。

## Pixelfx 圣殿骑士特效

- 圣殿骑士的 `attack02.png`、`attack03.png` 仅从授权素材的 Aseprite 源文件导出 `body` 图层。两招的剑气由 pixelfx 特效单独播放。
- `assets/fx/pixelfx/templar_holy_blade.png`：`melee/radiant-wave` 的金色剑气，仅导出释放后的特效帧。
- `assets/fx/pixelfx/aegis_ring_ground.png`：用 pixelfx 绘制的正圆俯视法阵，投影由游戏相机完成。
- 导出命令：`PIXELFX_DIR=../pixelfx node tools/export_templar_fx.mjs`。
- 来源：[patch-gg/pixelfx](https://github.com/patch-gg/pixelfx)，MIT License。剑气的发光边缘和渐暗轨迹改编自 [Sprite Fusion 的 Slash](https://www.spritefusion.com/pixel-art-vfx/slash)（MIT License, Copyright (c) 2026 Hugo Duprez）。

## Pixelfx 熊人震落

- 熊人的 `attack03.png` 仅从授权素材的 Aseprite 源文件导出 `body` 图层，落地特效由 pixelfx 播放。
- `assets/fx/pixelfx/ground_pound_25d_ground.png` 和 `ground_pound_25d_air.png` 来自本地 pixelfx 的 `moves/ground-pound-perspective`，55 帧、30 FPS、每帧 196×204。
- 在 pixelfx 运行 `node tools/render.mjs moves/ground-pound-perspective --sheet --no-actor`。地面层传入 `--opts '{"depth":1,"layer":"ground"}'`，空中层传入 `--opts '{"layer":"air"}'`。Godot 会用战场相机投影地面层。

## Pixelfx 眩晕、重击与普攻命中特效

- `assets/fx/pixelfx/stunned.png` 来自 pixelfx 的 `status/stunned`。图集为每帧 60×64 像素、8 列、30 FPS、60 帧循环。在 pixelfx 检出中运行 `node tools/render.mjs status/stunned --sheet`，将 `records/status/stunned/stunned.png` 复制到游戏资源目录。
- 眩晕、重击和普攻命中特效的完整许可见 [Stunned](assets/status/STUNNED_LICENSE.md)、[Heavy cleave](assets/FX_HEAVY_CLEAVE_LICENSE.md) 和 [Hit spark](assets/HIT_SPARK_LICENSE.md)。
- `assets/fx/pixelfx/freeze_status.png` 来自 pixelfx 的 `ice/freeze`。游戏图集为 64 帧、30 FPS，改编保留结霜、封冰和碎冰阶段。碎冰手法的上游来源使用 MIT License，Copyright (c) 2026 Hugo Duprez。[pixelfx](https://github.com/patch-gg/pixelfx) · [Sprite Fusion Ice](https://www.spritefusion.com/pixel-art-vfx/ice)
- 雷暴的云层和落雷来自 pixelfx 的 `lightning/storm-cloud` 与 `lightning/lightning-strike`。源效果的闪电画法源自 Sprite Fusion，MIT License，Copyright (c) 2026 Hugo Duprez。[pixelfx](https://github.com/patch-gg/pixelfx) · [Sprite Fusion Lightning](https://www.spritefusion.com/pixel-art-vfx/lightning)

## Pixelfx 高压水枪特效

- `assets/fx/water/` 包含五套独立特效的图集、帧数据、预览和源码。使用方法、重新导出命令与署名见 [素材说明](assets/fx/water/README.md)。

## 攻坚模式基地

- 圆塔来自 CodeLaboratory 的 [Pixel Tower Defenders Asset Pack](https://codelaboratory.itch.io/pixel-tower-defenders-asset-pack)。作者允许用于游戏（包括商业游戏），禁止原样转售素材。
- 项目收录该塔的单张裁切 `artifacts/main_base_tower_source.png`，使用 pixelfx 重着色为蓝红阵营图集 `assets/fx/pixelfx/main_base_tower.png`。
- 从项目根目录运行 `PIXELFX_DIR=../pixelfx node tools/export_main_base_tower.mjs` 可重新导出。需要 Python 3 和 Pillow。
