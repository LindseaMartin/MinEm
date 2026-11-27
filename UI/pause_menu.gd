extends Control
## Pause / settings window. In game it also offers "Save and quit"; on the
## title screen it is just the settings. Esc closes it.

signal resumed
signal quit_requested
signal wardrobe_requested

var in_game: bool = true
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Paused" if in_game else "Settings"
	title.add_theme_font_size_override("font_size", Settings.title_size())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	box.add_child(title)

	_add_slider(box, "Sound volume", Settings.volume, _on_volume)
	_add_slider(box, "Detector beeps", Settings.beep_volume, _on_beeps)
	_add_slider(box, "Ambience", Settings.ambience, _on_ambience)
	_add_check(box, "Screen shake", Settings.screen_shake, _on_shake)
	_add_check(box, "Show tips", Settings.hints, _on_hints)
	_add_check(box, "Fullscreen", Settings.fullscreen, _on_fullscreen)

	var size_row := HBoxContainer.new()
	var size_label := Label.new()
	size_label.text = "Text size"
	size_label.custom_minimum_size = Vector2(150, 0)
	size_row.add_child(size_label)
	var size_pick := OptionButton.new()
	for size_name in Settings.TEXT_SIZE_NAMES:
		size_pick.add_item(size_name)
	size_pick.selected = Settings.text_size
	size_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_pick.item_selected.connect(_on_text_size)
	size_row.add_child(size_pick)
	box.add_child(size_row)
	var hint := Label.new()
	hint.text = "F11 toggles fullscreen at any time."
	hint.add_theme_font_size_override("font_size", Settings.small_size())
	hint.add_theme_color_override("font_color", Color(0.65, 0.63, 0.62))
	box.add_child(hint)

	var back := Button.new()
	back.text = "Resume" if in_game else "Back"
	back.pressed.connect(_resume)
	box.add_child(back)
	back.grab_focus()

	if in_game:
		var look := Button.new()
		look.text = "Change look"
		look.pressed.connect(_wardrobe)
		box.add_child(look)
		var quit := Button.new()
		quit.text = "Save and quit to title"
		quit.pressed.connect(_quit)
		box.add_child(quit)


func _on_volume(v: float) -> void:
	Settings.volume = v
	Sfx.play("coin")


func _on_beeps(v: float) -> void:
	Settings.beep_volume = v
	if v > 0.0:
		Sfx.play("beep", 1.2, -18.0 + linear_to_db(v))


func _on_ambience(v: float) -> void:
	Settings.ambience = v


func _on_text_size(index: int) -> void:
	Settings.text_size = index
	Settings.apply()


func _on_hints(on: bool) -> void:
	Settings.hints = on


func _on_shake(on: bool) -> void:
	Settings.screen_shake = on


func _on_fullscreen(on: bool) -> void:
	Settings.fullscreen = on
	Settings.apply()


func _add_slider(box: VBoxContainer, label_text: String, value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(200, 18)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	box.add_child(row)


func _add_check(box: VBoxContainer, label_text: String, value: bool, on_change: Callable) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = value
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(on_change)
	box.add_child(check)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	if _done:
		return
	_done = true
	Settings.save()
	resumed.emit()
	queue_free()


func _wardrobe() -> void:
	if _done:
		return
	_done = true
	Settings.save()
	wardrobe_requested.emit()
	queue_free()


func _quit() -> void:
	if _done:
		return
	_done = true
	Settings.save()
	quit_requested.emit()
