extends Control
## In-mine HUD: money, pack, day and supplies (top left), the detector and
## lantern gauges (top right), the interaction prompt (bottom) and short
## pop-up messages (top centre).

const UiTheme := preload("res://UI/ui_theme.gd")
const GAUGE_SIZE := Vector2(230, 64)
const MARGIN := 12.0

var money_label: Label
var stats_label: Label
var place_label: Label
var supplies_label: Label
var goal_label: Label
var goal_bar: ProgressBar
var alert_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_box: VBoxContainer

var strength: float = 0.0              # detector signal 0..1
var direction: Vector2 = Vector2.ZERO  # towards nearest dig site (level 3)
var oil_frac: float = 1.0
var _blink: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Top left: who/where/what you carry.
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiTheme.hud_box())
	info.position = Vector2(MARGIN, MARGIN)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	info.add_child(rows)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	rows.add_child(top)
	money_label = _label(UiTheme.GOLD)
	money_label.add_theme_font_size_override("font_size", Settings.title_size())
	top.add_child(money_label)
	stats_label = _label(UiTheme.TEXT)
	stats_label.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(stats_label)
	place_label = _label(UiTheme.INFO)
	rows.add_child(place_label)
	supplies_label = _label(UiTheme.TEXT_DIM)
	supplies_label.add_theme_font_size_override("font_size", Settings.small_size())
	rows.add_child(supplies_label)

	# The next upgrade within reach: a goal to dig towards.
	goal_label = _label(UiTheme.TEXT)
	goal_label.add_theme_font_size_override("font_size", Settings.small_size())
	rows.add_child(goal_label)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(240, 7)
	goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(goal_bar)
	alert_label = _label(UiTheme.INFO)
	alert_label.add_theme_font_size_override("font_size", Settings.small_size())
	rows.add_child(alert_label)

	# Bottom centre: what pressing E will do.
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiTheme.hud_box())
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.offset_bottom = -20
	prompt_panel.visible = false
	add_child(prompt_panel)
	prompt_label = _label(Color(1.0, 0.95, 0.65))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)

	# Top centre: messages (kept above shop and other windows).
	toast_box = VBoxContainer.new()
	toast_box.z_index = 100
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.offset_top = 96
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.add_theme_constant_override("separation", 4)
	add_child(toast_box)

	Game.changed.connect(_refresh)
	_refresh()


func _label(color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	return l


func _refresh() -> void:
	money_label.text = "$%d" % Game.money
	stats_label.text = "Pack %d/%d     Day %d" % [Game.bag.size(), Game.pack_capacity(), Game.day]
	place_label.text = Game.depth_name()
	supplies_label.text = "Props %d   Dynamite %d   Oil flasks %d" % [
		Game.supply_count("prop"), Game.supply_count("dynamite"), Game.supply_count("flask")]
	_refresh_goal()


func _refresh_goal() -> void:
	var best_id := ""
	var best_cost := 0
	for id in Game.UPGRADES:
		var cost: int = Game.upgrade_cost(id)
		if cost < 0 or Game.upgrade_locked(id):
			continue
		if best_id == "" or cost < best_cost:
			best_id = id
			best_cost = cost
	if best_id == "":
		goal_label.text = "All gear fully upgraded!"
		goal_bar.visible = false
	else:
		var gear: String = Game.UPGRADES[best_id]["name"]
		var next_level: int = Game.level(best_id) + 1
		goal_bar.visible = true
		goal_bar.max_value = best_cost
		goal_bar.value = mini(Game.money, best_cost)
		if Game.money >= best_cost:
			goal_label.text = "Ready: %s level %d ($%d). Buy it at camp!" % [gear, next_level, best_cost]
			goal_label.add_theme_color_override("font_color", UiTheme.GOOD)
		else:
			goal_label.text = "Next: %s level %d   $%d / $%d" % [gear, next_level, Game.money, best_cost]
			goal_label.add_theme_color_override("font_color", UiTheme.TEXT)

	var alerts: Array = []
	if Game.bag.size() >= Game.pack_capacity():
		alerts.append("Pack full - sell at camp")
	for c in Game.contracts:
		if Game.contract_ready(c):
			alerts.append("A contract is ready to deliver")
			break
	alert_label.text = "   ".join(PackedStringArray(alerts))
	alert_label.visible = not alerts.is_empty()


func set_prompt(text: String) -> void:
	if prompt_label.text != text:
		prompt_label.text = text
		prompt_panel.visible = text != ""
		prompt_panel.reset_size()


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
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.hud_box())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _label(color)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	toast_box.add_child(box)
	# Keep the stack short.
	while toast_box.get_child_count() > 5:
		var oldest := toast_box.get_child(0)
		toast_box.remove_child(oldest)
		oldest.queue_free()
	var tw := box.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


func _draw() -> void:
	# Detector and lantern read-out in the top-right corner.
	var area := Rect2(Vector2(size.x - GAUGE_SIZE.x - MARGIN, MARGIN), GAUGE_SIZE)
	draw_style_box(UiTheme.hud_box(), area)
	var font := get_theme_default_font()
	var fs := Settings.font_size()
	var left := area.position.x + 12.0
	var gauge_x := area.position.x + 92.0

	var row1 := area.position.y + 24.0
	draw_string(font, Vector2(left, row1), "Detector", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
	var bars := int(ceil(strength * 5.0))
	for i in 5:
		var h := 6.0 + i * 3.0
		var r := Rect2(Vector2(gauge_x + i * 14.0, row1 - h), Vector2(9, h))
		draw_rect(r, Color(0.4, 1.0, 0.5) if i < bars else Color(0.25, 0.25, 0.25))
	if direction != Vector2.ZERO:
		var c := Vector2(area.end.x - 24.0, row1 - 6.0)
		var d := direction.normalized()
		var side := Vector2(-d.y, d.x)
		draw_circle(c, 11.0, Color(0, 0, 0, 0.6))
		draw_colored_polygon(PackedVector2Array([c + d * 9.0, c - d * 5.0 + side * 6.0, c - d * 5.0 - side * 6.0]), Color(0.4, 1.0, 0.5))

	var row2 := area.position.y + 50.0
	draw_string(font, Vector2(left, row2), "Lantern", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
	var bar := Rect2(Vector2(gauge_x, row2 - 11.0), Vector2(area.end.x - gauge_x - 12.0, 10))
	draw_rect(bar, Color(0.15, 0.13, 0.12))
	var oil_col := Color(1.0, 0.8, 0.3).lerp(Color(1.0, 0.3, 0.2), clampf(1.0 - oil_frac / 0.4, 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(oil_frac, 0.0, 1.0), bar.size.y)), oil_col)
	if oil_frac <= 0.0 and fmod(_blink, 0.6) < 0.3:
		draw_rect(bar, Color(1.0, 0.2, 0.2, 0.7))
	draw_rect(bar, Color(0.45, 0.35, 0.2), false, 1.0)
