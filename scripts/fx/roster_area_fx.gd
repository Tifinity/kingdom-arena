class_name RosterAreaFx
extends Node2D

const FLOOR_CLIP := preload("res://shaders/ground_fx_clip.gdshader")

@export var frame_count := 1
@export var frames_per_second := 30.0
@export var sheet_radius := 80.0
@export var clip_to_training_floor := false
@export var burst_scene: PackedScene

var _elapsed := 0.0
var _projected_ring: Sprite3D

@onready var _ground: Sprite2D = $Ground


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	var cast := source.current_cast
	var target := cast.target if cast != null else source.target
	var center := target.global_position if is_instance_valid(target) and target.alive else source.global_position
	if cast != null and cast.has_point:
		center = cast.point
	if effect.center_on_self:
		center = source.global_position
	setup_at(source.battle, center, effect.radius)


func setup_at(battle: Battle, center: Vector2, radius: float) -> void:
	global_position = center
	_ground.scale = Vector2.ONE * (radius / sheet_radius)
	var stage := battle.stage
	_projected_ring = stage.add_ground_sprite(_ground, self, ArenaStage3D.GROUND_MARKER_PRIORITY + 1)
	stage.sync_ground_sprite(_projected_ring, _ground, 0.2)
	if clip_to_training_floor and battle.training_mode:
		var material := ShaderMaterial.new()
		material.shader = FLOOR_CLIP
		material.render_priority = _projected_ring.render_priority
		material.set_shader_parameter(&"atlas", _projected_ring.texture)
		_projected_ring.material_override = material
		_sync_training_floor_clip(stage)
		get_viewport().size_changed.connect(_sync_training_floor_clip.bind(stage))
	_ground.hide()
	if burst_scene != null:
		var burst := burst_scene.instantiate() as ArenaBillboardEffect
		get_parent().add_child(burst)
		burst.setup_projection(stage, center)


func _sync_training_floor_clip(stage: ArenaStage3D) -> void:
	var bounds := stage.training_floor_bounds()
	var material := _projected_ring.material_override as ShaderMaterial
	material.set_shader_parameter(&"floor_min", bounds.position)
	material.set_shader_parameter(&"floor_max", bounds.end)


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * frames_per_second)
	if index >= frame_count:
		queue_free()
		return
	_ground.frame = index
	if is_instance_valid(_projected_ring):
		_projected_ring.frame = index
