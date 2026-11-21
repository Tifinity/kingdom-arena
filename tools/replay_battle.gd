extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const USAGE := "用法：-- --create 对阵.json 或 -- --run 对阵.json 结果.json"

var _battle: Battle
var _result_path: String


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--create":
		var config := BattleReplayConfig.from_setup()
		var error := config.save(args[1])
		if error != OK:
			_fail("保存配置失败：%s" % error_string(error))
			return
		print("已保存对阵 %s，种子 %d" % [args[1], config.seed])
		get_tree().quit()
		return
	if args.size() != 3 or args[0] != "--run":
		_fail(USAGE)
		return
	var config_path := ProjectSettings.globalize_path(args[1]).simplify_path()
	_result_path = ProjectSettings.globalize_path(args[2]).simplify_path()
	if config_path == _result_path:
		_fail("结果路径必须与对阵配置路径不同")
		return
	var loaded := BattleReplayConfig.read(config_path)
	if loaded.has("error"):
		_fail(loaded["error"])
		return
	if Engine.physics_ticks_per_second != BattleReplayConfig.TICKS_PER_SECOND:
		_fail("当前物理频率与对阵配置不一致")
		return
	_battle = BATTLE_SCENE.instantiate()
	_battle.replay_config = loaded["config"]
	_battle.battle_finished.connect(_on_battle_finished)
	add_child(_battle)


func _on_battle_finished(winner: int) -> void:
	var result := _battle.replay_result.duplicate()
	result["config"] = _battle.replay_config.to_dict()
	result["events"] = _battle.replay_events
	var error := BattleReplayConfig.write_json(_result_path, result)
	if error != OK:
		_fail("写入战斗结果失败：%s" % error_string(error))
		return
	print("对阵结束，胜方 %d，物理帧 %d，结果 %s" % [winner, result["tick"], _result_path])
	get_tree().quit(2 if result["reason"] == "timeout" else 0)


func _fail(message: String) -> void:
	printerr(message)
	get_tree().quit(1)
