extends Node

## 开发用：在真实 5v5 战斗中等待骑士释放火焰斩击，并在火焰帧截图。
## 运行：godot --path . res://tools/flame_capture.tscn --resolution 1600x900

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	GameState.reset_lineups()
	var battle: Battle = BATTLE_SCENE.instantiate()
	add_child(battle)
	var knight: Unit = null
	var waited := 0.0
	while waited < 12.0:
		await _wait(0.03)
		waited += 0.03
		if knight == null or not is_instance_valid(knight):
			for unit in battle.units:
				if is_instance_valid(unit) and unit.definition.unit_id == &"knight":
					knight = unit
					break
		if knight != null and is_instance_valid(knight):
			if knight.state_machine.current_name == &"action" and knight.planned_action != null:
				if knight.planned_action.action_id == &"knight_flame_slash":
					break
	if knight == null or not is_instance_valid(knight) or knight.planned_action == null:
		printerr("[flame] 骑士没有在限定时间内释放火焰斩击")
		get_tree().quit(1)
		return
	battle._select_at(knight.global_position + Vector2(0, -50))
	# attack_03 第 7 帧（16 FPS）约 0.44s；稍微多等一点让火焰帧完全显现。
	await _wait(0.46)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://artifacts/flame_slash.png")
	image.save_png(path)
	print("[flame] captured %s at %.2fs" % [path, waited])
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
