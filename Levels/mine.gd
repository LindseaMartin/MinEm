extends Node2D
## The explorable mine. Depth 0 is the hand-drawn map in level_0.tscn with
## the trader's camp; the deeper levels are caves generated from the same
## tiles (the layout is fixed per save, the dig sites change every day).
## Handles dig sites, the trader, shafts between depths, supply caches,
## the lantern, journal pages and the finale.

const DigScript := preload("res://Dig/dig.gd")
const ShopScript := preload("res://Shop/shop.gd")
const HudScript := preload("res://UI/hud.gd")
const PopupScript := preload("res://UI/popup.gd")
const DigSpotScript := preload("res://Levels/dig_spot.gd")
const TraderScript := preload("res://Levels/trader.gd")
const ShaftScript := preload("res://Levels/shaft.gd")
const CacheScript := preload("res://Levels/cache.gd")
const DecoScript := preload("res://Levels/deco.gd")
const LiftScript := preload("res://Levels/lift.gd")
const ChoiceScript := preload("res://UI/choice_popup.gd")
const BatScript := preload("res://Levels/bat.gd")
const PauseScript := preload("res://UI/pause_menu.gd")
const MapScript := preload("res://UI/map_view.gd")
const BAT_OIL := 15.0
const MINE_SCENE := "res://Levels/level_0.tscn"

const SPOT_COUNT := 8
const SPOT_SPACING := 6.0      # minimum distance between dig sites, in tiles
const SIGHT_RANGE := 56.0      # px: glints become visible this close
const INTERACT_RANGE := 26.0   # px

# Lantern oil: burns while you are away from the campfire.
const OIL_PER_SEC := 1.0
const OIL_PER_DIG := 12.0
const CAMP_RADIUS := 48.0      # px: the campfire's safe glow
const DARK_GRACE := 10.0       # seconds you can stumble in the dark
const LIGHT_RADIUS := 110.0    # px with a full lantern
const LIGHT_RADIUS_MIN := 30.0

# Generated caves (depth 1+). Atlas coords are tiles in Art/cave.png.
const CAVE_W := 64
const CAVE_H := 44
const CAVE_MARGIN := 10
const FLOOR_TILES := [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(7, 3)]
const VOID_TILE := Vector2i(2, 1)      # solid dark rock
const CLIFF_TOP := Vector2i(2, 4)      # rock face, upper part
const CLIFF_BOTTOM := Vector2i(2, 5)   # rock face meeting the floor
const DARKNESS := [Color(0.07, 0.06, 0.09), Color(0.06, 0.05, 0.04), Color(0.03, 0.05, 0.1), Color(0.04, 0.02, 0.03)]
const GROUND_TINT := [Color(1, 1, 1), Color(0.9, 0.82, 0.72), Color(0.72, 0.82, 1.0), Color(0.85, 0.65, 0.65)]
const DECO_KIND := ["", "timber", "crystal", "magma"]
const DEPTH_FLAVOR := [
	"",
	"Rotten timbers creak overhead. Someone mined here long ago.",
	"Crystals glow in the dark here and ring faintly as you pass.",
	"The rock is warm. Somewhere below, something is beating.",
]

@onready var player = $Player
@onready var tile_map = $TileMap
@onready var transitioner = $CanvasLayer/Transitioner

var depth: int = 0
var ui_layer: CanvasLayer
var hud
var trader
var shaft          # way down (none at the deepest level)
var ladder         # way up (none in the old mine)
var lift           # the lift next to the camp (old mine only)
var caches: Array = []
var busy: bool = false
var spots: Array = []
var candidates: Array = []   # [{"wall": Vector2i, "stand": Vector2i, "dist": int}]
var max_dist: int = 1
var tile_px: float = 16.0
var lantern: PointLight2D
var start_pos: Vector2

var _reach: Dictionary = {}  # floor cell -> walking distance from the start
var _order: Array = []       # floor cells, nearest first
var _far_cell: Vector2i
var _rng := RandomNumberGenerator.new()
var _beep_timer: float = 0.0
var _dark_timer: float = DARK_GRACE
var _low_oil_warned: bool = false
var _time: float = 0.0
var _block_interact_frame: int = -1
var map_view = null
var _explore_timer: float = 0.0


func _ready() -> void:
	randomize()
	depth = clampi(Game.depth, 0, Game.MAX_DEPTH)
	# Keep the screen wipe above everything and stop it eating mouse clicks.
	$CanvasLayer.layer = 10
	transitioner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioner.get_node("TextureRect").mouse_filter = Control.MOUSE_FILTER_IGNORE

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	hud = HudScript.new()
	ui_layer.add_child(hud)

	# The mine is dark: only the lantern and a few other lights show the way.
	# The UI runs at 960x540; zoom the camera so the pixel-art world keeps
	# its chunky 4x look.
	$Camera2D.zoom = Vector2(2, 2)

	var darkness := CanvasModulate.new()
	darkness.color = DARKNESS[depth]
	add_child(darkness)
	lantern = PointLight2D.new()
	lantern.texture = Game.light_texture()
	lantern.color = Color(1.0, 0.86, 0.62)
	lantern.energy = 1.15
	player.add_child(lantern)

	if depth > 0:
		_generate_cave()
	start_pos = player.position
	_scan_map()
	_place_features()
	_spawn_spots()
	Game.set_completed.connect(_on_set_completed)
	Game.milestone_reached.connect(_on_milestone)
	Game.stat_max("depth", depth)
	Sfx.start_ambience(depth)
	_welcome()

	if Game.transition_in:
		Game.transition_in = false
		_set_busy(true)
		transitioner.animation_tex.visible = true
		transitioner.animation_tex.scale = Vector2(25, 25)
		await transitioner.uncover()
		_set_busy(false)


func _welcome() -> void:
	if depth == 0 and not Game.intro_shown:
		Game.intro_shown = true
		hud.toast("WASD to move, E to interact, Tab for the map, F oil flask, Esc to pause.")
		hud.toast("Your lantern burns oil away from the campfire - watch the gauge.")
		_announce_day()
	elif depth > 0:
		hud.toast(Game.depth_name(depth), Color(0.8, 0.85, 1.0))
		hud.toast(DEPTH_FLAVOR[depth], Color(0.75, 0.75, 0.8))
	for msg in Game.pending_messages:
		hud.toast(str(msg[0]), msg[1])
	Game.pending_messages = []


func _cell_pos(cell: Vector2i) -> Vector2:
	return to_local(tile_map.to_global(tile_map.map_to_local(cell)))


# ------------------------------------------------------------ cave builder

## Builds a cave for this depth with cellular automata. The seed comes from
## the save, so each depth keeps the same layout.
func _generate_cave() -> void:
	var region: Dictionary = {}
	for attempt in 6:
		_rng.seed = hash([Game.world_seed, depth, attempt])
		region = _carve_cave()
		if region.size() >= 500:
			break

	var wall_layer: int = 1 if tile_map.get_layers_count() > 1 else 0
	tile_map.clear()
	var start := Vector2i(CAVE_W, 0)
	for y in range(-CAVE_MARGIN, CAVE_H + CAVE_MARGIN):
		for x in range(-CAVE_MARGIN, CAVE_W + CAVE_MARGIN):
			var cell := Vector2i(x, y)
			if region.has(cell):
				tile_map.set_cell(0, cell, 0, FLOOR_TILES[_rng.randi() % FLOOR_TILES.size()])
				# Start on the left-most floor, as close to the middle row as possible.
				if x < start.x or (x == start.x and absi(y - CAVE_H / 2) < absi(start.y - CAVE_H / 2)):
					start = cell
			else:
				var tile := VOID_TILE
				if region.has(cell + Vector2i.DOWN):
					tile = CLIFF_BOTTOM
				elif region.has(cell + Vector2i(0, 2)):
					tile = CLIFF_TOP
				tile_map.set_cell(wall_layer, cell, 0, tile)
	tile_map.modulate = GROUND_TINT[depth]
	player.position = _cell_pos(start)


## Returns the cells of the largest open area of a fresh random cave.
func _carve_cave() -> Dictionary:
	var open: Array = []
	for y in CAVE_H:
		var row: Array = []
		for x in CAVE_W:
			var edge := x < 2 or y < 2 or x >= CAVE_W - 2 or y >= CAVE_H - 2
			row.append(not edge and _rng.randf() > 0.46)
		open.append(row)
	for step in 5:
		var next: Array = []
		for y in CAVE_H:
			var row: Array = []
			for x in CAVE_W:
				var walls := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx < 0 or ny < 0 or nx >= CAVE_W or ny >= CAVE_H or not open[ny][nx]:
							walls += 1
				if walls > 4:
					row.append(false)
				elif walls < 4:
					row.append(true)
				else:
					row.append(open[y][x])
			next.append(row)
		open = next

	# Keep only the biggest connected area so everything is reachable.
	var seen: Dictionary = {}
	var best: Dictionary = {}
	for y in CAVE_H:
		for x in CAVE_W:
			var c := Vector2i(x, y)
			if not open[y][x] or seen.has(c):
				continue
			var area: Dictionary = {c: true}
			seen[c] = true
			var stack: Array = [c]
			while not stack.is_empty():
				var cur: Vector2i = stack.pop_back()
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var n: Vector2i = cur + d
					if n.x >= 0 and n.y >= 0 and n.x < CAVE_W and n.y < CAVE_H and open[n.y][n.x] and not seen.has(n):
						seen[n] = true
						area[n] = true
						stack.append(n)
			if area.size() > best.size():
				best = area
	return best


# ------------------------------------------------------------- map scanning

## Finds every floor tile the player can walk to and every solid tile that
## touches one (those are the possible dig sites).
func _scan_map() -> void:
	if tile_map.tile_set != null:
		tile_px = float(tile_map.tile_set.tile_size.x)
	var solid: Dictionary = {}
	for layer in tile_map.get_layers_count():
		for cell in tile_map.get_used_cells(layer):
			var data = tile_map.get_cell_tile_data(layer, cell)
			if data != null and data.get_collision_polygons_count(0) > 0:
				solid[cell] = true
	var ground: Dictionary = {}
	for cell in tile_map.get_used_cells(0):
		if not solid.has(cell):
			ground[cell] = true
	if ground.is_empty():
		return

	var start: Vector2i = tile_map.local_to_map(tile_map.to_local(player.global_position))
	if not ground.has(start):
		var best := INF
		for cell in ground:
			var d: float = Vector2(cell - start).length_squared()
			if d < best:
				best = d
				start = cell

	# Flood fill outward from the player to get walking distances.
	var dirs := [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
	_reach = {start: 0}
	_order = [start]
	var head := 0
	while head < _order.size():
		var cell: Vector2i = _order[head]
		head += 1
		for d in dirs:
			var n: Vector2i = cell + d
			if ground.has(n) and not _reach.has(n):
				_reach[n] = int(_reach[cell]) + 1
				_order.append(n)

	candidates = []
	max_dist = 1
	for cell in solid:
		for d in dirs:
			var n: Vector2i = cell + d
			if _reach.has(n):
				var dist: int = _reach[n]
				if dist >= 5:
					candidates.append({"wall": cell, "stand": n, "dist": dist})
					max_dist = maxi(max_dist, dist)
				break

	if depth == 0:
		# The trader camps a couple of steps from where the player starts.
		var camp: Vector2i = start
		for cell in _order:
			if int(_reach[cell]) == 2:
				camp = cell
				break
		trader = TraderScript.new()
		trader.position = _cell_pos(camp)
		add_child(trader)


## The floor cell `steps` away from the start that is closest to `target`.
func _cell_near(target: Vector2i, steps: int) -> Vector2i:
	var best := target
	var best_d := INF
	for cell in _order:
		if int(_reach[cell]) == steps:
			var d := Vector2(cell - target).length_squared()
			if d < best_d:
				best_d = d
				best = cell
	return best


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Shafts, ladders, supply caches and decorations.
func _place_features() -> void:
	if _order.is_empty():
		return
	_far_cell = _order[_order.size() - 1]
	var far_steps: int = _reach[_far_cell]

	if depth < Game.MAX_DEPTH:
		shaft = ShaftScript.new()
		shaft.position = _cell_pos(_far_cell)
		add_child(shaft)
	if depth > 0:
		ladder = ShaftScript.new()
		ladder.up = true
		ladder.lift = Game.lift_depth() >= depth
		ladder.position = _cell_pos(_order[0])
		add_child(ladder)
		player.position = _cell_pos(_cell_near(_order[0], 2))
	if depth == 0 and trader != null:
		# The old lift stands a few steps from the camp.
		var camp_cell: Vector2i = tile_map.local_to_map(tile_map.to_local(trader.global_position))
		for cell in _order:
			if int(_reach[cell]) >= 4 and Vector2(cell - camp_cell).length() >= 3.0:
				lift = LiftScript.new()
				lift.position = _cell_pos(cell)
				add_child(lift)
				break
	if Game.arrive_at_shaft and shaft != null:
		player.position = _cell_pos(_cell_near(_far_cell, maxi(far_steps - 2, 0)))
	Game.arrive_at_shaft = false

	# Supply caches in dead ends. Same spots every day; restocked daily.
	_rng.seed = hash([Game.world_seed, depth, "caches"])
	var dead_ends: Array = []
	for cell in _order:
		if int(_reach[cell]) < 10 or cell == _far_cell:
			continue
		var exits := 0
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _reach.has(cell + d):
				exits += 1
		if exits == 1:
			dead_ends.append(cell)
	_shuffle(dead_ends)
	var cache_count := 1 if depth == 0 else 2
	for cell in dead_ends:
		if caches.size() >= cache_count:
			break
		var ok := true
		for other in caches:
			if other.position.distance_to(_cell_pos(cell)) < 8.0 * tile_px:
				ok = false
		if not ok:
			continue
		var cache = CacheScript.new()
		cache.key = "cache:%d:%d:%d" % [depth, cell.x, cell.y]
		cache.opened = Game.dug_sites.has(cache.key)
		cache.position = _cell_pos(cell)
		add_child(cache)
		caches.append(cache)

	# Bats roost in the deep levels.
	if depth > 0:
		var roosts: Array = []
		for cell in _order:
			if int(_reach[cell]) >= 12:
				roosts.append(cell)
		_shuffle(roosts)
		for i in mini(2 + depth * 2, roosts.size()):
			var bat = BatScript.new()
			bat.mine = self
			bat.home = _cell_pos(roosts[i])
			add_child(bat)

	# Decorations along the cave walls.
	if depth > 0:
		var wall_side: Array = []
		for c in candidates:
			wall_side.append(c["stand"])
		_shuffle(wall_side)
		var placed: Array = []
		for cell in wall_side:
			if placed.size() >= 16:
				break
			var pos := _cell_pos(cell)
			var ok := true
			for p in placed:
				if p.distance_to(pos) < 5.0 * tile_px:
					ok = false
			if not ok:
				continue
			placed.append(pos)
			var deco = DecoScript.new()
			deco.kind = DECO_KIND[depth]
			deco.position = pos
			add_child(deco)


func _spawn_spots() -> void:
	for s in spots:
		s.queue_free()
	spots = []
	# Seeded by the day so leaving and coming back shows the same sites.
	_rng.seed = hash([Game.world_seed, Game.day, depth])
	var pool: Array = candidates.duplicate()
	_shuffle(pool)

	# At the very bottom, the Heart of the Mountain waits at the far end.
	var heart_site = null
	if depth == Game.MAX_DEPTH and not Game.heart_found and not pool.is_empty():
		var best_d := INF
		for c in pool:
			var d := Vector2(c["stand"] - _far_cell).length_squared()
			if d < best_d:
				best_d = d
				heart_site = c
		pool.erase(heart_site)

	var chosen: Array = []
	for c in pool:
		if chosen.size() >= SPOT_COUNT + Game.extra_sites():
			break
		var ok := true
		for other in chosen:
			if Vector2(c["wall"] - other["wall"]).length() < SPOT_SPACING:
				ok = false
				break
		if heart_site != null and Vector2(c["wall"] - heart_site["wall"]).length() < SPOT_SPACING:
			ok = false
		if ok:
			chosen.append(c)
	for c in chosen:
		# Further from the entrance and deeper down = richer walls.
		var tier := 1 + int(3.0 * float(c["dist"]) / float(max_dist + 1)) + depth
		if _rng.randf() < 0.15:
			tier += 1
		tier += Game.tier_bonus()
		# Some sites have a trait that changes how the wall plays.
		var site_trait := ""
		if _rng.randf() < 0.4:
			var keys: Array = Game.TRAITS.keys()
			site_trait = str(keys[_rng.randi() % keys.size()])
		_add_spot(c, clampi(tier, 1, 3), "", site_trait)
	if heart_site != null:
		_add_spot(heart_site, 3, "heart")


func _add_spot(c: Dictionary, tier: int, special: String, site_trait: String = "") -> void:
	var key := "%d:%d:%d" % [depth, c["wall"].x, c["wall"].y]
	if Game.dug_sites.has(key):
		return
	var spot = DigSpotScript.new()
	spot.tier = tier
	spot.special = special
	spot.site_trait = site_trait
	spot.key = key
	spot.stand_cell = c["stand"]
	spot.position = _cell_pos(c["wall"])
	spot.show_tier = Game.level("detector") >= 2
	add_child(spot)
	spots.append(spot)


# -------------------------------------------------------------- per frame

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if map_view != null:
			_close_map()
		else:
			_open_pause()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		if map_view != null:
			_close_map()
		else:
			_open_map()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		_use_flask()


func _process(delta: float) -> void:
	_time += delta
	_update_lantern()
	if busy:
		return
	var ppos: Vector2 = player.position
	_burn_oil(delta, ppos)
	_explore_timer -= delta
	if _explore_timer <= 0.0:
		_explore_timer = 0.2
		_mark_explored()
	if busy:
		return  # fainted this frame

	# Detector: signal strength towards the nearest hidden site.
	var nearest = null
	var nearest_d := INF
	for s in spots:
		var d: float = ppos.distance_to(s.position)
		if d < SIGHT_RANGE:
			s.reveal()
		if d < nearest_d:
			nearest_d = d
			nearest = s
	var strength := 0.0
	var dir := Vector2.ZERO
	if nearest != null:
		var range_px := Game.detector_range_cells() * tile_px
		strength = clampf(1.0 - nearest_d / range_px, 0.0, 1.0)
		if Game.level("detector") >= 3 and nearest_d > 8.0:
			dir = nearest.position - ppos
	hud.set_detector(strength, dir)
	# Hot/cold beeps: the closer the site, the faster and higher they get.
	if strength > 0.0:
		_beep_timer -= delta
		if _beep_timer <= 0.0:
			_beep_timer = lerpf(1.4, 0.14, strength)
			if Settings.beep_volume > 0.0:
				Sfx.play("beep", 0.8 + 0.7 * strength, -18.0 + linear_to_db(Settings.beep_volume))
	else:
		_beep_timer = 0.0

	# What can we interact with?
	var action := ""
	var target = null
	var prompt := ""
	var near_cache = null
	for c in caches:
		if not c.opened and ppos.distance_to(c.position) < INTERACT_RANGE:
			near_cache = c
	if trader != null and ppos.distance_to(trader.position) < INTERACT_RANGE:
		action = "trade"
		prompt = "[E] Trade"
	elif lift != null and ppos.distance_to(lift.position) < INTERACT_RANGE:
		action = "lift"
		if Game.lift_depth() > 0:
			prompt = "[E] Take the lift down"
		else:
			prompt = "The old lift is broken. Maybe the trader can fix it."
	elif ladder != null and ppos.distance_to(ladder.position) < INTERACT_RANGE:
		action = "up"
		if Game.lift_depth() >= depth:
			prompt = "[E] Ride the lift up to camp"
		else:
			prompt = "[E] Climb up to %s" % Game.depth_name(depth - 1)
	elif shaft != null and ppos.distance_to(shaft.position) < INTERACT_RANGE:
		action = "down"
		if Game.max_depth() > depth:
			prompt = "[E] Climb down to %s" % Game.depth_name(depth + 1)
		else:
			prompt = "The shaft drops into darkness. You need a longer rope."
	elif near_cache != null:
		action = "cache"
		target = near_cache
		prompt = "[E] Search the old crate"
	elif nearest != null and (nearest_d < INTERACT_RANGE or ppos.distance_to(_cell_pos(nearest.stand_cell)) < 12.0):
		action = "dig"
		target = nearest
		nearest.reveal()
		prompt = "[E] Dig here" if nearest.special != "heart" else "[E] Dig... gently"
		if nearest.site_trait != "":
			prompt += "  (%s)" % Game.TRAITS[nearest.site_trait]["name"]
	elif spots.is_empty():
		prompt = "No dig sites left here today"
	hud.set_prompt(prompt)

	if action == "" or not Input.is_action_just_pressed("interact"):
		return
	if Engine.get_process_frames() <= _block_interact_frame:
		return  # this E press just closed a window
	match action:
		"trade":
			_open_shop()
		"lift":
			_use_lift()
		"up":
			if Game.lift_depth() >= depth:
				_change_depth(0, false)
			else:
				_change_depth(depth - 1, true)
		"down":
			if Game.max_depth() > depth:
				_change_depth(depth + 1, false)
			else:
				Sfx.play("deny")
				hud.toast("Buy a longer Climbing Rope from the trader to go deeper.", Color(1.0, 0.75, 0.4))
		"cache":
			_open_cache(target)
		"dig":
			_open_dig(target)


func _set_busy(value: bool) -> void:
	busy = value
	player.can_move = not value
	if value:
		_close_map()
		hud.set_prompt("")
	else:
		_block_interact_frame = Engine.get_process_frames()


# ---------------------------------------------------------------- lantern

func _update_lantern() -> void:
	var frac := Game.oil / Game.oil_max()
	# Full glow until the tank is under 60%, then it shrinks.
	var radius := lerpf(LIGHT_RADIUS_MIN, LIGHT_RADIUS * Game.light_radius_mult(), clampf(frac / 0.6, 0.0, 1.0))
	if Game.oil <= 0.0:
		radius = LIGHT_RADIUS_MIN * 0.6
	var flicker := 1.0 + 0.03 * sin(_time * 9.0) + 0.02 * sin(_time * 17.0)
	if frac < 0.15:
		flicker += 0.12 * sin(_time * 31.0) * randf()  # sputtering
	lantern.texture_scale = radius * flicker / 64.0
	hud.set_oil(frac)


func _burn_oil(delta: float, ppos: Vector2) -> void:
	var at_camp: bool = trader != null and ppos.distance_to(trader.position) < CAMP_RADIUS
	if at_camp:
		_dark_timer = DARK_GRACE
		return
	if Game.oil > 0.0:
		Game.oil = maxf(Game.oil - OIL_PER_SEC * delta, 0.0)
		if Game.oil / Game.oil_max() < 0.25 and not _low_oil_warned:
			_low_oil_warned = true
			if Game.supply_count("flask") > 0:
				hud.toast("Your lantern is running low. Press F to use an oil flask.", Color(1.0, 0.75, 0.4))
			else:
				hud.toast("Your lantern is running low. Head back soon!", Color(1.0, 0.75, 0.4))
		if Game.oil <= 0.0:
			Sfx.play("hiss", 0.6, -12.0)
			hud.toast("Your lantern goes out! Get back to the campfire!", Color(1.0, 0.5, 0.4))
		return
	_dark_timer -= delta
	if _dark_timer <= 0.0:
		_faint()


func _use_flask() -> void:
	if Game.supply_count("flask") <= 0:
		Sfx.play("deny")
		hud.toast("You have no oil flasks. The trader sells them.")
	elif Game.use_flask():
		Sfx.play("prop", 1.4)
		_dark_timer = DARK_GRACE
		if Game.oil / Game.oil_max() >= 0.25:
			_low_oil_warned = false
		hud.toast("You top up the lantern. (+%d oil)" % int(Game.FLASK_OIL), Color(1.0, 0.85, 0.5))
	else:
		hud.toast("Your lantern is already full.")


## Out of oil for too long: wake up at camp the next morning, minus a find.
func _faint() -> void:
	_set_busy(true)
	Sfx.play("collapse", 0.7)
	await transitioner.cover(1.2)
	var messages: Array = [["You stumbled in the dark and woke up back at camp.", Color(1.0, 0.6, 0.5)]]
	if not Game.bag.is_empty():
		var item: Dictionary = Game.bag.pop_at(randi() % Game.bag.size())
		messages.append(["Somewhere in the dark you dropped your %s." % Game.item_label(item), Color(1.0, 0.6, 0.5)])
	Game.next_day()
	messages.append(["Day %d begins." % Game.day, Color(1, 1, 1)])
	messages.append_array(_day_lines())
	if depth > 0:
		# Carried all the way back up to the camp.
		Game.depth = 0
		Game.transition_in = true
		Game.pending_messages = messages
		get_tree().change_scene_to_file(MINE_SCENE)
		return
	player.position = start_pos
	_new_day_objects()
	for msg in messages:
		hud.toast(msg[0], msg[1])
	await transitioner.uncover()
	_set_busy(false)


func _new_day_objects() -> void:
	_spawn_spots()
	for c in caches:
		c.opened = Game.dug_sites.has(c.key)
		c.queue_redraw()
	_dark_timer = DARK_GRACE
	_low_oil_warned = false


# ----------------------------------------------------------- moving around

func _change_depth(new_depth: int, arrive_at_shaft: bool) -> void:
	_set_busy(true)
	Sfx.play("prop", 0.8)
	await transitioner.cover()
	Game.depth = clampi(new_depth, 0, Game.MAX_DEPTH)
	Game.arrive_at_shaft = arrive_at_shaft
	Game.transition_in = true
	Game.save_game()
	get_tree().change_scene_to_file(MINE_SCENE)


func _open_cache(cache) -> void:
	var loot: String = cache.open()
	Game.bump("caches")
	Sfx.play("coin")
	hud.toast("You search the old crate and find %s." % loot, Color(1.0, 0.9, 0.6))
	Game.save_game()


# -------------------------------------------------------------------- dig

func _open_dig(spot) -> void:
	if Game.bag.size() >= Game.pack_capacity():
		hud.toast("Your pack is full! Sell your finds at the trader's camp.", Color(1, 0.6, 0.5))
		Sfx.play("deny")
		return
	_set_busy(true)
	Game.oil = maxf(Game.oil - OIL_PER_DIG, 0.0)  # time spent digging
	await transitioner.cover()
	var dig = DigScript.new()
	dig.setup(spot.tier, depth, spot.special, spot.site_trait)
	dig.finished.connect(_on_dig_finished.bind(dig, spot))
	ui_layer.add_child(dig)
	hud.visible = false
	await transitioner.uncover()


func _on_dig_finished(found: Array, dig, spot) -> void:
	var clear_bonus: int = dig.bonus_cash
	Game.note_dig(dig.was_cleared, dig.was_flawless)
	await transitioner.cover()
	dig.queue_free()
	hud.visible = true
	Game.dug_sites[spot.key] = true
	spots.erase(spot)
	spot.queue_free()
	var pages: Array = []
	var heart_reward := -1
	for item in found:
		if item["id"] == "page":
			pages.append(Game.add_page())
		elif item["id"] == "heart":
			heart_reward = Game.claim_heart(item["cond"])
		else:
			var bonus: int = Game.add_to_bag(item["id"], item["cond"], item.get("shine", false))
			Game.note_find(item)
			if bonus > 0:
				hud.toast("New discovery: %s! Bonus $%d" % [Game.TREASURES[item["id"]]["name"], bonus], Color(1.0, 0.9, 0.4))
	if clear_bonus > 0:
		Game.money += clear_bonus
		Game.changed.emit()
		hud.toast("Wall cleared! Bonus $%d" % clear_bonus, Color(1.0, 0.9, 0.4))
	Game.save_game()
	await transitioner.uncover()
	for page in pages:
		await _show_page(page)
	if heart_reward >= 0:
		await _show_ending(heart_reward)
	_set_busy(false)


func _show_page(index: int) -> void:
	Sfx.play("found", 0.8)
	var pop = PopupScript.new()
	pop.title_text = "Journal page %d of %d" % [index + 1, Game.JOURNAL.size()]
	pop.body_text = Game.JOURNAL[index]
	ui_layer.add_child(pop)
	await pop.closed


func _show_ending(reward: int) -> void:
	Sfx.play("fanfare")
	var known := 0
	var total := 0
	for id in Game.TREASURES:
		if Game.TREASURES[id].get("hidden", false):
			continue
		total += 1
		if Game.collection.has(id):
			known += 1
	var pop = PopupScript.new()
	pop.title_text = "The Heart of the Mountain"
	pop.accent = Color(1.0, 0.6, 0.45)
	pop.body_text = ("You freed the stone Edda Thorn sealed away - warm as a hearth and still beating.\n\n"
		+ "The miners' guild pays $%d for the find.\n\n" % reward
		+ "Days underground: %d\nTreasures catalogued: %d of %d\nJournal pages: %d of %d\n\n" % [Game.day, known, total, Game.journal, Game.JOURNAL.size()]
		+ "The mine is yours to keep exploring.")
	pop.button_text = "Keep digging"
	ui_layer.add_child(pop)
	await pop.closed


func _on_set_completed(set_name: String) -> void:
	Sfx.play("fanfare")
	hud.toast("%s set complete! All sale prices +10%% for good." % set_name, Color(0.5, 1.0, 0.7))


func _day_lines() -> Array:
	var lines: Array = []
	var event: Dictionary = Game.DAY_EVENTS[Game.day_event]
	if Game.day_event != "calm":
		lines.append(["%s: %s" % [event["name"], event["desc"]], Color(0.7, 0.9, 1.0)])
	lines.append(["The trader pays double for %s today." % Game.TREASURES[Game.wanted]["name"], Color(1.0, 0.9, 0.4)])
	return lines


func _announce_day() -> void:
	for line in _day_lines():
		hud.toast(line[0], line[1])


# ------------------------------------------------------------------- shop

func _open_shop() -> void:
	_set_busy(true)
	var shop = ShopScript.new()
	shop.closed.connect(_close_shop.bind(shop, false))
	shop.rest_requested.connect(_close_shop.bind(shop, true))
	ui_layer.add_child(shop)


func _close_shop(shop, rest: bool) -> void:
	if shop.is_queued_for_deletion() or shop.has_meta("closing"):
		return
	shop.set_meta("closing", true)
	if rest:
		shop.queue_free()
		await _show_day_summary()
		await transitioner.cover()
		Game.next_day()
		_new_day_objects()
		hud.toast("Day %d - fresh dig sites are waiting in the mine." % Game.day)
		_announce_day()
		await transitioner.uncover()
	else:
		shop.queue_free()
		if Game.oil / Game.oil_max() >= 0.25:
			_low_oil_warned = false  # refilled or upgraded at the shop
		# Detector upgrades change how glints are shown.
		for s in spots:
			s.show_tier = Game.level("detector") >= 2
			s.queue_redraw()
	_set_busy(false)


# ------------------------------------------------------- pause, map, misc

func _open_pause() -> void:
	_set_busy(true)
	var pause = PauseScript.new()
	pause.in_game = true
	pause.resumed.connect(func(): _set_busy(false))
	pause.quit_requested.connect(_quit_to_title)
	ui_layer.add_child(pause)


func _quit_to_title() -> void:
	Game.depth = 0
	Game.save_game()
	get_tree().change_scene_to_file("res://menu.tscn")


func _open_map() -> void:
	if map_view != null:
		return
	_mark_explored()
	map_view = MapScript.new()
	map_view.mine = self
	ui_layer.add_child(map_view)


func _close_map() -> void:
	if map_view != null:
		map_view.queue_free()
		map_view = null


## Remembers every cell the lantern currently lights, for the map.
func _mark_explored() -> void:
	var seen: Dictionary = Game.explored_cells(depth)
	var center: Vector2i = tile_map.local_to_map(tile_map.to_local(player.global_position))
	var radius := int(ceil(lantern.texture_scale * 64.0 * 0.6 / tile_px))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				seen[center + Vector2i(dx, dy)] = true


## A bat flew into the lantern.
func bat_hit() -> void:
	if Game.oil <= 0.0:
		return
	Game.oil = maxf(Game.oil - BAT_OIL, 0.0)
	Sfx.play("flap", 0.8, -6.0)
	hud.toast("A bat flaps into your lantern! (-%d oil)" % int(BAT_OIL), Color(1.0, 0.7, 0.5))


func _on_milestone(milestone_name: String, reward: int) -> void:
	Sfx.play("fanfare", 1.2)
	hud.toast("Milestone: %s! +$%d" % [milestone_name, reward], Color(0.6, 1.0, 0.75))


func _show_day_summary() -> void:
	var t: Dictionary = Game.today
	var start := int(t.get("start_money", Game.money))
	var diff := Game.money - start
	var lines := "Walls dug: %d   (cleared %d, flawless %d)\n" % [int(t.get("digs", 0)), int(t.get("cleared", 0)), int(t.get("flawless", 0))]
	lines += "Finds: %d\n" % int(t.get("finds", 0))
	if str(t.get("best", "")) != "":
		lines += "Best find: %s ($%d)\n" % [str(t["best"]), int(t.get("best_value", 0))]
	lines += "Money: $%d -> $%d  (%s$%d)\n\n" % [start, Game.money, "+" if diff >= 0 else "-", absi(diff)]
	lines += "Tomorrow: lantern refilled, new dig sites, new conditions."
	var pop = PopupScript.new()
	pop.title_text = "End of day %d" % Game.day
	pop.body_text = lines
	pop.button_text = "Sleep"
	ui_layer.add_child(pop)
	await pop.closed


func _use_lift() -> void:
	if Game.lift_depth() <= 0:
		Sfx.play("deny")
		hud.toast("The lift needs repairs. Mags sells a Mine Lift upgrade.", Color(1.0, 0.75, 0.4))
		return
	_set_busy(true)
	var choice = ChoiceScript.new()
	choice.title_text = "Take the lift down to..."
	choice.cancel_value = -1
	for d in range(1, Game.lift_depth() + 1):
		choice.options.append([Game.depth_name(d), d])
	ui_layer.add_child(choice)
	var picked = await choice.chosen
	if int(picked) <= 0:
		_set_busy(false)
		return
	_change_depth(int(picked), false)
