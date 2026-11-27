extends Control
## Full-screen map of the current level (Tab). Only shows what your lantern
## has lit up so far, plus the camp, shafts, crates and dig sites you've seen.

const UiTheme := preload("res://UI/ui_theme.gd")

var mine   # the Levels/mine.gd node
var _bounds := Rect2i()
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mine == null or mine._reach.is_empty():
		return
	var first: Vector2i = mine._order[0]
	var lo := first
	var hi := first
	for cell in mine._reach:
		lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
		hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	_bounds = Rect2i(lo - Vector2i.ONE, hi - lo + Vector2i(3, 3))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _cell_of(node: Node2D) -> Vector2i:
	return mine.tile_map.local_to_map(mine.tile_map.to_local(node.global_position))


func _marker(origin: Vector2, cell_px: float, cell: Vector2i, col: Color, radius: float) -> void:
	draw_circle(origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_px, radius, col)


func _draw() -> void:
	if mine == null or _bounds.size.x <= 0:
		return
	var font := get_theme_default_font()
	var fs := Settings.font_size()
	var panel := Rect2(Vector2(48, 40), size - Vector2(96, 80))
	draw_style_box(UiTheme.box(UiTheme.PANEL_BG, UiTheme.PANEL_EDGE, 2, 5), panel)
	draw_string(font, panel.position + Vector2(14, 12 + fs), "%s  -  Tab to close" % Game.depth_name(mine.depth),
		HORIZONTAL_ALIGNMENT_LEFT, -1, Settings.title_size(), UiTheme.GOLD)

	var area := panel.grow(-16.0)
	area.position.y += 16 + fs
	area.size.y -= 32 + fs * 2
	var cell_px := floorf(minf(area.size.x / _bounds.size.x, area.size.y / _bounds.size.y))
	cell_px = maxf(cell_px, 1.0)
	var map_size := Vector2(_bounds.size) * cell_px
	var origin := area.position + (area.size - map_size) * 0.5 - Vector2(_bounds.position) * cell_px

	var seen: Dictionary = Game.explored_cells(mine.depth)
	for cell in seen:
		if not _bounds.has_point(cell):
			continue
		var r := Rect2(origin + Vector2(cell) * cell_px, Vector2(cell_px, cell_px))
		if mine._reach.has(cell):
			draw_rect(r, Color(0.55, 0.45, 0.32))
		else:
			draw_rect(r, Color(0.2, 0.16, 0.14))

	if mine.trader != null:
		_marker(origin, cell_px, _cell_of(mine.trader), Color(1.0, 0.55, 0.2), 6.0)
	if mine.shaft != null and seen.has(_cell_of(mine.shaft)):
		_marker(origin, cell_px, _cell_of(mine.shaft), Color(0.1, 0.1, 0.1), 6.0)
		_marker(origin, cell_px, _cell_of(mine.shaft), Color(0.8, 0.8, 0.9), 3.0)
	if mine.ladder != null:
		_marker(origin, cell_px, _cell_of(mine.ladder), Color(0.75, 0.85, 1.0), 5.0)
	for c in mine.caches:
		if not c.opened and seen.has(_cell_of(c)):
			var p: Vector2 = origin + (Vector2(_cell_of(c)) + Vector2(0.5, 0.5)) * cell_px
			draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(0.8, 0.6, 0.3))
	for s in mine.spots:
		if s.revealed:
			var col := Color(1.0, 0.35, 0.25) if s.special == "heart" else Color(1.0, 0.95, 0.5)
			_marker(origin, cell_px, _cell_of(s), col, 4.0)
	if fmod(_time, 0.8) < 0.55:
		_marker(origin, cell_px, _cell_of(mine.player), Color(1, 1, 1), 5.0)

	var legend := "White: you   Orange: camp   Grey: shaft   Blue: ladder   Brown: crate   Yellow: dig site"
	draw_string(font, Vector2(panel.position.x + 14, panel.end.y - 12), legend, HORIZONTAL_ALIGNMENT_LEFT, -1, Settings.small_size(), UiTheme.TEXT_DIM)
