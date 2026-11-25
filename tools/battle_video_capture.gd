extends "res://tools/replay_battle.gd"

const RESULT_HOLD_SECONDS := 2.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("视频采集需要 Godot Movie Maker，请通过 tools/export_battle_video.sh 启动")
		return
	super._ready()
	if _battle == null:
		return

	var hud := _battle.hud
	_battle.set_process_unhandled_input(false)
	hud.set_process_unhandled_input(false)
	hud.hint_label.hide()
	hud.phase_label.hide()
	hud.get_node("Root/Controls").hide()
	for column in hud.roster_columns:
		column.hide()

	var result_panel := hud.result_root.get_node("CenterBox/Panel") as PanelContainer
	var content := result_panel.get_node("Margin/VBox")
	content.get_node("Buttons").hide()
	content.get_node("Spacer2").hide()
	result_panel.custom_minimum_size.y = 0.0
	var dim := hud.result_root.get_node("Dim") as ColorRect
	dim.color.a = 0.47


func _on_battle_finished(winner: int) -> void:
	# Battle 在发出信号后显示结算。交给 Movie Maker 继续录满片尾。
	await get_tree().process_frame
	var hud := _battle.hud
	if _battle.replay_result["reason"] == "timeout":
		hud.result_title.text = "时间到 · 平局"
	elif winner >= 0:
		var names := [_battle.team_name(0), _battle.team_name(1)]
		if names[0] == names[1]:
			for team in 2:
				names[team] += "（%s）" % GameState.team_short_name(team)
		hud.result_title.text = "%s 获胜" % names[winner]
		var objective := "主基地已摧毁" if _battle.is_siege() else "全员阵亡"
		hud.result_sub.text = names[1 - winner] + objective
	await get_tree().create_timer(RESULT_HOLD_SECONDS).timeout
	super._on_battle_finished(winner)
