extends Node

signal busy_changed(busy: bool)
signal finished(path: String, error: String)

const EXPORT_SCRIPT := "res://tools/export_battle_video.sh"
const BASH := "/bin/bash"
const JOB_DIRECTORY := "user://video-export"
const LAUNCH := """
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
export GODOT_BIN="$1"
trap 'rm -- "$3"' EXIT
/bin/bash "$2" "$3" "$4" > "$5" 2>&1
"""

var _pid := -1


func is_available() -> bool:
	return not OS.has_feature("template") and (OS.has_feature("macos") or OS.has_feature("linux")) \
			and FileAccess.file_exists(BASH) and FileAccess.file_exists(EXPORT_SCRIPT)


func is_busy() -> bool:
	return _pid > 0


## 启动成功时返回空字符串。录制进程拥有临时对阵文件，无需依赖当前场景存活。
func start(config: BattleReplayConfig, path: String) -> String:
	if not is_available():
		return "游戏内录像需要在 macOS 或 Linux 上从 Godot 工程运行。"
	if is_busy():
		return "已有一场战斗正在导出。"
	if not path.to_lower().ends_with(".mp4"):
		path += ".mp4"
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		return "该文件名已存在。请选择新的保存位置。"
	var directory := ProjectSettings.globalize_path(JOB_DIRECTORY)
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return "无法准备录像目录：%s" % error_string(error)
	var job := directory.path_join("arena-video-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var match_path := job + ".json"
	var log_path := job + ".log"
	error = config.save(match_path)
	if error != OK:
		return "无法准备对阵：%s" % error_string(error)

	_pid = OS.create_process(BASH, [
		"-c", LAUNCH, "arena-video-export", OS.get_executable_path(),
		ProjectSettings.globalize_path(EXPORT_SCRIPT), match_path, path, log_path,
	])
	if not is_busy():
		DirAccess.remove_absolute(match_path)
		return "无法启动录像进程。"
	busy_changed.emit(true)
	_watch(path, log_path)
	return ""


func _watch(path: String, log_path: String) -> void:
	while OS.is_process_running(_pid):
		await get_tree().create_timer(0.25, true, false, true).timeout
	var exit_code := OS.get_process_exit_code(_pid)
	_pid = -1
	busy_changed.emit(false)
	if exit_code == 0 and FileAccess.file_exists(path):
		DirAccess.remove_absolute(log_path)
		finished.emit(path, "")
		return
	var lines := FileAccess.get_file_as_string(log_path).strip_edges().split("\n", false)
	var detail := lines[-1].strip_edges() if not lines.is_empty() else "录制进程提前结束。"
	finished.emit(path, "%s\n\n日志：%s" % [detail, log_path])
