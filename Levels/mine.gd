extends Node2D
## The explorable mine. Reads the hand-drawn TileMap to work out which wall
## tiles border reachable floor, hides dig sites in some of them, and opens
## the dig minigame / trader when the player interacts.

const DigScript := preload("res://Dig/dig.gd")
const ShopScript := preload("res://Shop/shop.gd")
const HudScript := preload("res://UI/hud.gd")
const DigSpotScript := preload("res://Levels/dig_spot.gd")
const TraderScript := preload("res://Levels/trader.gd")

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

@onready var player = $Player
@onready var tile_map = $TileMap
@onready var transitioner = $CanvasLayer/Transitioner

var ui_layer: CanvasLayer
var hud
var trader
var busy: bool = false
var spots: Array = []
var candidates: Array = []   # [{"wall": Vector2i, "stand": Vector2i, "dist": int}]
var max_dist: int = 1
var tile_px: float = 16.0
var _beep_timer: float = 0.0
var lantern: PointLight2D
var start_pos: Vector2
var _dark_timer: float = DARK_GRACE
var _low_oil_warned: bool = false
var _time: float = 0.0


func _ready() -> void:
	randomize()
	# Keep the screen wipe above everything and stop it eating mouse clicks.
	$CanvasLayer.layer = 10
	transitioner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioner.get_node("TextureRect").mouse_filter = Control.MOUSE_FILTER_IGNORE

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	hud = HudScript.new()
	ui_layer.add_child(hud)

	# The mine is dark: only the lantern and the campfire light it.
	var darkness := CanvasModulate.new()
	darkness.color = Color(0.07, 0.06, 0.09)
	add_child(darkness)
	lantern = PointLight2D.new()
	lantern.texture = Game.light_texture()
	lantern.color = Color(1.0, 0.86, 0.62)
	lantern.energy = 1.15
	player.add_child(lantern)
	start_pos = player.position

	_scan_map()
	_spawn_spots()
	Game.set_completed.connect(_on_set_completed)
	hud.toast("WASD to move, E to interact, M to mute, Esc for menu.")
	hud.toast("Your lantern burns oil away from the campfire - watch the gauge.")
	hud.toast("Follow your detector - it beeps faster near a dig site.")
	_announce_day()


func _cell_pos(cell: Vector2i) -> Vector2:
	return to_local(tile_map.to_global(tile_map.map_to_local(cell)))


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
	var reach: Dictionary = {start: 0}
	var queue: Array = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var n: Vector2i = cell + d
			if ground.has(n) and not reach.has(n):
				reach[n] = int(reach[cell]) + 1
				queue.append(n)

	candidates = []
	max_dist = 1
	for cell in solid:
		for d in dirs:
			var n: Vector2i = cell + d
			if reach.has(n):
				var dist: int = reach[n]
				if dist >= 5:
					candidates.append({"wall": cell, "stand": n, "dist": dist})
					max_dist = maxi(max_dist, dist)
				break

	# The trader camps a couple of steps from where the player starts.
	var camp: Vector2i = start
	for cell in queue:
		if int(reach[cell]) == 2:
			camp = cell
			break
	trader = TraderScript.new()
	trader.position = _cell_pos(camp)
	add_child(trader)


func _spawn_spots() -> void:
	for s in spots:
		s.queue_free()
	spots = []
	candidates.shuffle()
	var chosen: Array = []
	for c in candidates:
		if chosen.size() >= SPOT_COUNT + Game.extra_sites():
			break
		var ok := true
		for other in chosen:
			if Vector2(c["wall"] - other["wall"]).length() < SPOT_SPACING:
				ok = false
				break
		if ok:
			chosen.append(c)
	for c in chosen:
		# Deeper into the mine = richer walls, with a little luck mixed in.
		var tier := 1 + int(3.0 * float(c["dist"]) / float(max_dist + 1))
		if randf() < 0.15:
			tier += 1
		tier += Game.tier_bonus()
		var spot = DigSpotScript.new()
		spot.tier = clampi(tier, 1, 3)
		spot.stand_cell = c["stand"]
		spot.position = _cell_pos(c["wall"])
		spot.show_tier = Game.level("detector") >= 2
		add_child(spot)
		spots.append(spot)


func _unhandled_input(event: InputEvent) -> void:
	if not busy and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Game.save_game()
		get_tree().change_scene_to_file("res://menu.tscn")


func _process(delta: float) -> void:
	_time += delta
	_update_lantern()
	if busy:
		return
	var ppos: Vector2 = player.position
	_burn_oil(delta, ppos)
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
			Sfx.play("beep", 0.8 + 0.7 * strength, -18.0)
	else:
		_beep_timer = 0.0

	# What can we interact with?
	var target = null
	var prompt := ""
	if trader != null and ppos.distance_to(trader.position) < INTERACT_RANGE:
		target = trader
		prompt = "[E] Trade"
	elif nearest != null and (nearest_d < INTERACT_RANGE or ppos.distance_to(_cell_pos(nearest.stand_cell)) < 12.0):
		target = nearest
		nearest.reveal()
		prompt = "[E] Dig here"
	elif spots.is_empty():
		prompt = "No dig sites left today - rest at the trader's camp"
	hud.set_prompt(prompt)

	if target != null and Input.is_action_just_pressed("interact"):
		if target == trader:
			_open_shop()
		else:
			_open_dig(target)


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
			hud.toast("Your lantern is running low. Head back soon!", Color(1.0, 0.75, 0.4))
		if Game.oil <= 0.0:
			Sfx.play("hiss", 0.6, -12.0)
			hud.toast("Your lantern goes out! Get back to the campfire!", Color(1.0, 0.5, 0.4))
		return
	_dark_timer -= delta
	if _dark_timer <= 0.0:
		_faint()


## Out of oil for too long: wake up at camp the next morning, minus a find.
func _faint() -> void:
	_set_busy(true)
	Sfx.play("collapse", 0.7)
	await transitioner.cover(1.2)
	var lost := ""
	if not Game.bag.is_empty():
		var item: Dictionary = Game.bag.pop_at(randi() % Game.bag.size())
		lost = Game.item_label(item)
	player.position = start_pos
	Game.next_day()
	_spawn_spots()
	_reset_day_state()
	hud.toast("You stumbled in the dark and woke up back at camp.", Color(1.0, 0.6, 0.5))
	if lost != "":
		hud.toast("Somewhere in the dark you dropped your %s." % lost, Color(1.0, 0.6, 0.5))
	hud.toast("Day %d begins." % Game.day)
	_announce_day()
	await transitioner.uncover()
	_set_busy(false)


func _reset_day_state() -> void:
	_dark_timer = DARK_GRACE
	_low_oil_warned = false


func _set_busy(value: bool) -> void:
	busy = value
	player.can_move = not value
	if value:
		hud.set_prompt("")


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
	dig.setup(spot.tier)
	dig.finished.connect(_on_dig_finished.bind(dig, spot))
	ui_layer.add_child(dig)
	hud.visible = false
	await transitioner.uncover()


func _on_dig_finished(found: Array, dig, spot) -> void:
	var clear_bonus: int = dig.bonus_cash
	await transitioner.cover()
	dig.queue_free()
	hud.visible = true
	spots.erase(spot)
	spot.queue_free()
	if found.is_empty():
		hud.toast("You leave empty-handed.")
	for item in found:
		var bonus: int = Game.add_to_bag(item["id"], item["cond"])
		hud.toast("+ " + Game.item_label(item))
		if bonus > 0:
			hud.toast("New discovery! Bonus $%d" % bonus, Color(1.0, 0.9, 0.4))
	if clear_bonus > 0:
		Game.money += clear_bonus
		Game.changed.emit()
		hud.toast("Wall cleared! Bonus $%d" % clear_bonus, Color(1.0, 0.9, 0.4))
	Game.save_game()
	await transitioner.uncover()
	_set_busy(false)


func _on_set_completed(set_name: String) -> void:
	Sfx.play("fanfare")
	hud.toast("%s set complete! All sale prices +10%% for good." % set_name, Color(0.5, 1.0, 0.7))


func _announce_day() -> void:
	var event: Dictionary = Game.DAY_EVENTS[Game.day_event]
	if Game.day_event != "calm":
		hud.toast("%s: %s" % [event["name"], event["desc"]], Color(0.7, 0.9, 1.0))
	hud.toast("The trader pays double for %s today." % Game.TREASURES[Game.wanted]["name"], Color(1.0, 0.9, 0.4))


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
		await transitioner.cover()
		shop.queue_free()
		Game.next_day()
		_spawn_spots()
		_reset_day_state()
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
