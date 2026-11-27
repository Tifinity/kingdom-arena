class_name ArenaUIRoot
extends Control

signal layout_changed(compact: bool)

const COMPACT_SCALE := 1.25
const COMPACT_BELOW := Vector2(1500.0, 850.0)

var compact := false
var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	var window := get_window()
	window.size_changed.connect(_update_window_layout)
	window.dpi_changed.connect(_update_window_layout)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(DisplayServer.get_name() != "headless")
	_update_window_layout()


func _process(_delta: float) -> void:
	# 同宽高比缩放时，逻辑视口没变，size_changed 不一定触发。
	if get_window().size != _last_window_size:
		_update_window_layout()


func _update_window_layout() -> void:
	var window := get_window()
	_last_window_size = window.size
	var window_points := get_viewport_rect().size
	if DisplayServer.get_name() != "headless":
		window_points = Vector2(window.size) / maxf(DisplayServer.screen_get_scale(window.current_screen), 1.0)
	fit_window(window_points)


## 只缩放界面层。战场镜头、单位和输入坐标继续使用原视口尺寸。
func fit_window(window_points: Vector2) -> void:
	if window_points.x <= 1.0 or window_points.y <= 1.0:
		return
	var was_compact := compact
	compact = Engine.get_write_movie_path().is_empty() \
		and (window_points.x < COMPACT_BELOW.x or window_points.y < COMPACT_BELOW.y)
	var factor := COMPACT_SCALE if compact else 1.0
	scale = Vector2.ONE * factor
	size = get_viewport_rect().size / factor
	if was_compact != compact:
		layout_changed.emit(compact)
