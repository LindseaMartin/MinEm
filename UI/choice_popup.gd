extends Control
## A small window with one button per option. Emits `chosen` with the
## option's value, or with `cancel_value` if closed with Cancel / Esc.

signal chosen(value)

var title_text: String = ""
var options: Array = []   # [[label, value], ...]
var cancel_value = null
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", Settings.title_size())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	box.add_child(title)

	var first: Button = null
	for opt in options:
		var b := Button.new()
		b.text = str(opt[0])
		b.pressed.connect(_pick.bind(opt[1]))
		box.add_child(b)
		if first == null:
			first = b
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_pick.bind(cancel_value))
	box.add_child(cancel)
	if first != null:
		first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pick(cancel_value)


func _pick(value) -> void:
	if _done:
		return
	_done = true
	chosen.emit(value)
	queue_free()
