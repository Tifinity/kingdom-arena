class_name AegisRingFx
extends Node2D

## The source atlas is a top-down circle. The arena camera projects it onto the floor.
const SHEET_RING_RADIUS := 64.0
const FRAME_COUNT := 68
const FPS := 24.0

var radius := 160.0
var _elapsed := 0.0
var _projected_ring: Sprite3D

@onready var _ground: Sprite2D = $Ground


func setup_from_effect(source: Unit, effect: ActionEffectDefinition) -> void:
	global_position = source.global_position
	radius = maxf(effect.radius, 1.0)
	scale = Vector2.ONE * (radius / SHEET_RING_RADIUS)
	if source.battle is Battle:
		var stage: ArenaStage3D = source.battle.stage
		_projected_ring = stage.add_ground_sprite(_ground, self, ArenaStage3D.GROUND_MARKER_PRIORITY + 1)
		stage.sync_ground_sprite(_projected_ring, _ground, 0.2)
		_ground.hide()


func _process(delta: float) -> void:
	_elapsed += delta
	var index := int(_elapsed * FPS)
	if index >= FRAME_COUNT:
		queue_free()
		return
	_ground.frame = index
	if _projected_ring != null:
		_projected_ring.frame = index
