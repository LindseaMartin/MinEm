extends Control
## A small one-time tip that points at something: a HUD element (Rect2 or
## Control) or a thing in the mine (Node2D, followed as it moves on screen).
## If a world target is off screen, the bubble sits at the screen edge and
## its arrow points the way. Fades out by itself after `duration`.

signal finished

const UiTheme := preload("res://UI/ui_theme.gd")
const WIDTH := 260.0
const EDGE := 20.0

var text: String = ""
var target = null          # Rect2, Control, Node2D or null (top centre)
var duration: float = 7.0

var _box: PanelContainer
var _time: float = 0.0
var _point := Vector2.ZERO  # where the arrow points, in screen space
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.09, 0.05, 0.95), UiTheme.GOLD, 2, 5, 10.0, 7.0))
	add_child(_box)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 20.0, 0)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	label.add_theme_font_size_override("font_size", Settings.small_size() + 1)
	_box.add_child(label)
	modulate.a = 0.0
	Sfx.play("sparkle", 1.4, -18.0)


func _target_rect() -> Rect2:
	if typeof(target) == TYPE_RECT2:
		return target
	if typeof(target) != TYPE_OBJECT or not is_instance_valid(target):
		return Rect2(Vector2(size.x * 0.5, 0), Vector2.ZERO)
	if target is Control:
		return target.get_global_rect()
	if target is Node2D:
		var p: Vector2 = target.get_global_transform_with_canvas().origin
		return Rect2(p - Vector2(10, 14), Vector2(20, 20))
	return Rect2(Vector2(size.x * 0.5, 0), Vector2.ZERO)


func _process(delta: float) -> void:
	_time += delta
	# Fade in, hold, fade out.
	modulate.a = clampf(minf(_time * 4.0, (duration - _time) * 2.0), 0.0, 1.0)
	if _time >= duration:
		dismiss()
		return
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
		dismiss()  # what it pointed at is gone (dug up, picked...)
		return
	var screen := size
	var r := _target_rect()
	var aim := r.get_center()
	var inside := Rect2(Vector2(EDGE, EDGE), screen - Vector2(EDGE, EDGE) * 2.0)
	var off_screen := not inside.has_point(aim)
	_point = Vector2(clampf(aim.x, EDGE, screen.x - EDGE), clampf(aim.y, EDGE, screen.y - EDGE))
	var box_size := _box.get_combined_minimum_size()
	_box.size = box_size
	var pos: Vector2
	if off_screen:
		# Sit just inside the edge, towards the target.
		pos = _point - box_size * 0.5 - (_point - screen * 0.5).normalized() * 50.0
	elif aim.y < screen.y * 0.5:
		pos = Vector2(aim.x - box_size.x * 0.5, r.end.y + 16.0)   # below the target
	else:
		pos = Vector2(aim.x - box_size.x * 0.5, r.position.y - box_size.y - 16.0)  # above it
	pos.x = clampf(pos.x, 8.0, screen.x - box_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, screen.y - box_size.y - 8.0)
	_box.position = pos
	if typeof(target) == TYPE_NIL:
		_point = Vector2(-1, -1)
	queue_redraw()


func _draw() -> void:
	if _point.x < 0.0:
		return
	var box := Rect2(_box.position, _box.size)
	var from := Vector2(clampf(_point.x, box.position.x + 12.0, box.end.x - 12.0), clampf(_point.y, box.position.y, box.end.y))
	var dir := _point - from
	if dir.length() < 6.0:
		return
	var d := dir.normalized()
	var side := Vector2(-d.y, d.x)
	var bob := 3.0 * sin(_time * 6.0)
	var tip := _point - d * (6.0 + bob)
	var base := tip - d * 12.0
	draw_line(from, base, UiTheme.GOLD, 2.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side * 7.0, base - side * 7.0]), UiTheme.GOLD)


func dismiss() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
