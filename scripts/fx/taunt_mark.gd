extends Node2D

var _time := 0.0

@onready var _mark: Sprite2D = $Mark


func _process(delta: float) -> void:
	_time += delta
	_mark.position.y = snappedf(sin(_time * 7.0) * 4.0, 4.0)
