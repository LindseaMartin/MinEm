extends Control
## In-mine HUD: money / pack / day, the detector signal, the interaction
## prompt and short pop-up messages.

var stats_label: Label
var prompt_label: Label
var toast_box: VBoxContainer

var strength: float = 0.0          # detector signal 0..1
var direction: Vector2 = Vector2.ZERO  # towards nearest dig site (level 3)
var oil_frac: float = 1.0
var _blink: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	stats_label = _make_label()
	stats_label.position = Vector2(6, 4)
	add_child(stats_label)

	prompt_label = _make_label()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_label.offset_bottom = -10
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	add_child(prompt_label)

	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.offset_top = 24
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(toast_box)

	Game.changed.connect(_refresh)
	_refresh()


func _make_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _refresh() -> void:
	stats_label.text = "$%d    Pack %d/%d    Day %d" % [Game.money, Game.bag.size(), Game.pack_capacity(), Game.day]


func set_prompt(text: String) -> void:
	if prompt_label.text != text:
		prompt_label.text = text


func set_detector(new_strength: float, new_direction: Vector2) -> void:
	strength = new_strength
	direction = new_direction
	queue_redraw()


func set_oil(frac: float) -> void:
	if absf(frac - oil_frac) > 0.002 or frac <= 0.0:
		oil_frac = frac
		queue_redraw()


func _process(delta: float) -> void:
	_blink += delta


func toast(text: String, color: Color = Color(1, 1, 1)) -> void:
	var l := _make_label()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _draw() -> void:
	# Detector read-out in the top-right corner.
	var font := get_theme_default_font()
	var origin := Vector2(size.x - 98, 5)
	draw_string_outline(font, origin + Vector2(0, 8), "Detector", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0))
	draw_string(font, origin + Vector2(0, 8), "Detector", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))
	var bars := int(ceil(strength * 5.0))
	for i in 5:
		var h := 3.0 + i * 1.5
		var r := Rect2(origin + Vector2(42 + i * 6, 9 - h), Vector2(4, h))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.4, 1.0, 0.5) if i < bars else Color(0.3, 0.3, 0.3))
	# Lantern oil gauge.
	var oil_origin := origin + Vector2(0, 14)
	draw_string_outline(font, oil_origin + Vector2(0, 8), "Oil", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0))
	draw_string(font, oil_origin + Vector2(0, 8), "Oil", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))
	var bar := Rect2(oil_origin + Vector2(42, 3), Vector2(52, 5))
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.8))
	draw_rect(bar, Color(0.2, 0.18, 0.16))
	var oil_col := Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.3, 0.2), clampf(1.0 - oil_frac / 0.4, 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(oil_frac, 0.0, 1.0), bar.size.y)), oil_col)
	if oil_frac <= 0.0 and fmod(_blink, 0.6) < 0.3:
		draw_rect(bar, Color(1.0, 0.2, 0.2, 0.7))

	if direction != Vector2.ZERO:
		var c := origin + Vector2(82, 5)
		var d := direction.normalized()
		var side := Vector2(-d.y, d.x)
		draw_circle(c, 6.0, Color(0, 0, 0, 0.7))
		draw_colored_polygon(PackedVector2Array([c + d * 5.0, c - d * 3.0 + side * 3.0, c - d * 3.0 - side * 3.0]), Color(0.4, 1.0, 0.5))
