extends Node

## 开发用压力测试：连续跑多场随机 5v5，确认战斗不会卡死，并打印胜者/时长。
## 运行：Godot --headless --path . res://tools/soak_test.tscn

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const BATTLES := 8


func _ready() -> void:
	await get_tree().process_frame
	var wins := [0, 0, 0]
	var total_time := 0.0
	for index in BATTLES:
		var pool: Array = UnitCatalog.all().duplicate()
		pool.shuffle()
		GameState.clear_lineup(0)
		GameState.clear_lineup(1)
		for slot in 5:
			GameState.set_slot(0, slot, pool[slot].unit_id)
			GameState.set_slot(1, slot, pool[pool.size() - 1 - slot].unit_id)

		var battle: Battle = BATTLE_SCENE.instantiate()
		add_child(battle)
		await get_tree().process_frame
		Engine.time_scale = 10.0
		var waited := 0.0
		while not battle.finished and waited < 15.0:
			await get_tree().create_timer(0.1, true, false, true).timeout
			waited += 0.1
		Engine.time_scale = 1.0
		var bucket := battle.winner if battle.winner >= 0 else 2
		wins[bucket] += 1
		total_time += battle.elapsed
		print("battle %d: finished=%s winner=%d elapsed=%.1fs real=%.1fs alive=%s" % [
			index + 1, battle.finished, battle.winner, battle.elapsed, waited,
			[battle.team_alive(0), battle.team_alive(1)],
		])
		await get_tree().create_timer(1.0, true, false, true).timeout
		battle.queue_free()
		await get_tree().process_frame
	print("summary: wins=%s avg=%.1fs" % [wins, total_time / float(BATTLES)])
	get_tree().quit(0 if wins[2] == 0 else 1)
