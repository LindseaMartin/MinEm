extends Control
## A simple message window (journal pages, the ending). Closes with the
## button, E, Space or Esc and emits `closed`.

signal closed

var title_text: String = ""
var body_text: String = ""
var button_text: String = "Close"
var accent: Color = Color(0.95, 0.85, 0.6)
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", Settings.title_size())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", accent)
	box.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(510, 0)
	box.add_child(body)

	var button := Button.new()
	button.text = button_text
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_close)
	box.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()
