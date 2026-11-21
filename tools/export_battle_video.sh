#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  fail "用法：tools/export_battle_video.sh 对阵.json [成片.mp4]"
fi

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
config_path="$(cd -- "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")"
[[ -f "$config_path" && -r "$config_path" ]] || fail "无法读取对阵配置：$config_path"
output="${2:-${config_path%.*}.mp4}"
[[ "$output" == *.mp4 ]] || fail "成片路径必须以 .mp4 结尾"
output_dir="$(cd -- "$(dirname -- "$output")" && pwd -P)"
output_path="$output_dir/$(basename -- "$output")"
[[ ! -e "$output_path" && ! -L "$output_path" ]] || fail "成片已存在：$output_path"

godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
  if command -v godot >/dev/null; then
    godot_bin=godot
  elif command -v godot4 >/dev/null; then
    godot_bin=godot4
  else
    godot_bin=/Applications/Godot.app/Contents/MacOS/Godot
  fi
fi
ffmpeg_bin="${FFMPEG_BIN:-ffmpeg}"
command -v "$godot_bin" >/dev/null || fail "找不到 Godot。请设置 GODOT_BIN。"
command -v "$ffmpeg_bin" >/dev/null || fail "找不到 FFmpeg。请设置 FFMPEG_BIN。"
[[ -d "$project_dir/.godot/imported" ]] || fail "请先打开 Godot 项目，或在项目根目录运行 Godot --headless --path . --import。"

temp_dir="$(mktemp -d "$output_dir/.battle-video.XXXXXX")"
trap 'rm -rf -- "$temp_dir"' EXIT
capture_project="$temp_dir/project"
mkdir "$capture_project"

# Movie Maker 在场景启动前读取录制尺寸。通过临时项目启用专用画面配置，
# 原工程设置与对阵配置的项目指纹继续使用同一份源码。
for entry in project.godot icon.svg icon.svg.import .godot assets resources scenes scripts shaders tools; do
  ln -s "$project_dir/$entry" "$capture_project/$entry"
done
cat > "$capture_project/override.cfg" <<'CFG'
[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/aspect="keep"

[editor]
movie_writer/mjpeg_quality=0.92
CFG

printf '%s\n' "正在渲染 1080p / 60 fps 对战，请保持录制窗口打开。"
record_exit=0
"$godot_bin" --path "$capture_project" --windowed --resolution 1280x720 \
  --disable-vsync --fixed-fps 60 --write-movie "$temp_dir/battle.avi" \
  res://tools/battle_video_capture.tscn -- --run "$config_path" "$temp_dir/result.json" || record_exit=$?
if [[ "$record_exit" -ne 0 && "$record_exit" -ne 2 ]]; then
  fail "Godot 录制失败（退出码 ${record_exit}）。"
fi
[[ -s "$temp_dir/result.json" && -s "$temp_dir/battle.avi" ]] || fail "录制在结算前结束。"

printf '%s\n' "正在编码 MP4。"
"$ffmpeg_bin" -nostdin -hide_banner -loglevel error -xerror -i "$temp_dir/battle.avi" \
  -map 0:v:0 -map '0:a:0?' -c:v libx264 -preset fast -crf 17 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -movflags +faststart "$temp_dir/battle.mp4"
ln "$temp_dir/battle.mp4" "$output_path" || fail "无法发布成片：$output_path"
printf '成片已保存到 %s\n' "$output_path"
