extends Node
## Global game state (autoload "Game"): money, backpack, upgrades, the
## treasure catalogue and saving/loading.

signal changed

const SAVE_PATH := "user://minem_save.json"

## A treasure loses condition every time it is struck while exposed.
const CONDITIONS := [
	{"name": "Pristine", "mult": 1.0},
	{"name": "Chipped", "mult": 0.7},
	{"name": "Cracked", "mult": 0.4},
	{"name": "Ruined", "mult": 0.15},
]

## w/h are the size in wall cells. "tier" is the poorest dig site (1-3) the
## treasure can appear in. "weight" is how common it is.
const TREASURES := {
	"copper": {"name": "Copper Nugget", "w": 1, "h": 1, "value": 8, "tier": 1, "weight": 10, "kind": "nugget", "color": "c8723c"},
	"quartz": {"name": "Quartz Shard", "w": 1, "h": 2, "value": 15, "tier": 1, "weight": 8, "kind": "shard", "color": "e6e6f5"},
	"coin": {"name": "Old Coin", "w": 1, "h": 1, "value": 22, "tier": 1, "weight": 6, "kind": "coin", "color": "c9a227"},
	"silver": {"name": "Silver Ore", "w": 2, "h": 1, "value": 30, "tier": 1, "weight": 6, "kind": "ore", "color": "d5dbe3"},
	"lantern": {"name": "Lost Lantern", "w": 1, "h": 2, "value": 55, "tier": 1, "weight": 3, "kind": "lantern", "color": "8a6a3a"},
	"amethyst": {"name": "Amethyst", "w": 2, "h": 2, "value": 60, "tier": 1, "weight": 3, "kind": "gem", "color": "9b5de5"},
	"ammonite": {"name": "Ammonite", "w": 2, "h": 2, "value": 75, "tier": 1, "weight": 3, "kind": "fossil", "color": "d9b38c", "frame": 1},
	"gold": {"name": "Gold Nugget", "w": 1, "h": 1, "value": 80, "tier": 2, "weight": 5, "kind": "nugget", "color": "f2c230"},
	"emerald": {"name": "Emerald", "w": 2, "h": 2, "value": 130, "tier": 2, "weight": 4, "kind": "gem", "color": "2fbf71"},
	"raptor": {"name": "Raptor Skeleton", "w": 4, "h": 3, "value": 240, "tier": 2, "weight": 3, "kind": "fossil", "color": "d9b38c", "frame": 0},
	"miner": {"name": "Ancient Miner", "w": 2, "h": 3, "value": 280, "tier": 2, "weight": 2, "kind": "fossil", "color": "d9b38c", "frame": 2},
	"ruby": {"name": "Ruby", "w": 2, "h": 2, "value": 220, "tier": 3, "weight": 4, "kind": "gem", "color": "e0314f"},
	"croc": {"name": "Croc Skeleton", "w": 4, "h": 2, "value": 320, "tier": 3, "weight": 3, "kind": "fossil", "color": "d9b38c", "frame": 3},
	"ptero": {"name": "Pterosaur", "w": 3, "h": 3, "value": 400, "tier": 3, "weight": 2, "kind": "fossil", "color": "d9b38c", "frame": 4},
	"diamond": {"name": "Diamond", "w": 2, "h": 2, "value": 480, "tier": 3, "weight": 2, "kind": "gem", "color": "9be8f5"},
}

## "costs"[i] is the price of going from level i+1 to level i+2.
const UPGRADES := {
	"pick": {"name": "Pickaxe", "costs": [120, 450], "levels": [
		"Chips one layer. Costs 2 stability.",
		"Balanced head: costs 1.5 stability.",
		"Master's pick: costs 1 stability."]},
	"hammer": {"name": "Hammer", "costs": [150, 500], "levels": [
		"Cross-shaped blow. Costs 6 stability.",
		"Wide 3x3 blow. Costs 7 stability.",
		"Padded 3x3 blow. Costs 5 stability."]},
	"detector": {"name": "Metal Detector", "costs": [100, 400], "levels": [
		"Short range. 2 wall scans (3x3).",
		"Longer range, rates dig sites. 3 scans (5x5).",
		"Long range, points the way. 4 scans (7x7)."]},
	"pack": {"name": "Backpack", "costs": [80, 300], "levels": [
		"Holds 6 finds.",
		"Holds 10 finds.",
		"Holds 16 finds."]},
	"brace": {"name": "Wall Braces", "costs": [140, 480], "levels": [
		"Walls have 100 stability.",
		"Walls have 125 stability.",
		"Walls have 150 stability."]},
}

var money: int = 0
var day: int = 1
var bag: Array = []            # [{"id": String, "cond": int}]
var upgrades: Dictionary = {}  # upgrade id -> level (1..3)
var collection: Dictionary = {}  # treasure id -> number found

var _fossil_tex: Texture2D
var _fossil_regions: Array = []


func _ready() -> void:
	_setup_input()
	reset()
	load_game()


func reset() -> void:
	money = 0
	day = 1
	bag = []
	collection = {}
	upgrades = {}
	for id in UPGRADES:
		upgrades[id] = 1


func _setup_input() -> void:
	_add_key("interact", KEY_E)
	_add_key("interact", KEY_SPACE)
	_add_key("up", KEY_UP)
	_add_key("down", KEY_DOWN)
	_add_key("left", KEY_LEFT)
	_add_key("right", KEY_RIGHT)


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- upgrades

func level(id: String) -> int:
	return int(upgrades.get(id, 1))

func max_level(id: String) -> int:
	return UPGRADES[id]["levels"].size()

func upgrade_cost(id: String) -> int:
	if level(id) >= max_level(id):
		return -1
	return int(UPGRADES[id]["costs"][level(id) - 1])

func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or money < cost:
		return false
	money -= cost
	upgrades[id] = level(id) + 1
	save_game()
	changed.emit()
	return true

func pick_cost() -> float:
	return [2.0, 1.5, 1.0][level("pick") - 1]

func hammer_cost() -> float:
	return [6.0, 7.0, 5.0][level("hammer") - 1]

func hammer_is_wide() -> bool:
	return level("hammer") >= 2

func detector_range_cells() -> int:
	return [7, 11, 16][level("detector") - 1]

func scan_radius() -> int:
	return level("detector")

func scan_charges() -> int:
	return level("detector") + 1

func pack_capacity() -> int:
	return [6, 10, 16][level("pack") - 1]

func max_stability() -> float:
	return [100.0, 125.0, 150.0][level("brace") - 1]


# ---------------------------------------------------------------- treasure

func item_value(item: Dictionary) -> int:
	var base: float = float(TREASURES[item["id"]]["value"])
	return int(round(base * float(CONDITIONS[int(item["cond"])]["mult"])))

func item_label(item: Dictionary) -> String:
	return "%s (%s)" % [TREASURES[item["id"]]["name"], CONDITIONS[int(item["cond"])]["name"]]

## Puts a find in the backpack. Returns the first-discovery bonus (0 if this
## kind of treasure has been found before).
func add_to_bag(id: String, cond: int) -> int:
	bag.append({"id": id, "cond": cond})
	var bonus := 0
	if not collection.has(id):
		bonus = int(TREASURES[id]["value"]) / 2
		money += bonus
	collection[id] = int(collection.get(id, 0)) + 1
	changed.emit()
	return bonus

func sell(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	money += item_value(bag[index])
	bag.remove_at(index)
	save_game()
	changed.emit()

func sell_all() -> void:
	for item in bag:
		money += item_value(item)
	bag = []
	save_game()
	changed.emit()

func bag_value() -> int:
	var total := 0
	for item in bag:
		total += item_value(item)
	return total

## Random treasure id that can appear in a dig site of the given tier.
func roll_treasure(tier: int) -> String:
	var pool: Array = []
	var total := 0.0
	for id in TREASURES:
		var t: Dictionary = TREASURES[id]
		if int(t["tier"]) > tier:
			continue
		# Richer sites lean towards their own tier's treasure.
		var w: float = float(t["weight"])
		if int(t["tier"]) == tier:
			w *= 2.0
		pool.append([id, w])
		total += w
	var roll := randf() * total
	for entry in pool:
		roll -= float(entry[1])
		if roll <= 0.0:
			return entry[0]
	return pool[0][0]


# ---------------------------------------------------------------- saving

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"money": money, "day": day, "bag": bag,
		"upgrades": upgrades, "collection": collection,
	}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	money = int(data.get("money", 0))
	day = int(data.get("day", 1))
	var saved_up = data.get("upgrades", {})
	if typeof(saved_up) == TYPE_DICTIONARY:
		for id in UPGRADES:
			upgrades[id] = clampi(int(saved_up.get(id, 1)), 1, max_level(id))
	var saved_bag = data.get("bag", [])
	if typeof(saved_bag) == TYPE_ARRAY:
		for item in saved_bag:
			if typeof(item) == TYPE_DICTIONARY and TREASURES.has(item.get("id", "")):
				bag.append({"id": str(item["id"]), "cond": clampi(int(item.get("cond", 0)), 0, CONDITIONS.size() - 1)})
	var saved_col = data.get("collection", {})
	if typeof(saved_col) == TYPE_DICTIONARY:
		for id in saved_col:
			if TREASURES.has(id):
				collection[id] = int(saved_col[id])
	changed.emit()


# ---------------------------------------------------------------- drawing
# Treasures are drawn with code so no extra art is needed. Fossils use the
# skeletons in Art/fossils3.PNG (its green background is removed at runtime).

func draw_treasure(ci: CanvasItem, id: String, rect: Rect2, alpha: float = 1.0) -> void:
	var t: Dictionary = TREASURES[id]
	var col := Color(str(t["color"]))
	col.a = alpha
	var r := rect.grow(-1.0)
	match str(t["kind"]):
		"fossil":
			_draw_fossil(ci, int(t["frame"]), r, alpha)
		"nugget":
			_draw_nugget(ci, r, col)
		"ore":
			_draw_nugget(ci, r, Color(0.42, 0.38, 0.36, alpha))
			for p in [Vector2(0.3, 0.45), Vector2(0.55, 0.3), Vector2(0.7, 0.6), Vector2(0.45, 0.7)]:
				var c: Vector2 = r.position + p * r.size
				var s := minf(r.size.x, r.size.y) * 0.12
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)
		"gem":
			ci.draw_colored_polygon(_pts(r, [0.3, 0.08, 0.7, 0.08, 0.92, 0.3, 0.92, 0.7, 0.7, 0.92, 0.3, 0.92, 0.08, 0.7, 0.08, 0.3]), col.darkened(0.3))
			ci.draw_colored_polygon(_pts(r, [0.36, 0.25, 0.64, 0.25, 0.75, 0.36, 0.75, 0.64, 0.64, 0.75, 0.36, 0.75, 0.25, 0.64, 0.25, 0.36]), col)
			ci.draw_colored_polygon(_pts(r, [0.36, 0.25, 0.64, 0.25, 0.52, 0.42, 0.4, 0.42]), col.lightened(0.5))
		"coin":
			var c := r.get_center()
			var rad := minf(r.size.x, r.size.y) * 0.42
			ci.draw_circle(c, rad, col.darkened(0.35))
			ci.draw_circle(c, rad * 0.8, col)
			ci.draw_circle(c, rad * 0.45, col.darkened(0.2))
			ci.draw_circle(c + Vector2(-rad, -rad) * 0.3, rad * 0.15, col.lightened(0.5))
		"shard":
			ci.draw_colored_polygon(_pts(r, [0.5, 0.04, 0.8, 0.25, 0.72, 0.8, 0.5, 0.96, 0.28, 0.8, 0.2, 0.25]), col.darkened(0.25))
			ci.draw_colored_polygon(_pts(r, [0.5, 0.04, 0.5, 0.96, 0.28, 0.8, 0.2, 0.25]), col)
		"lantern":
			ci.draw_rect(_sub(r, 0.36, 0.04, 0.28, 0.14), col.darkened(0.3), false, 1.0)
			ci.draw_rect(_sub(r, 0.22, 0.18, 0.56, 0.12), col)
			ci.draw_rect(_sub(r, 0.3, 0.3, 0.4, 0.46), Color(1.0, 0.85, 0.4, alpha))
			ci.draw_rect(_sub(r, 0.44, 0.42, 0.12, 0.26), Color(1.0, 0.98, 0.8, alpha))
			ci.draw_rect(_sub(r, 0.18, 0.76, 0.64, 0.16), col.darkened(0.15))


func _draw_nugget(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_colored_polygon(_pts(r, [0.2, 0.35, 0.45, 0.15, 0.75, 0.2, 0.9, 0.5, 0.75, 0.82, 0.4, 0.88, 0.12, 0.65]), col)
	ci.draw_colored_polygon(_pts(r, [0.3, 0.38, 0.48, 0.25, 0.62, 0.3, 0.5, 0.48]), col.lightened(0.4))
	ci.draw_colored_polygon(_pts(r, [0.55, 0.65, 0.78, 0.55, 0.72, 0.78, 0.45, 0.82]), col.darkened(0.3))


func _draw_fossil(ci: CanvasItem, frame: int, r: Rect2, alpha: float) -> void:
	if _fossil_tex == null:
		_prepare_fossils()
	var src: Rect2 = _fossil_regions[clampi(frame, 0, _fossil_regions.size() - 1)]
	var s := minf(r.size.x / src.size.x, r.size.y / src.size.y)
	var sz := src.size * s
	var dest := Rect2(r.position + (r.size - sz) * 0.5, sz)
	ci.draw_texture_rect_region(_fossil_tex, dest, src, Color(1, 1, 1, alpha))


func _prepare_fossils() -> void:
	var tex: Texture2D = load("res://Art/fossils3.PNG")
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var key := img.get_pixel(0, 0)
	var col_used: Array = []
	for x in w:
		var used := false
		for y in h:
			var c := img.get_pixel(x, y)
			if absf(c.r - key.r) + absf(c.g - key.g) + absf(c.b - key.b) < 0.15:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				used = true
		col_used.append(used)
	# Split the sheet into sprites wherever there is a gap of empty columns.
	var runs: Array = []
	var start := -1
	var gap := 0
	for x in w:
		if col_used[x]:
			if start < 0:
				start = x
			gap = 0
		elif start >= 0:
			gap += 1
			if gap >= 3:
				runs.append(Vector2i(start, x - gap + 1))
				start = -1
	if start >= 0:
		runs.append(Vector2i(start, w))
	_fossil_regions = []
	if runs.size() == 5:
		for run in runs:
			var top := h
			var bottom := 0
			for x in range(run.x, run.y):
				for y in h:
					if img.get_pixel(x, y).a > 0.0:
						top = mini(top, y)
						bottom = maxi(bottom, y + 1)
			_fossil_regions.append(Rect2(run.x, top, run.y - run.x, maxi(bottom - top, 1)))
	else:
		for i in 5:
			_fossil_regions.append(Rect2(i * w / 5.0, 0, w / 5.0, h))
	_fossil_tex = ImageTexture.create_from_image(img)


func _pts(r: Rect2, unit: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, unit.size(), 2):
		out.append(r.position + Vector2(float(unit[i]), float(unit[i + 1])) * r.size)
	return out


func _sub(r: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(r.position + Vector2(x, y) * r.size, Vector2(w, h) * r.size)
