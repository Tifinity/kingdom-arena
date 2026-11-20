extends Node2D

## pixelfx foot-level status loop. The status controller owns the lifetime.
const GROUND_RADIUS := 21.0
const FRAME_COUNT := 48
const FPS := 30.0

@onready var _ground: Sprite2D = $Ground
@onready var _chevrons: Sprite2D = $Chevrons

var _elapsed := 0.0


func _ready() -> void:
	var parent := get_parent()
	var unit := parent as Unit if parent is Unit else parent.get_parent() as Unit
	if unit != null:
		scale = Vector2.ONE * ((unit.body_radius + 10.0) / GROUND_RADIUS)


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, FRAME_COUNT / FPS)
	var index := int(_elapsed * FPS)
	_ground.frame = index
	_chevrons.frame = index
