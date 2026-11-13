extends Control
## The wall the player chips away at. Each cell has 0-3 layers of stone
## (tan soil -> dark soil -> rock) and treasures are buried underneath.
##
## Rules:
##  * Every strike costs wall stability. At 0 the wall collapses and only
##    fully uncovered treasures are kept.
##  * Striking a treasure that is already exposed (or punching through to it
##    with the hammer's heavy centre) damages it and lowers its value.
##  * Cracked "fault" cells cost a lot of extra stability when struck.

signal changed
signal treasure_found(treasure)
signal treasure_damaged(treasure)
signal collapsed
signal cleared
signal notice(text)

const COLS := 13
const ROWS := 9
const CELL := 22
const FAULT_COST := 6.0
const ROCK_COST := 1.0
const DYNAMITE_COST := 10.0
const PROP_AMOUNT := 30.0

var thickness: Array = []      # thickness[y][x] -> layers left
var faults: Dictionary = {}    # Vector2i -> true
var pings: Dictionary = {}     # Vector2i -> bool (scan result)
var treasures: Array = []      # [{id, x, y, w, h, cond, found}]
var owner_of: Dictionary = {}  # Vector2i -> index into treasures

var stability: float = 100.0
var stability_max: float = 100.0
var scans_left: int = 0
var tool_name: String = "pick"
var active: bool = true
var has_collapsed: bool = false

var _hover := Vector2i(-1, -1)
var _shake: float = 0.0
var _flash: float = 0.0
var _particles: Array = []
var _cracks: Array = []
var _layer_tex: Array = []
var _back_tex: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	custom_minimum_size = Vector2(COLS * CELL, ROWS * CELL)
	size = custom_minimum_size
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_layer_tex = [
		load("res://Art/tansoil.png"),
		load("res://Art/darksoil.png"),
		load("res://Art/rock.png"),
	]
	_back_tex = load("res://Art/cavewall.png")
	mouse_exited.connect(_on_mouse_exited)


func generate(tier: int) -> void:
	stability_max = Game.wall_stability()
	stability = stability_max
	scans_left = Game.scan_charges()

	# Stone layers.
	thickness = []
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			var t := 1 + (randi() % 2)
			if randf() < 0.1 + 0.1 * tier:
				t += 1
			row.append(mini(t, 3))
		thickness.append(row)
	# Clumps of solid rock.
	for i in 1 + tier:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		var rad := 1.0 + randf() * 1.2
		for y in ROWS:
			for x in COLS:
				if Vector2(x - c.x, y - c.y).length() <= rad:
					thickness[y][x] = 3

	# Buried treasure.
	treasures = []
	owner_of = {}
	var count := 2 + tier + (randi() % 2) + Game.extra_treasures()
	for i in count:
		_place_treasure(Game.roll_treasure(tier))
	if treasures.is_empty():
		_place_treasure("copper")

	# Fault lines.
	faults = {}
	for i in 3 + tier * 2:
		faults[Vector2i(randi() % COLS, randi() % ROWS)] = true

	# Cracks that spread across the wall as stability drops (visual only).
	_cracks = []
	var wall_size := Vector2(COLS * CELL, ROWS * CELL)
	for i in 12:
		var p := Vector2(randf() * wall_size.x, 0.0 if randf() < 0.5 else wall_size.y)
		var line := PackedVector2Array([p])
		for s in 4 + randi() % 3:
			var toward := (wall_size * 0.5 - p).normalized()
			p += toward * randf_range(10.0, 22.0) + Vector2(randf_range(-12, 12), randf_range(-8, 8))
			line.append(p)
		_cracks.append(line)
	queue_redraw()


func _place_treasure(id: String) -> bool:
	var def: Dictionary = Game.TREASURES[id]
	var w := int(def["w"])
	var h := int(def["h"])
	for attempt in 40:
		var x := randi() % (COLS - w + 1)
		var y := randi() % (ROWS - h + 1)
		var free := true
		for cy in range(y, y + h):
			for cx in range(x, x + w):
				if owner_of.has(Vector2i(cx, cy)):
					free = false
		if not free:
			continue
		for cy in range(y, y + h):
			for cx in range(x, x + w):
				owner_of[Vector2i(cx, cy)] = treasures.size()
		treasures.append({"id": id, "x": x, "y": y, "w": w, "h": h, "cond": 0, "found": false})
		return true
	return false


func found_items() -> Array:
	var out: Array = []
	for t in treasures:
		if t["found"]:
			out.append({"id": t["id"], "cond": t["cond"]})
	return out


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _cell_at(event.position)
		if c != _hover:
			_hover = c
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hover = _cell_at(event.position)
		strike(_hover)


func _on_mouse_exited() -> void:
	_hover = Vector2i(-1, -1)
	queue_redraw()


func _cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
	if not _inside(c):
		return Vector2i(-1, -1)
	return c


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


## Cells hit by the current tool: [[cell, layers_removed], ...]
func _footprint(c: Vector2i) -> Array:
	var out: Array = []
	if tool_name == "pick":
		out.append([c, 1])
	elif tool_name == "dynamite":
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				out.append([c + Vector2i(dx, dy), 9])
	elif tool_name == "hammer":
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not Game.hammer_is_wide() and dx != 0 and dy != 0:
					continue
				out.append([c + Vector2i(dx, dy), 2 if (dx == 0 and dy == 0) else 1])
	else:
		var r := Game.scan_radius()
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				out.append([c + Vector2i(dx, dy), 0])
	return out


func strike(c: Vector2i) -> void:
	if not active or not _inside(c):
		return
	if tool_name == "scan":
		_scan(c)
		return
	if tool_name == "dynamite" and Game.supply_count("dynamite") <= 0:
		notice.emit("You are out of dynamite. The trader sells more.")
		Sfx.play("deny")
		return

	var chipped := false
	var rock_hit := false
	var fault_hits := 0
	var damaged: Dictionary = {}
	for entry in _footprint(c):
		var cell: Vector2i = entry[0]
		var layers: int = entry[1]
		if not _inside(cell):
			continue
		var th: int = thickness[cell.y][cell.x]
		var buried: bool = owner_of.has(cell) and not treasures[owner_of[cell]]["found"]
		if th == 0:
			if buried:
				damaged[owner_of[cell]] = true
			continue
		if layers > th and buried:
			damaged[owner_of[cell]] = true
		chipped = true
		if th == 3:
			rock_hit = true
		if faults.has(cell):
			fault_hits += 1
		thickness[cell.y][cell.x] = maxi(th - layers, 0)
		if thickness[cell.y][cell.x] == 0:
			faults.erase(cell)
		_burst(cell, th)

	if not chipped and damaged.is_empty():
		return

	var cost := Game.pick_cost()
	if tool_name == "hammer":
		cost = Game.hammer_cost()
		Sfx.play("thud", randf_range(0.9, 1.1))
	elif tool_name == "dynamite":
		cost = DYNAMITE_COST
		Game.use_supply("dynamite")
		Sfx.play("blast")
	else:
		Sfx.play("rock" if rock_hit else "chip", randf_range(0.85, 1.2))
	if rock_hit:
		cost += ROCK_COST
	cost += FAULT_COST * fault_hits
	if fault_hits > 0:
		notice.emit("You struck a fault line! The wall shudders.")
	_shake = 2.0 if tool_name == "pick" else 4.0
	if tool_name == "dynamite":
		_shake = 9.0
	if fault_hits > 0:
		_shake = 6.0

	for idx in damaged:
		var t: Dictionary = treasures[idx]
		t["cond"] = mini(int(t["cond"]) + 1, Game.CONDITIONS.size() - 1)
		_flash = 0.35
		Sfx.play("damage")
		treasure_damaged.emit(t)

	for t in treasures:
		if t["found"]:
			continue
		var exposed := true
		for cy in range(t["y"], t["y"] + t["h"]):
			for cx in range(t["x"], t["x"] + t["w"]):
				if thickness[cy][cx] > 0:
					exposed = false
		if exposed:
			t["found"] = true
			Sfx.play("found")
			treasure_found.emit(t)

	stability = maxf(stability - cost, 0.0)
	var all_found := true
	for t in treasures:
		if not t["found"]:
			all_found = false
	if all_found:
		active = false
		cleared.emit()
	elif stability <= 0.0:
		active = false
		has_collapsed = true
		_shake = 10.0
		Sfx.play("collapse")
		collapsed.emit()
	changed.emit()
	queue_redraw()


## Uses a timber prop from the pack to win back some stability.
func shore_up() -> void:
	if not active:
		return
	if stability >= stability_max:
		notice.emit("The wall is already as solid as it gets.")
		return
	if not Game.use_supply("prop"):
		notice.emit("You have no timber props. The trader sells them.")
		Sfx.play("deny")
		return
	stability = minf(stability + PROP_AMOUNT, stability_max)
	Sfx.play("prop")
	notice.emit("You wedge a timber prop into place. The wall steadies.")
	changed.emit()
	queue_redraw()


func _scan(c: Vector2i) -> void:
	if scans_left <= 0:
		notice.emit("The detector is out of charge for this wall.")
		Sfx.play("deny")
		return
	scans_left -= 1
	Sfx.play("beep", 1.3)
	var hits := 0
	for entry in _footprint(c):
		var cell: Vector2i = entry[0]
		if not _inside(cell):
			continue
		var hit: bool = owner_of.has(cell) and not treasures[owner_of[cell]]["found"]
		pings[cell] = hit
		if hit:
			hits += 1
	if hits > 0:
		notice.emit("Beep! Something is buried here.")
	else:
		notice.emit("Nothing but stone in that patch.")
	changed.emit()
	queue_redraw()


func _burst(cell: Vector2i, layer: int) -> void:
	var colors := [Color(0.78, 0.62, 0.42), Color(0.45, 0.32, 0.22), Color(0.5, 0.5, 0.52)]
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
	for i in 5:
		_particles.append({
			"pos": center + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2(randf_range(-40, 40), randf_range(-70, -10)),
			"life": randf_range(0.25, 0.5),
			"col": colors[clampi(layer - 1, 0, 2)],
		})


# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	var animating := _shake > 0.0 or _flash > 0.0 or not _particles.is_empty()
	_shake = maxf(_shake - delta * 14.0, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	for p in _particles:
		p["life"] -= delta
		p["vel"] = p["vel"] + Vector2(0, 260.0 * delta)
		p["pos"] = p["pos"] + p["vel"] * delta
	_particles = _particles.filter(func(p): return p["life"] > 0.0)
	if animating:
		queue_redraw()


func _draw() -> void:
	var wall_rect := Rect2(Vector2.ZERO, Vector2(COLS * CELL, ROWS * CELL))
	var offset := Vector2.ZERO
	if _shake > 0.0:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	draw_set_transform(offset, 0.0, Vector2.ONE)

	# Bare cave wall behind everything.
	draw_texture_rect(_back_tex, wall_rect.grow(12.0), false, Color(0.5, 0.45, 0.45))

	# Treasures (stone is drawn over the parts still buried).
	for t in treasures:
		var r := Rect2(Vector2(t["x"], t["y"]) * CELL, Vector2(t["w"], t["h"]) * CELL)
		if t["found"]:
			draw_rect(r.grow(-1.0), Color(1, 1, 0.6, 0.12))
			Game.draw_treasure(self, t["id"], r, 0.35)
		else:
			Game.draw_treasure(self, t["id"], r)

	# Stone.
	for y in ROWS:
		for x in COLS:
			var th: int = thickness[y][x]
			var cell := Vector2i(x, y)
			var r := Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL))
			if th > 0:
				_rng.seed = x * 7919 + y * 104729 + th * 31
				var shade := 0.9 + _rng.randf() * 0.2
				draw_texture_rect(_layer_tex[th - 1], r, false, Color(shade, shade, shade))
				for i in 3:
					var sp := r.position + Vector2(_rng.randf_range(2, CELL - 4), _rng.randf_range(2, CELL - 4))
					draw_rect(Rect2(sp, Vector2(2, 2)), Color(0, 0, 0, 0.18))
				if th == 3:
					draw_line(r.position + Vector2(4, 15), r.position + Vector2(10, 6), Color(1, 1, 1, 0.12), 1.0)
					draw_line(r.position + Vector2(10, 6), r.position + Vector2(17, 12), Color(1, 1, 1, 0.12), 1.0)
				draw_line(r.position, r.position + Vector2(CELL, 0), Color(1, 1, 1, 0.1), 1.0)
				draw_line(r.position, r.position + Vector2(0, CELL), Color(1, 1, 1, 0.1), 1.0)
				draw_line(r.position + Vector2(0, CELL), r.end, Color(0, 0, 0, 0.3), 1.0)
				draw_line(r.position + Vector2(CELL, 0), r.end, Color(0, 0, 0, 0.3), 1.0)
				if faults.has(cell):
					var pts := PackedVector2Array([
						r.position + Vector2(3, 4), r.position + Vector2(9, 9),
						r.position + Vector2(7, 13), r.position + Vector2(15, 16),
						r.position + Vector2(18, 20)])
					draw_polyline(pts, Color(0.08, 0.03, 0.03, 0.9), 1.5)
					draw_line(r.position + Vector2(9, 9), r.position + Vector2(16, 6), Color(0.08, 0.03, 0.03, 0.9), 1.0)
			if pings.has(cell):
				if pings[cell] and th > 0:
					draw_circle(r.get_center(), 4.0, Color(0.3, 1.0, 0.5, 0.35))
					draw_circle(r.get_center(), 2.0, Color(0.6, 1.0, 0.7, 0.95))
				elif not pings[cell] and th > 0:
					draw_circle(r.get_center(), 1.0, Color(0, 0, 0, 0.45))

	# Stress cracks.
	var shown := int((1.0 - stability / stability_max) * _cracks.size())
	for i in mini(shown, _cracks.size()):
		draw_polyline(_cracks[i], Color(0, 0, 0, 0.55), 1.0)

	# Tool preview.
	if active and _inside(_hover):
		var col := Color(1, 1, 1, 0.9)
		if tool_name == "hammer":
			col = Color(1.0, 0.7, 0.3, 0.9)
		elif tool_name == "scan":
			col = Color(0.4, 1.0, 0.6, 0.9)
		elif tool_name == "dynamite":
			col = Color(1.0, 0.3, 0.25, 0.95)
		for entry in _footprint(_hover):
			var cell: Vector2i = entry[0]
			if _inside(cell):
				var r := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)).grow(-1.0)
				draw_rect(r, col, false, 2.0 if entry[1] == 2 else 1.0)

	for p in _particles:
		draw_rect(Rect2(p["pos"], Vector2(2, 2)), p["col"])

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _flash > 0.0:
		draw_rect(wall_rect, Color(1, 0.1, 0.1, _flash))
	if has_collapsed:
		draw_rect(wall_rect, Color(0.05, 0.03, 0.02, 0.7))
		draw_string(get_theme_default_font(), Vector2(0, wall_rect.size.y * 0.5 + 6), "COLLAPSED",
			HORIZONTAL_ALIGNMENT_CENTER, wall_rect.size.x, 24, Color(1, 0.5, 0.4))
	draw_rect(wall_rect, Color(0, 0, 0, 0.8), false, 2.0)
