extends Node
## Player preferences (autoload "Settings"). Saved separately from the game
## so starting a new game keeps them.

const PATH := "user://minem_settings.cfg"
const UiTheme := preload("res://UI/ui_theme.gd")
const TEXT_SIZES := [9, 11, 13]
const TEXT_SIZE_NAMES := ["Small", "Medium", "Large"]

var volume: float = 0.8        # all sound effects, 0..1
var beep_volume: float = 0.6   # detector beeps in the mine, 0..1
var ambience: float = 0.6      # cave drone, drips and rumbles, 0..1
var screen_shake: bool = true
var fullscreen: bool = false
var text_size: int = 1        # index into TEXT_SIZES


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
		beep_volume = clampf(float(cfg.get_value("audio", "beep_volume", beep_volume)), 0.0, 1.0)
		ambience = clampf(float(cfg.get_value("audio", "ambience", ambience)), 0.0, 1.0)
		screen_shake = bool(cfg.get_value("video", "screen_shake", screen_shake))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		text_size = clampi(int(cfg.get_value("video", "text_size", text_size)), 0, TEXT_SIZES.size() - 1)
	apply()


func apply() -> void:
	get_tree().root.theme = UiTheme.build(font_size())
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
	cfg.set_value("video", "text_size", text_size)
	cfg.save(PATH)


## Body text size for the current setting (in UI pixels).
func font_size() -> int:
	return TEXT_SIZES[text_size]

func small_size() -> int:
	return font_size() - 2

func title_size() -> int:
	return font_size() + 4


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		fullscreen = not fullscreen
		apply()
		save()
