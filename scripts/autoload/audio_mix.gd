extends Node

const BGM := &"BGM"
const SFX := &"SFX"
const SETTINGS_PATH := "user://audio.cfg"
const DIALOG := preload("res://scenes/ui/audio_settings.tscn")
const DEFAULT_VOLUMES := {BGM: 50, SFX: 60}

var _settings := ConfigFile.new()
var _volumes: Dictionary = {}
var _dialog: AcceptDialog
var _dirty := false


func _ready() -> void:
	var error := _settings.load(SETTINGS_PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("读取音量设置失败：%s" % error_string(error))
	for bus: StringName in DEFAULT_VOLUMES:
		var fallback: int = DEFAULT_VOLUMES[bus]
		var saved: Variant = _settings.get_value("volume", bus, fallback)
		var volume := clampi(int(saved), 0, 100) if saved is int else fallback
		_apply_volume(bus, volume)


func open_settings() -> void:
	if _dialog == null:
		_dialog = DIALOG.instantiate()
		add_child(_dialog)
		_bind_slider(_dialog.get_node("%BgmSlider"), _dialog.get_node("%BgmValue"), BGM)
		_bind_slider(_dialog.get_node("%SfxSlider"), _dialog.get_node("%SfxValue"), SFX)
		_dialog.visibility_changed.connect(_save_when_closed)
	_dialog.popup_centered()


func _bind_slider(slider: HSlider, value_label: Label, bus: StringName) -> void:
	slider.set_value_no_signal(_volumes[bus])
	value_label.text = "%d%%" % _volumes[bus]
	slider.value_changed.connect(_on_volume_changed.bind(bus, value_label))


func _on_volume_changed(value: float, bus: StringName, value_label: Label) -> void:
	var volume := roundi(value)
	_apply_volume(bus, volume)
	_settings.set_value("volume", bus, volume)
	value_label.text = "%d%%" % volume
	_dirty = true


func _apply_volume(bus: StringName, volume: int) -> void:
	_volumes[bus] = volume
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume / 100.0, 0.0001)))
	AudioServer.set_bus_mute(index, volume == 0)


func _save_when_closed() -> void:
	if _dialog.visible or not _dirty:
		return
	var error := _settings.save(SETTINGS_PATH)
	_dirty = error != OK
	if _dirty:
		push_warning("保存音量设置失败：%s" % error_string(error))
