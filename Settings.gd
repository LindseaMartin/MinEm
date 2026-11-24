extends Node
## Player preferences (autoload "Settings"). Saved separately from the game
## so starting a new game keeps them.

const PATH := "user://minem_settings.cfg"

var volume: float = 0.8        # all sound effects, 0..1
var beep_volume: float = 0.6   # detector beeps in the mine, 0..1
var ambience: float = 0.6      # cave drone, drips and rumbles, 0..1
var screen_shake: bool = true
var fullscreen: bool = false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
		beep_volume = clampf(float(cfg.get_value("audio", "beep_volume", beep_volume)), 0.0, 1.0)
		ambience = clampf(float(cfg.get_value("audio", "ambience", ambience)), 0.0, 1.0)
		screen_shake = bool(cfg.get_value("video", "screen_shake", screen_shake))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	apply()


func apply() -> void:
	var mode := DisplayServer.window_get_mode()
	if fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "beep_volume", beep_volume)
	cfg.set_value("audio", "ambience", ambience)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)
