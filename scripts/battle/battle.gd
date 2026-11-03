class_name Battle
extends Node2D

## 战斗总控：生成双方阵容、倒计时、单位登记、伤害统计、胜负判定与结算。
## 具体战斗行为由 Unit + UnitBrain + StateMachine 完成。

signal battle_finished(winner: int)

const UNIT_SCENE := preload("res://scenes/battle/unit.tscn")
const PROJECTILE_SCENE := preload("res://scenes/battle/projectile.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/battle/damage_number.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/battle/hit_spark.tscn")
const SLASH_SCENE := preload("res://scenes/battle/slash_effect.tscn")

const SETUP_SCENE := "res://scenes/setup/setup_screen.tscn"
const BASE_SIZE := Vector2(1600.0, 900.0)
const BASE_FIELD_MIN := Vector2(190.0, 430.0)
const BASE_FIELD_MAX := Vector2(1410.0, 860.0)

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

var _mvp_name := "无"
var _mvp_team := -1
var _mvp_damage := 0.0

var field_min := BASE_FIELD_MIN
var field_max := BASE_FIELD_MAX
var _viewport_size := Vector2.ZERO

var _rng := RandomNumberGenerator.new()

@onready var hud: BattleHUD = $HUD
@onready var units_root: Node2D = $UnitsRoot
@onready var projectiles_root: Node2D = $Projectiles
@onready var effects_root: Node2D = $Effects


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_viewport_size = get_viewport_rect().size
	_refresh_layout()
	get_viewport().size_changed.connect(_on_viewport_resized)
	hud.bind(self)
	_spawn_lineups()
	_run_countdown()


## 逻辑视口变化时重新计算战场边界；单位按相同比例平移，保持相对站位。
func _on_viewport_resized() -> void:
	var next_size := get_viewport_rect().size
	if next_size.x <= 1.0 or next_size.y <= 1.0:
		return
	var previous := _viewport_size
	_viewport_size = next_size
	_refresh_layout()
	if previous.x <= 1.0 or previous.y <= 1.0:
		return
	var ratio := next_size / previous
	for unit in units:
		if is_instance_valid(unit):
			unit.position = clamp_unit_position(unit.position * ratio)


func _refresh_layout() -> void:
	if _viewport_size.x <= 1.0 or _viewport_size.y <= 1.0:
		return
	var layout_scale := _viewport_size / BASE_SIZE
	field_min = BASE_FIELD_MIN * layout_scale
	field_max = BASE_FIELD_MAX * layout_scale


func _formation_position(team: int, slot: int) -> Vector2:
	return BASE_FORMATIONS[team][slot] * (_viewport_size / BASE_SIZE)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _spawn_lineups() -> void:
	for team in 2:
		var lineup: Array = GameState.get_lineup(team)
		for slot in GameState.TEAM_SIZE:
			var unit_id: Variant = lineup[slot]
			if unit_id == null:
				continue
			var definition: UnitDefinition = UnitCatalog.get_definition(unit_id)
			if definition == null:
				continue
			var unit_scene: PackedScene = definition.unit_scene if definition.unit_scene != null else UNIT_SCENE
			var unit: Unit = unit_scene.instantiate()
			units_root.add_child(unit)
			unit.position = _formation_position(team, slot)
			unit.setup(self, team, slot, definition)
			unit.face_direction(1.0 if team == 0 else -1.0)
			unit.set_range_overlay_visible(show_combat_ranges)
			unit.died.connect(_on_unit_died)
			units.append(unit)
			team_sizes[team] += 1
			team_max_hp_total[team] += unit.max_hp


func _run_countdown() -> void:
	hud.show_countdown("3")
	await get_tree().create_timer(0.8, false).timeout
	if not is_inside_tree():
		return
	hud.show_countdown("2")
	await get_tree().create_timer(0.8, false).timeout
	if not is_inside_tree():
		return
	hud.show_countdown("1")
	await get_tree().create_timer(0.8, false).timeout
	if not is_inside_tree():
		return

	battle_active = true
	hud.show_countdown("开战！")
	for unit in units:
		if is_instance_valid(unit) and unit.alive:
			unit.brain.force_think()
	await get_tree().create_timer(0.55, false).timeout
	if not is_inside_tree():
		return
	hud.hide_countdown()


func _physics_process(delta: float) -> void:
	if finished:
		return
	if battle_active:
		elapsed += delta
	_resolve_separation()
	if battle_active:
		_evaluate_victory()


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
			a.position = clamp_unit_position(a.position - direction * push)
			b.position = clamp_unit_position(b.position + direction * push)


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
	return living_units(team).size()


func _on_unit_died(unit: Unit, killer: Unit) -> void:
	if is_instance_valid(unit):
		spawn_death_burst(unit.get_hit_point(), unit.accent_color)
	if is_instance_valid(killer):
		team_kills[killer.team] += 1
	call_deferred("_evaluate_victory")


func _evaluate_victory() -> void:
	if finished:
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


func _finish(result_winner: int) -> void:
	if finished:
		return
	finished = true
	battle_active = false
	winner = result_winner
	for unit in units:
		if is_instance_valid(unit):
			unit.brain.enabled = false
	Engine.time_scale = 1.0
	speed_multiplier = 1.0
	hud.refresh_controls()

	await get_tree().create_timer(0.9, false).timeout
	if not is_inside_tree():
		return

	var result := {
		"winner": winner,
		"elapsed": elapsed,
		"alive": [team_alive(0), team_alive(1)],
		"size": [team_sizes[0], team_sizes[1]],
		"damage": [team_damage[0], team_damage[1]],
		"kills": [team_kills[0], team_kills[1]],
		"mvp": {"name": _mvp_name, "team": _mvp_team, "damage": _mvp_damage},
	}
	GameState.last_result = result
	battle_finished.emit(winner)
	hud.show_result(result)


func on_damage_dealt(target: Unit, source: Unit, amount: float) -> void:
	if not is_instance_valid(target):
		return
	if is_instance_valid(source):
		team_damage[source.team] += amount
		var total: float = unit_damage.get(source, 0.0) + amount
		unit_damage[source] = total
		if total > _mvp_damage:
			_mvp_damage = total
			_mvp_name = source.definition.display_name
			_mvp_team = source.team
	var color: Color = source.accent_color if is_instance_valid(source) else Color.WHITE
	var at: Vector2 = target.get_hit_point() + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-8.0, 4.0))
	spawn_damage_number(at, amount, color)


func spawn_damage_number(at: Vector2, amount: float, color: Color) -> void:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	effects_root.add_child(number)
	number.setup(amount, color, at)


func spawn_block_text(at: Vector2) -> void:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	effects_root.add_child(number)
	number.setup_text("格挡", Color("#e7c46b"), at)


func register_action_cast(source: Unit, action: CombatActionDefinition) -> void:
	if action == null:
		return
	action_casts += 1
	if action.category == CombatActionDefinition.Category.SKILL:
		skill_casts += 1


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


func spawn_action_effect(scene: PackedScene, source: Unit, effect: ActionEffectDefinition) -> void:
	if scene == null or not is_instance_valid(source):
		return
	var fx := scene.instantiate()
	effects_root.add_child(fx)
	if fx.has_method("setup_from_effect"):
		fx.setup_from_effect(source, effect)


func spawn_projectile(source: Unit, target: Unit, damage: float, kind: int, color: Color) -> void:
	projectiles_fired += 1
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectiles_root.add_child(projectile)
	projectile.setup(source, target, damage, kind, color)


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
	if finished:
		return
	speed_multiplier = 2.0 if speed_multiplier < 1.5 else 1.0
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
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func back_to_setup() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(SETUP_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			_select_at(get_global_mouse_position())


func _select_at(point: Vector2) -> void:
	var best: Unit = null
	var best_distance := INF
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var center := unit.global_position + Vector2(0, -unit.character_height * unit.definition.visual_scale * 0.5)
		var distance := center.distance_to(point)
		var threshold := maxf(46.0, unit.body_radius * 1.75)
		if distance <= threshold and distance < best_distance:
			best = unit
			best_distance = distance

	if is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = best
	if best != null:
		best.set_selected(true)
	hud.set_selected_unit(best)
