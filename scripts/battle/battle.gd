class_name Battle
extends Node2D

## 战斗总控：生成双方阵容、倒计时、单位登记、伤害统计、胜负判定与结算。
## 具体战斗行为由 Unit + UnitBrain + StateMachine 完成。

signal battle_finished(winner: int)
signal deployment_changed(active: bool)

@export var deployment_enabled := false

const UNIT_SCENE := preload("res://scenes/battle/unit.tscn")
const PROJECTILE_SCENE := preload("res://scenes/battle/projectile.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/battle/damage_number.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/battle/hit_spark.tscn")
const SLASH_SCENE := preload("res://scenes/battle/slash_effect.tscn")
const TRAINING_DUMMY_DEFINITION := preload("res://resources/training/training_dummy.tres")

const MAIN_BASE_DEFINITION := preload("res://resources/battle/main_base.tres")
const RESPAWN_DELAY := 8.0
const RESPAWN_DELAY_STEP := 3.0
const MAX_RESPAWN_DELAY := 20.0
const MUSIC_TRIM_DB := -2.0
const MUSIC_FADE_SECONDS := 2.5

const SETUP_SCENE := "res://scenes/setup/setup_screen.tscn"
const BASE_SIZE := Vector2(1600.0, 900.0)
const TRAINING_FIELD_MIN := Vector2(190.0, 430.0)
const TRAINING_FIELD_MAX := Vector2(1410.0, 860.0)
const FIELD_CENTER := (TRAINING_FIELD_MIN + TRAINING_FIELD_MAX) * 0.5
# 相机保持原倍率，横向留出边距，新增面积主要分配到纵深。
const ARENA_FIELD_SCALE := Vector2(1.17, 2.0 / 1.17)
const ARENA_FIELD_HALF_SPAN := (TRAINING_FIELD_MAX - TRAINING_FIELD_MIN) * ARENA_FIELD_SCALE * 0.5
const BASE_FIELD_MIN := FIELD_CENTER - ARENA_FIELD_HALF_SPAN
const BASE_FIELD_MAX := FIELD_CENTER + ARENA_FIELD_HALF_SPAN
const FORMATION_DEPTH_SCALE := 1.35

## 训练模式的固定站位：英雄在左、稻草人在右，保持在中央可视区且避开底部技能栏。
const TRAINING_HERO_SPOT := Vector2(650.0, 600.0)
const TRAINING_DUMMY_SPOT := Vector2(980.0, 600.0)

## 5 个槽位在 1600x900 设计坐标里的位置。槽位即布阵面板中的从上到下 1~5。
const BASE_FORMATIONS := [
	[
		Vector2(530, 650), Vector2(512, 550), Vector2(512, 770),
		Vector2(388, 490), Vector2(388, 710),
	],
	[
		Vector2(1070, 650), Vector2(1088, 550), Vector2(1088, 770),
		Vector2(1212, 490), Vector2(1212, 710),
	],
]

var units: Array[Unit] = []
var mode := GameState.BattleMode.ELIMINATION
var main_bases: Array[Unit] = [null, null]
var _base_shot_ready_at: Array[float] = [0.0, 0.0]
var _respawns: Array[Dictionary] = [{}, {}]
var _hero_deaths: Array[Dictionary] = [{}, {}]
var deploying := false
var _round_id := 0
var battle_active := false
var finished := false
var winner := -1
var elapsed := 0.0
var speed_multiplier := 1.0
var team_damage: Array[float] = [0.0, 0.0]
var team_kills: Array[int] = [0, 0]
var team_sizes: Array[int] = [0, 0]
var team_max_hp_total: Array[float] = [0.0, 0.0]
var selected_unit: Unit
var show_combat_ranges := false
var unit_damage: Dictionary = {}
var projectiles_fired := 0
var action_casts := 0
var skill_casts := 0
var action_hits := 0

## 复跑入口在添加战斗场景前设置；普通对战和试炼场维持原来的行为。
var replay_config: BattleReplayConfig
var replay_tick := 0
var replay_events: Array[Dictionary] = []
var replay_result: Dictionary = {}

## 训练模式：不读 GameState 阵容，只生成指定英雄 + 一只不会死亡、不会移动的稻草人。
## Hero Lab 在 add_child 之前设置 training_mode / training_definition。
var training_mode := false
var training_positioning := false
var training_definition: UnitDefinition
var training_hero: Unit
var training_dummy: Unit

var _mvp_name := "无"
var _mvp_team := -1
var _mvp_damage := 0.0

var field_min := BASE_FIELD_MIN
var field_max := BASE_FIELD_MAX
var _viewport_size := Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _music_fade: Tween

@onready var hud: BattleHUD = $HUD
@onready var battle_music: AudioStreamPlayer = $BattleMusic
@onready var stage: ArenaStage3D = $Stage
@onready var ground_presentation: CanvasLayer = $GroundPresentation
@onready var units_root: Node2D = $GroundPresentation/UnitsRoot
@onready var projectiles_root: Node2D = $GroundPresentation/Projectiles
@onready var effects_root: Node2D = $GroundPresentation/Effects
@onready var combat_text: CanvasLayer = $CombatText
@onready var _base_markers: Array[Marker2D] = [$BasePositions/BlueBase, $BasePositions/RedBase]


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_viewport_size = get_viewport_rect().size
	_refresh_layout()
	mode = replay_config.mode if replay_config != null else GameState.battle_mode
	get_viewport().size_changed.connect(_on_viewport_resized)
	hud.bind(self)
	if training_mode:
		hud.visible = false
		hud.process_mode = Node.PROCESS_MODE_DISABLED
		if training_definition == null:
			var roster := UnitCatalog.all()
			if not roster.is_empty():
				training_definition = roster[0]
		if training_definition != null:
			start_training(training_definition)
	elif deployment_enabled:
		_enter_deployment()
	else:
		if replay_config != null:
			_rng.seed = replay_config.seed
		_spawn_lineups()
		hud.set_roster(units)
		if replay_config != null:
			return
		if BattleTransition.is_loading():
			var previous_process_mode := process_mode
			process_mode = Node.PROCESS_MODE_DISABLED
			await BattleTransition.finished
			process_mode = previous_process_mode
		_run_countdown()


## 逻辑视口变化时重新计算战场边界；单位按相同比例平移，保持相对站位。
func _on_viewport_resized() -> void:
	var next_size := get_viewport_rect().size
	if next_size.x <= 1.0 or next_size.y <= 1.0:
		return
	var previous := _viewport_size
	_viewport_size = next_size
	_refresh_layout()
	if replay_config != null:
		return
	if training_mode:
		var layout_scale := _viewport_size / BASE_SIZE
		var next_dummy := TRAINING_DUMMY_SPOT * layout_scale
		if is_instance_valid(training_hero):
			if training_positioning and is_instance_valid(training_dummy):
				training_hero.position = clamp_unit_position(training_hero.position + next_dummy - training_dummy.position)
			else:
				training_hero.position = TRAINING_HERO_SPOT * layout_scale
		if is_instance_valid(training_dummy):
			training_dummy.position = next_dummy
		return
	if previous.x <= 1.0 or previous.y <= 1.0:
		return
	var ratio := next_size / previous
	for unit in units:
		if is_instance_valid(unit) and not unit.is_main_base():
			unit.position = clamp_unit_position(unit.position * ratio)
	for team in 2:
		if is_instance_valid(main_bases[team]):
			main_bases[team].position = _base_position(team)


func _refresh_layout() -> void:
	if _viewport_size.x <= 1.0 or _viewport_size.y <= 1.0:
		return
	var layout_scale := _viewport_size / BASE_SIZE if replay_config == null else Vector2.ONE
	field_min = (TRAINING_FIELD_MIN if training_mode else BASE_FIELD_MIN) * layout_scale
	field_max = (TRAINING_FIELD_MAX if training_mode else BASE_FIELD_MAX) * layout_scale
	stage.frame_field(_viewport_size, field_min, field_max, training_mode)
	ground_presentation.transform = stage.ground_transform
	for unit in units:
		if is_instance_valid(unit):
			unit.update_arena_projection(ground_presentation.scale.y / ground_presentation.scale.x)


func set_deployment_view_offset(pixels: float) -> void:
	stage.set_vertical_offset(pixels)
	ground_presentation.transform = stage.ground_transform


func _formation_position(team: int, slot: int) -> Vector2:
	var default_position := _default_formation_position(team, slot)
	if replay_config != null:
		return replay_config.position_for_slot(team, slot, default_position)
	return GameState.deployment_position(team, slot, default_position) * (_viewport_size / BASE_SIZE)


func _default_formation_position(team: int, slot: int) -> Vector2:
	var point: Vector2 = BASE_FORMATIONS[team][slot]
	point.y = FIELD_CENTER.y + (point.y - FIELD_CENTER.y) * FORMATION_DEPTH_SCALE
	return point


func unit_in_slot(team: int, slot: int) -> Unit:
	for unit in units:
		if is_instance_valid(unit) and unit.alive and not unit.summoned and unit.team == team and unit.slot == slot:
			return unit
	return null


func refresh_deployment() -> void:
	if not deploying:
		return
	for team in 2:
		for slot in GameState.TEAM_SIZE:
			var unit := unit_in_slot(team, slot)
			var unit_id: Variant = GameState.get_slot(team, slot)
			if unit != null and unit.definition.unit_id != unit_id:
				if selected_unit == unit:
					select_unit(null)
				team_sizes[team] -= 1
				team_max_hp_total[team] -= unit.max_hp
				units.erase(unit)
				unit.queue_free()
				unit = null
			if unit == null and unit_id != null:
				unit = _spawn_unit(UnitCatalog.get_definition(unit_id), team, slot, _formation_position(team, slot))
				unit.set_physics_process(false)
			elif unit != null:
				unit.position = _formation_position(team, slot)
	_sync_main_bases()


func set_deployment_position(team: int, slot: int, point: Vector2) -> void:
	GameState.set_deployment_position(team, slot, point / (_viewport_size / BASE_SIZE), _default_formation_position(team, slot))


func start_deployed_battle() -> void:
	if not deploying or not GameState.lineup_ready():
		return
	refresh_deployment()
	deploying = false
	select_unit(null)
	for unit in units:
		unit.set_physics_process(true)
	_show_combat_hud()
	deployment_changed.emit(false)
	_run_countdown()


func _enter_deployment() -> void:
	_reset_round()
	deploying = true
	hud.hide()
	hud.process_mode = Node.PROCESS_MODE_DISABLED
	refresh_deployment()
	deployment_changed.emit(true)


func _show_combat_hud() -> void:
	hud.show()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.set_roster(units)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _spawn_lineups() -> void:
	for team in 2:
		var lineup: Array = GameState.get_lineup(team) if replay_config == null else replay_config.lineups[team]
		for slot in GameState.TEAM_SIZE:
			var unit_id: Variant = lineup[slot]
			if unit_id == null:
				continue
			var definition := _lineup_definition(StringName(unit_id))
			if definition == null:
				continue
			_spawn_unit(definition, team, slot, _formation_position(team, slot))
	_sync_main_bases()


func _sync_main_bases() -> void:
	mode = replay_config.mode if replay_config != null else GameState.battle_mode
	for team in 2:
		var base := main_bases[team]
		if is_siege():
			if not is_instance_valid(base):
				base = _spawn_unit(MAIN_BASE_DEFINITION, team, -1, _base_position(team), false)
				base.set_physics_process(not deploying)
				main_bases[team] = base
		elif is_instance_valid(base):
			units.erase(base)
			main_bases[team] = null
			base.queue_free()


func _base_position(team: int) -> Vector2:
	var layout_scale := _viewport_size / BASE_SIZE if replay_config == null else Vector2.ONE
	return clamp_unit_position(_base_markers[team].position * layout_scale)


func is_siege() -> bool:
	return not training_mode and mode == GameState.BattleMode.SIEGE


func respawn_remaining(team: int, slot: int) -> float:
	var pending: Dictionary = _respawns[team].get(slot, {})
	return maxf(0.0, float(pending.get("at", elapsed)) - elapsed)


func _update_siege() -> void:
	for team in 2:
		var base := main_bases[team]
		if elapsed >= _base_shot_ready_at[team]:
			_fire_base_arrow(base)
		for slot: int in _respawns[team].keys():
			if respawn_remaining(team, slot) > 0.0:
				continue
			var definition: UnitDefinition = _respawns[team][slot]["definition"]
			_respawns[team].erase(slot)
			var rear := -1.0 if team == 0 else 1.0
			var offset := Vector2(rear * (base.body_radius + 46.0 + 25.0 * (slot % 2)), 66.0 * (slot - 2))
			var hero := _spawn_unit(definition, team, slot, clamp_unit_position(base.position + offset), false)
			hero.on_battle_started()
			hud.replace_roster_unit(hero)


func _fire_base_arrow(base: Unit) -> void:
	var target: Unit
	var nearest := INF
	for enemy in living_units(1 - base.team):
		if enemy.is_main_base():
			continue
		var distance := base.position.distance_to(enemy.position)
		if distance <= base.attack_range + enemy.body_radius and distance < nearest:
			target = enemy
			nearest = distance
	if target == null:
		return
	spawn_projectile(base, target, base.current_attack_damage(), base.projectile_kind, GameState.team_color(base.team))
	_base_shot_ready_at[base.team] = elapsed + base.current_attack_interval()


func _lineup_definition(unit_id: StringName) -> UnitDefinition:
	return UnitCatalog.get_definition(unit_id) if replay_config == null else replay_config.unit_definition(unit_id)


## 生成并登记一个单位。正常战斗与试炼场的训练模式共用这条路径。
func _spawn_unit(definition: UnitDefinition, team: int, slot: int, spawn_position: Vector2,
		count_in_lineup := true, summoner: Unit = null) -> Unit:
	var unit_scene: PackedScene = definition.unit_scene if definition.unit_scene != null else UNIT_SCENE
	var unit: Unit = unit_scene.instantiate()
	units_root.add_child(unit)
	unit.position = spawn_position
	unit.setup(self, team, slot, definition)
	unit.summoned = summoner != null
	_register_replay_unit(unit, summoner)
	var direction := 1.0 if team == 0 else -1.0
	unit.face_direction(-direction if unit.summoned else direction)
	var sprite := UnitSprite3D.new()
	if training_mode:
		sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	stage.actors.add_child(sprite)
	sprite.setup(unit, stage)
	unit.tree_exiting.connect(sprite.queue_free, CONNECT_ONE_SHOT)
	unit.update_arena_projection(ground_presentation.scale.y / ground_presentation.scale.x)
	unit.set_range_overlay_visible(show_combat_ranges)
	unit.died.connect(_on_unit_died)
	units.append(unit)
	if count_in_lineup:
		team_sizes[team] += 1
		team_max_hp_total[team] += unit.max_hp
	return unit


## Hero Lab：清空战场并重新摆出「英雄 vs 稻草人」。切换英雄或重置演示时调用。
func start_training(definition: UnitDefinition) -> void:
	training_mode = true
	training_definition = definition
	_reset_round()
	battle_active = true
	training_hero = null
	training_dummy = null
	if definition == null:
		return
	var layout_scale := _viewport_size / BASE_SIZE
	training_hero = _spawn_unit(definition, 0, 0, TRAINING_HERO_SPOT * layout_scale)
	var dummy_definition := TRAINING_DUMMY_DEFINITION as UnitDefinition
	training_dummy = _spawn_unit(dummy_definition, 1, 2, TRAINING_DUMMY_SPOT * layout_scale)
	training_hero.face_direction(1.0)
	training_dummy.face_direction(-1.0)
	training_hero.on_battle_started()
	training_hero.brain.enabled = not training_positioning
	training_hero.brain.force_think()


func _reset_round() -> void:
	_round_id += 1
	if _music_fade != null:
		_music_fade.kill()
		_music_fade = null
	battle_music.stop()
	_clear_battlefield()
	battle_active = false
	finished = false
	winner = -1
	elapsed = 0.0
	speed_multiplier = 1.0
	Engine.time_scale = 1.0
	team_damage = [0.0, 0.0]
	team_kills = [0, 0]
	team_sizes = [0, 0]
	team_max_hp_total = [0.0, 0.0]
	unit_damage.clear()
	projectiles_fired = 0
	action_casts = 0
	skill_casts = 0
	action_hits = 0
	_mvp_name = "无"
	_mvp_team = -1
	_mvp_damage = 0.0
	selected_unit = null
	if not training_mode:
		get_tree().paused = false
		hud.reset_round()


func _clear_battlefield() -> void:
	for unit in units:
		if not is_instance_valid(unit):
			continue
		unit.brain.enabled = false
		unit.set_physics_process(false)
		unit.set_process(false)
		unit.queue_free()
	units.clear()
	main_bases = [null, null]
	_base_shot_ready_at = [0.0, 0.0]
	_respawns = [{}, {}]
	_hero_deaths = [{}, {}]
	for container in [projectiles_root, effects_root, combat_text]:
		for child in container.get_children():
			child.queue_free()


func is_training_dummy(unit: Unit) -> bool:
	return is_instance_valid(unit) and unit.definition != null and unit.definition.training_dummy


func training_damage() -> float:
	return team_damage[0] if team_damage.size() > 0 else 0.0



func _run_countdown() -> void:
	var round_id := _round_id
	for count in [3, 2, 1]:
		hud.show_countdown(str(count))
		await get_tree().create_timer(0.8, false).timeout
		if not is_inside_tree() or round_id != _round_id:
			return

	hud.show_countdown("开战！")
	_begin_battle()
	await get_tree().create_timer(0.55, false).timeout
	if not is_inside_tree() or round_id != _round_id:
		return
	hud.hide_countdown()


func _begin_battle() -> void:
	battle_active = true
	if not training_mode and DisplayServer.get_name() != "headless":
		battle_music.volume_db = MUSIC_TRIM_DB
		battle_music.play()
	for unit in living_units():
		unit.on_battle_started()
		unit.brain.force_think()


func _physics_process(delta: float) -> void:
	if finished or (deployment_enabled and not battle_active):
		return
	if replay_config != null and replay_tick == 0:
		_begin_battle()
	elif battle_active and not training_mode:
		# 在完整物理帧之间结算，先判胜负，再判超时。
		_evaluate_victory()
		if finished:
			return
		if elapsed >= GameState.BATTLE_TIME_LIMIT_SECONDS:
			_finish(-1, "timeout")
			return
	if replay_config != null:
		replay_tick += 1
		elapsed = float(replay_tick) / BattleReplayConfig.TICKS_PER_SECOND
	elif battle_active:
		elapsed = minf(elapsed + delta, GameState.BATTLE_TIME_LIMIT_SECONDS) if not training_mode else elapsed + delta
	if battle_active and is_siege():
		_update_siege()
	_resolve_separation()


func _resolve_separation() -> void:
	var living := living_units()
	for index in living.size():
		var a: Unit = living[index]
		if not is_instance_valid(a) or not a.alive:
			continue
		for other_index in range(index + 1, living.size()):
			var b: Unit = living[other_index]
			if not is_instance_valid(b) or not b.alive:
				continue
			# 稻草人固定站位，不被分离推挤，也不推开英雄。
			if is_training_dummy(a) or is_training_dummy(b):
				continue
			if (a.is_charging() or b.is_charging()) and not (a.is_main_base() or b.is_main_base()):
				continue
			var min_distance := (a.body_radius + b.body_radius) * 0.86
			var offset: Vector2 = b.position - a.position
			var distance := offset.length()
			if distance >= min_distance:
				continue
			if distance < 0.001:
				offset = Vector2(1.0, 0.0)
				distance = 1.0
			var push := (min_distance - distance) * 0.38
			var direction := offset / distance
			if not a.is_main_base():
				a.position = clamp_unit_position(a.position - direction * push * (2.0 if b.is_main_base() else 1.0))
			if not b.is_main_base():
				b.position = clamp_unit_position(b.position + direction * push * (2.0 if a.is_main_base() else 1.0))


func clamp_unit_position(point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, field_min.x, field_max.x),
		clampf(point.y, field_min.y, field_max.y)
	)


func living_units(team := -1) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		if team >= 0 and unit.team != team:
			continue
		result.append(unit)
	return result


func team_hp(team: int) -> float:
	var total := 0.0
	for unit in units:
		if not is_instance_valid(unit) or unit.team != team or not unit.alive:
			continue
		total += unit.hp
	return total


func team_max_hp(team: int) -> float:
	return team_max_hp_total[team]


func team_alive(team: int) -> int:
	var living := living_units(team)
	if not is_siege():
		return living.size()
	var heroes := 0
	for unit in living:
		if not unit.is_main_base() and not unit.summoned:
			heroes += 1
	return heroes


func _on_unit_died(unit: Unit, killer: Unit) -> void:
	if is_instance_valid(unit):
		spawn_death_burst(unit.get_effect_point(), unit.accent_color)
	if is_instance_valid(killer) and not unit.is_main_base():
		team_kills[killer.team] += 1
	if is_siege() and battle_active and not unit.is_main_base() and not unit.summoned:
		var previous_deaths: int = _hero_deaths[unit.team].get(unit.slot, 0)
		var delay := minf(RESPAWN_DELAY + RESPAWN_DELAY_STEP * previous_deaths, MAX_RESPAWN_DELAY)
		_hero_deaths[unit.team][unit.slot] = previous_deaths + 1
		_respawns[unit.team][unit.slot] = {"at": elapsed + delay, "definition": unit.definition}
	# 训练模式没有胜负：稻草人不会死亡，英雄也不应由靶子击杀。
	if replay_config != null:
		_record_replay_event("death", killer, unit)
		return
	if training_mode or is_siege():
		return
	call_deferred("_evaluate_victory")


func _evaluate_victory() -> void:
	if finished or training_mode or deploying:
		return
	if is_siege():
		var blue_destroyed := not is_instance_valid(main_bases[0]) or not main_bases[0].alive
		var red_destroyed := not is_instance_valid(main_bases[1]) or not main_bases[1].alive
		if blue_destroyed or red_destroyed:
			_finish(-1 if blue_destroyed and red_destroyed else (1 if blue_destroyed else 0), "base_destroyed")
		return
	var alive_blue := team_alive(0)
	var alive_red := team_alive(1)
	if alive_blue > 0 and alive_red > 0:
		return
	if alive_blue == 0 and alive_red == 0:
		_finish(-1)
	elif alive_red == 0:
		_finish(0)
	else:
		_finish(1)


func _finish(result_winner: int, reason := "elimination") -> void:
	if finished:
		return
	finished = true
	battle_active = false
	_respawns = [{}, {}]
	winner = result_winner
	for unit in units:
		if is_instance_valid(unit):
			unit.brain.enabled = false
	Engine.time_scale = 1.0
	speed_multiplier = 1.0
	hud.refresh_controls()
	if battle_music.playing:
		_music_fade = create_tween()
		_music_fade.tween_property(battle_music, "volume_db", -48.0, MUSIC_FADE_SECONDS)
		_music_fade.tween_callback(battle_music.stop)

	if replay_config != null:
		replay_result = {"tick": replay_tick, "reason": reason, "summary": _build_result(reason)}
	if replay_config != null or is_siege() or reason == "timeout":
		# 保留最后一击的动画与特效，同时停止战斗逻辑。
		for unit in living_units():
			unit.set_physics_process(false)
			unit.state_machine.set_physics_process(false)
			unit.status_controller.set_physics_process(false)
		for projectile in projectiles_root.get_children():
			projectile.set_physics_process(false)

	var round_id := _round_id
	await get_tree().create_timer(0.9, false).timeout
	if not is_inside_tree() or round_id != _round_id:
		return

	var result: Dictionary = replay_result["summary"] if replay_config != null else _build_result(reason)
	GameState.last_result = result
	battle_finished.emit(winner)
	hud.show_result(result)


func _build_result(reason: String) -> Dictionary:
	return {
		"winner": winner,
		"reason": reason,
		"elapsed": elapsed,
		"alive": [team_alive(0), team_alive(1)],
		"size": [team_sizes[0], team_sizes[1]],
		"damage": [team_damage[0], team_damage[1]],
		"kills": [team_kills[0], team_kills[1]],
		"mvp": {"name": _mvp_name, "team": _mvp_team, "damage": _mvp_damage},
	}


func on_damage_dealt(target: Unit, source: Unit, amount: float) -> void:
	if not is_instance_valid(target):
		return
	if is_instance_valid(source):
		team_damage[source.team] += amount
		var damage_key: Variant = source
		if is_siege() and not source.summoned and not source.is_main_base():
			damage_key = Vector2i(source.team, source.slot)
		var total: float = unit_damage.get(damage_key, 0.0) + amount
		unit_damage[damage_key] = total
		if not source.is_main_base() and total > _mvp_damage:
			_mvp_damage = total
			_mvp_name = source.definition.display_name
			_mvp_team = source.team
	if replay_config != null:
		_record_replay_event("damage", source, target, {"amount": amount})
	var color: Color = source.accent_color if is_instance_valid(source) else Color.WHITE
	var at: Vector2 = target.get_effect_point() + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-8.0, 4.0))
	spawn_damage_number(at, amount, color)


func spawn_damage_number(at: Vector2, amount: float, color: Color) -> void:
	_spawn_combat_text(at, "-%d" % maxi(1, roundi(amount)), color)


func spawn_block_text(at: Vector2) -> void:
	_spawn_combat_text(at, "格挡", Color("#e7c46b"))


func spawn_heal_text(at: Vector2, amount: float) -> void:
	_spawn_combat_text(at, "+%d" % roundi(amount), Color("#8fe3a8"))


func spawn_shield_text(at: Vector2, amount: float) -> void:
	_spawn_combat_text(at, "护盾 +%d" % roundi(amount), Color("#59d9ff"))


func _spawn_combat_text(at: Vector2, text: String, color: Color) -> void:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	combat_text.add_child(number)
	number.setup_text(text, color, stage.ground_transform * at)


func spawn_summons(source: Unit, unit_id: StringName, count: int, effect_scene: PackedScene = null) -> void:
	if not is_instance_valid(source) or unit_id == &"":
		return
	var definition := _lineup_definition(unit_id)
	if definition == null:
		return
	for index in maxi(count, 1):
		var angle := TAU * float(index) / float(maxi(count, 1))
		var spawn_position := source.global_position + Vector2.from_angle(angle) * 58.0
		var unit := _spawn_unit(definition, source.team, source.slot, spawn_position, not is_siege(), source)
		if effect_scene != null:
			var fx := effect_scene.instantiate()
			effects_root.add_child(fx)
			if fx is ArenaBillboardEffect:
				fx.setup_projection(stage, spawn_position)
			elif fx is Node2D:
				fx.global_position = spawn_position
		if battle_active:
			unit.on_battle_started()
		unit.play_summon_intro()


func register_action_cast(source: Unit, action: CombatActionDefinition) -> void:
	if action == null:
		return
	action_casts += 1
	if action.category == CombatActionDefinition.Category.SKILL:
		skill_casts += 1
	if replay_config != null and action.category != CombatActionDefinition.Category.BASIC:
		_record_replay_event("cast", source, source.current_cast.target, {"action": String(action.action_id)})


func _register_replay_unit(unit: Unit, summoner: Unit = null) -> void:
	if replay_config == null:
		return
	unit.replay_id = units.size()
	unit.brain.set_random_seed(replay_config.seed + unit.replay_id * 2654435761)
	_record_replay_event("spawn", summoner, unit, {
		"unit": String(unit.definition.unit_id), "team": unit.team, "slot": unit.slot,
		"position": [unit.position.x, unit.position.y],
	})


func _record_replay_event(kind: String, source: Unit, target: Unit, fields: Dictionary = {}) -> void:
	fields["type"] = kind
	fields["tick"] = replay_tick
	fields["source"] = source.replay_id if is_instance_valid(source) else null
	fields["target"] = target.replay_id if is_instance_valid(target) else null
	replay_events.append(fields)


func team_name(team: int) -> String:
	if replay_config != null:
		return GameState.TEAM_PRESETS[replay_config.presets[team]]["name"]
	return GameState.team_name(team)


## 扇形 AOE：以 source 为圆心，direction 为朝向，收集敌方单位。
func units_in_cone(source: Unit, direction: Vector2, radius: float, half_angle_degrees: float) -> Array[Unit]:
	var result: Array[Unit] = []
	if not is_instance_valid(source):
		return result
	var dir := direction.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2(float(source.facing), 0.0)
	var half_angle := deg_to_rad(absf(half_angle_degrees))
	for unit in living_units():
		if unit.team == source.team:
			continue
		var offset := unit.global_position - source.global_position
		if offset.length() > radius + unit.body_radius:
			continue
		if offset.length_squared() < 0.0001 or absf(dir.angle_to(offset.normalized())) <= half_angle:
			result.append(unit)
	return result


func units_in_circle(source: Unit, center: Vector2, radius: float) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in living_units():
		if unit.team == source.team:
			continue
		if unit.global_position.distance_to(center) <= radius + unit.body_radius:
			result.append(unit)
	return result


## 直线矩形：从 source 沿 direction 延伸 length，全宽 width。
func units_in_rect(source: Unit, direction: Vector2, length: float, width: float) -> Array[Unit]:
	var result: Array[Unit] = []
	if not is_instance_valid(source):
		return result
	var dir := direction.normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2(float(source.facing), 0.0)
	var side := Vector2(-dir.y, dir.x)
	var half_width := maxf(width, 1.0) * 0.5
	for unit in living_units():
		if unit.team == source.team:
			continue
		var offset := unit.global_position - source.global_position
		var forward := offset.dot(dir)
		var lateral := absf(offset.dot(side))
		if forward < -unit.body_radius or forward > length + unit.body_radius:
			continue
		if lateral <= half_width + unit.body_radius:
			result.append(unit)
	return result


func spawn_action_effect(scene: PackedScene, source: Unit, effect: ActionEffectDefinition) -> void:
	if scene == null or not is_instance_valid(source):
		return
	var fx := scene.instantiate()
	effects_root.add_child(fx)
	if fx.has_method("setup_from_effect"):
		fx.setup_from_effect(source, effect)


func spawn_billboard_effect_at(scene: PackedScene, unit: Unit) -> void:
	var fx := scene.instantiate() as ArenaBillboardEffect
	effects_root.add_child(fx)
	fx.setup_projection(stage, unit.global_position, unit.get_hit_point() - unit.global_position)


func spawn_projectile(source: Unit, target: Unit, damage: float, kind: int, color: Color, effect: ActionEffectDefinition = null) -> void:
	projectiles_fired += 1
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectiles_root.add_child(projectile)
	projectile.setup(source, target, damage, kind, color, effect)
	if effect != null:
		play_action_sound(effect.projectile_release_sound)


func play_action_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -9.0
	player.bus = AudioMix.SFX
	player.finished.connect(player.queue_free)
	effects_root.add_child(player)
	player.play()


func spawn_slash(at: Vector2, color: Color, direction: float) -> void:
	var slash: SlashEffect = SLASH_SCENE.instantiate()
	effects_root.add_child(slash)
	slash.setup(at, color, direction)


func spawn_hit_spark(at: Vector2, color: Color, size := 1.0) -> void:
	var spark: HitSpark = HIT_SPARK_SCENE.instantiate()
	effects_root.add_child(spark)
	spark.setup(at, color, size)


func spawn_death_burst(at: Vector2, color: Color) -> void:
	spawn_hit_spark(at, color, 2.1)
	spawn_hit_spark(at + Vector2(0, 18), color.darkened(0.25), 1.2)


func toggle_speed() -> void:
	if finished or replay_config != null:
		return
	if speed_multiplier < 0.75:
		speed_multiplier = 1.0
	elif speed_multiplier < 1.5:
		speed_multiplier = 2.0
	else:
		speed_multiplier = 0.5
	Engine.time_scale = speed_multiplier
	hud.refresh_controls()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	hud.set_paused(get_tree().paused)


func set_range_overlay(value: bool) -> void:
	show_combat_ranges = value
	for unit in units:
		if is_instance_valid(unit):
			unit.set_range_overlay_visible(value)


func toggle_range_overlay() -> void:
	set_range_overlay(not show_combat_ranges)


func restart_battle() -> void:
	if replay_config != null:
		return
	if deployment_enabled:
		if deploying:
			return
		_reset_round()
		_spawn_lineups()
		_show_combat_hud()
		_run_countdown()
	else:
		BattleTransition.start()


func back_to_setup() -> void:
	if replay_config != null:
		return
	if deployment_enabled:
		_enter_deployment()
		return
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(SETUP_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if not training_mode and not deploying and event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_select_at(mouse.position)


func unit_screen_position(unit: Unit) -> Vector2:
	return stage.ground_transform * unit.get_effect_point()


func _select_at(point: Vector2) -> void:
	select_unit(unit_at_screen_position(point))


func unit_at_screen_position(point: Vector2) -> Unit:
	var best: Unit = null
	var best_distance := INF
	for unit in units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		if deploying and unit.is_main_base():
			continue
		var center := unit_screen_position(unit)
		var distance := center.distance_to(point)
		var threshold := maxf(46.0, unit.body_radius * 1.75) * stage.ground_transform.x.length()
		if distance <= threshold and distance < best_distance:
			best = unit
			best_distance = distance

	return best


func select_unit(unit: Unit) -> void:
	if is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = unit
	if is_instance_valid(unit):
		unit.set_selected(true)
	hud.set_selected_unit(unit)
