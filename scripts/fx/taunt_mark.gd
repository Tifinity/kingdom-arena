extends Node2D

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	scale = Vector2.ONE * (1.0 + 0.07 * sin(_time * 7.0))
