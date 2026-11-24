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
	"geode": {"name": "Geode", "w": 1, "h": 1, "value": 25, "tier": 1, "weight": 5, "kind": "geode", "color": "8d8478"},
	# Only found below the old mine ("depth" is the shallowest level they appear on).
	"trilobite": {"name": "Trilobite", "w": 2, "h": 2, "value": 160, "tier": 1, "weight": 4, "kind": "trilobite", "color": "a08868", "depth": 1},
	"idol": {"name": "Obsidian Idol", "w": 1, "h": 2, "value": 260, "tier": 1, "weight": 3, "kind": "idol", "color": "2a2433", "depth": 1},
	"cluster": {"name": "Glow Crystal", "w": 2, "h": 2, "value": 300, "tier": 2, "weight": 4, "kind": "cluster", "color": "6fd3ff", "depth": 2},
	"sapphire": {"name": "Sapphire", "w": 2, "h": 2, "value": 380, "tier": 2, "weight": 3, "kind": "gem", "color": "2f5bea", "depth": 2},
	"meteorite": {"name": "Star Iron", "w": 2, "h": 2, "value": 650, "tier": 3, "weight": 3, "kind": "meteorite", "color": "3b3a40", "depth": 3},
	# Story items: never rolled at random, never go in the pack.
	"heart": {"name": "Heart of the Mountain", "w": 3, "h": 3, "value": 3000, "tier": 3, "weight": 0, "kind": "heart", "color": "ff5a3c", "depth": 3},
	"page": {"name": "Journal Page", "w": 1, "h": 1, "value": 0, "tier": 1, "weight": 0, "kind": "page", "color": "e8dcc0", "hidden": true},
}

const MAX_DEPTH := 3
const DEPTH_NAMES := ["The Old Mine", "The Old Workings", "The Crystal Caverns", "The Deep Dark"]

## Pages of Edda Thorn's journal, found one at a time in mine walls.
## PAGE_DEPTH says how deep you must be for each page to turn up.
const PAGE_DEPTH := [0, 0, 0, 1, 1, 2, 2, 3]
const JOURNAL := [
	"Signed the claim today. The old-timers in town say this hill is hollow. Good - hollow hills keep their riches close to the surface.\n- E. Thorn",
	"Struck silver in the east tunnel and the crew celebrated all night. When it's quiet I hear a low hum through the rock. Marten says it's only the wind.",
	"Marten found steps cut into the rock behind the far pool. Too even to be natural. Someone dug here before us - long, long before.",
	"The lower workings are older than any map. Rotten timbers, tools of a make I don't recognise. The hum is louder down here. I bought more rope.",
	"Two of the crew quit today. They say the walls breathe. I told them it's only gas pockets. I didn't tell them the gas smells sweet.",
	"Crystals everywhere, glowing on their own - in places you hardly need a lantern. The hum makes them ring like bells. They are all growing toward something below.",
	"I've stopped sleeping in camp. Every crystal down here points the same way: down. Whatever the old diggers were after, it is at the very bottom.",
	"I found it. A stone the size of a barrel, warm as a hearth, beating like a heart. I can't free it alone and the walls won't hold. I'm sealing the shaft. Whoever reads this: dig gently.",
]

## What a geode can hold when the trader cracks it open: [treasure id, weight].
const GEODE_TABLE := [["quartz", 35], ["amethyst", 30], ["emerald", 18], ["ruby", 12], ["diamond", 5]]
const GEODE_CRACK_COST := 30

const OIL_REFILL_COST := 25
const CONTRACT_COUNT := 3

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
	"lantern": {"name": "Lantern", "costs": [90, 350], "levels": [
		"A small oil lamp. Holds 100 oil.",
		"Bigger tank: holds 160 oil.",
		"Brass lantern: 220 oil and a wider glow."]},
	"rope": {"name": "Climbing Rope", "costs": [200, 450, 900], "levels": [
		"Only long enough for the old mine.",
		"Reaches the Old Workings (depth 1).",
		"Reaches the Crystal Caverns (depth 2).",
		"Reaches the Deep Dark (depth 3)."]},
	"canary": {"name": "Canary", "costs": [120], "levels": [
		"No canary yet.",
		"A canary in a little cage. It panics when your tool hovers near hidden gas."]},
	"lift": {"name": "Mine Lift", "costs": [300, 600, 1000], "levels": [
		"The old lift by the camp is broken.",
		"Lift runs to the Old Workings and back.",
		"Lift runs to the Crystal Caverns and back.",
		"Lift runs all the way to the Deep Dark."]},
}

## Some dig sites have a trait that changes how the wall plays.
const TRAITS := {
	"gems": {"name": "Gem pocket", "desc": "Mostly gems and crystals."},
	"bones": {"name": "Bone bed", "desc": "Mostly fossils."},
	"unstable": {"name": "Unstable", "desc": "30% less stability, but two extra treasures."},
	"granite": {"name": "Hard granite", "desc": "Lots of hard rock, but double the clear bonus."},
	"brittle": {"name": "Brittle", "desc": "Strikes cost 30% less, but damage hurts twice as much."},
}
const TRAIT_KINDS := {"gems": ["gem", "cluster", "shard", "geode"], "bones": ["fossil", "trilobite"]}

## Rare shiny versions of treasures, worth three times as much.
const GLEAM_CHANCE := 0.04
const GLEAM_MULT := 3.0

## Collecting every treasure in a set permanently raises all sale prices.
const SETS := [
	{"name": "Relics", "ids": ["coin", "lantern"]},
	{"name": "Ores", "ids": ["copper", "silver", "gold"]},
	{"name": "Crystals", "ids": ["quartz", "amethyst", "emerald", "ruby", "diamond"]},
	{"name": "Fossils", "ids": ["ammonite", "raptor", "miner", "croc", "ptero"]},
	{"name": "Deep Finds", "ids": ["trilobite", "idol", "cluster", "sapphire", "meteorite"]},
]
const SET_BONUS := 0.1

## Each new day rolls one of these conditions for the mine.
const DAY_EVENTS := {
	"calm": {"name": "A quiet day", "desc": "Nothing unusual in the mine today."},
	"tremors": {"name": "Tremors", "desc": "Walls are 20% weaker, but each hides 2 extra treasures."},
	"rich": {"name": "Fresh cave-in", "desc": "New seams exposed: every dig site is one grade richer."},
	"damp": {"name": "Damp stone", "desc": "The rock is soft: strikes cost 25% less stability."},
	"collector": {"name": "Collector in camp", "desc": "Everything sells for 25% more today."},
	"dust": {"name": "Dusty air", "desc": "Detector range is halved, but there are 3 extra dig sites."},
}

## One-use items bought from the trader and used inside a dig.
const SUPPLIES := {
	"prop": {"name": "Timber Prop", "cost": 40, "desc": "Shores up a wall: +30 stability."},
	"dynamite": {"name": "Dynamite", "cost": 60, "desc": "Blasts a 3x3 hole clean through. Rough on treasure."},
	"flask": {"name": "Oil Flask", "cost": 30, "desc": "Press F in the mine to top up your lantern by 50 oil."},
}
const FLASK_OIL := 50.0
const SUPPLY_MAX := 5
const WANTED_MULT := 2.0

signal set_completed(set_name)
signal milestone_reached(milestone_name, reward)

## Lifetime goals. Each pays a one-off reward when its stat reaches the goal.
const MILESTONES := [
	{"id": "dig1", "name": "First Strike", "desc": "Dig your first wall.", "stat": "digs", "goal": 1, "reward": 20},
	{"id": "dig25", "name": "Seasoned Digger", "desc": "Dig 25 walls.", "stat": "digs", "goal": 25, "reward": 150},
	{"id": "dig100", "name": "Old Hand", "desc": "Dig 100 walls.", "stat": "digs", "goal": 100, "reward": 500},
	{"id": "clear1", "name": "Nothing Left Behind", "desc": "Uncover everything in a wall.", "stat": "cleared", "goal": 1, "reward": 30},
	{"id": "flaw1", "name": "Steady Hands", "desc": "Clear a wall without damaging anything.", "stat": "flawless", "goal": 1, "reward": 50},
	{"id": "flaw10", "name": "Surgeon's Touch", "desc": "Clear 10 walls flawlessly.", "stat": "flawless", "goal": 10, "reward": 300},
	{"id": "earn1k", "name": "Making a Living", "desc": "Earn $1,000 from sales and contracts.", "stat": "earned", "goal": 1000, "reward": 100},
	{"id": "earn10k", "name": "Mining Magnate", "desc": "Earn $10,000 from sales and contracts.", "stat": "earned", "goal": 10000, "reward": 600},
	{"id": "depth1", "name": "Going Down", "desc": "Reach the Old Workings.", "stat": "depth", "goal": 1, "reward": 75},
	{"id": "depth2", "name": "Crystal Light", "desc": "Reach the Crystal Caverns.", "stat": "depth", "goal": 2, "reward": 150},
	{"id": "depth3", "name": "Into the Dark", "desc": "Reach the Deep Dark.", "stat": "depth", "goal": 3, "reward": 300},
	{"id": "contract5", "name": "Reliable Supplier", "desc": "Complete 5 contracts.", "stat": "contracts", "goal": 5, "reward": 150},
	{"id": "geode5", "name": "Geode Gambler", "desc": "Have 5 geodes cracked.", "stat": "geodes", "goal": 5, "reward": 60},
	{"id": "gleam1", "name": "Something Shiny", "desc": "Find a gleaming treasure.", "stat": "gleams", "goal": 1, "reward": 100},
	{"id": "caches10", "name": "Scavenger", "desc": "Search 10 old crates.", "stat": "caches", "goal": 10, "reward": 80},
	{"id": "pages", "name": "The Whole Story", "desc": "Find every journal page.", "stat": "pages", "goal": 8, "reward": 200},
	{"id": "sets", "name": "Curator", "desc": "Complete every collection set.", "stat": "sets", "goal": 5, "reward": 1000},
]

var money: int = 0
var day: int = 1
var day_event: String = "calm"   # key into DAY_EVENTS
var wanted: String = "copper"    # treasure the trader pays double for today
var supplies: Dictionary = {}    # supply id -> count carried
var oil: float = 100.0           # lantern oil left today
## Trader requests: [{"label", "ids": Array, "need": int, "reward": int, "expires": int}]
var contracts: Array = []
var bag: Array = []            # [{"id": String, "cond": int}]
var upgrades: Dictionary = {}  # upgrade id -> level (1..3)
var collection: Dictionary = {}  # treasure id -> number found
var world_seed: int = 0          # fixes the layout of the deep caves
var dug_sites: Dictionary = {}   # "depth:x:y" -> true for sites/caches used up today
var journal: int = 0             # journal pages found so far
var heart_found: bool = false

# Not saved: where the player is during this session.
var depth: int = 0               # 0 = the old mine with the trader's camp
var arrive_at_shaft: bool = false  # came up from below, so start by the shaft
var transition_in: bool = false    # open the iris when the next level loads
var intro_shown: bool = false
var pending_messages: Array = []   # toasts to show after the next level loads

var stats: Dictionary = {}            # lifetime counters, see MILESTONES
var milestones_done: Dictionary = {}  # milestone id -> true
## This day's tally for the end-of-day summary.
var today: Dictionary = {}
## depth -> {Vector2i: true}: map cells the lantern has lit up.
var explored: Dictionary = {}

var _fossil_tex: Texture2D
var _fossil_regions: Array = []


func _ready() -> void:
	_setup_input()
	reset()
	load_game()


func reset() -> void:
	money = 0
	day = 1
	day_event = "calm"
	wanted = "copper"
	supplies = {}
	bag = []
	collection = {}
	upgrades = {}
	for id in UPGRADES:
		upgrades[id] = 1
	oil = oil_max()
	world_seed = randi()
	dug_sites = {}
	journal = 0
	heart_found = false
	depth = 0
	stats = {}
	milestones_done = {}
	explored = {}
	_reset_today()
	contracts = []
	_fill_contracts()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Wipes progress and starts over from day 1.
func new_game() -> void:
	reset()
	save_game()
	changed.emit()


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

## The lift can't go deeper than your rope has taken you.
func upgrade_locked(id: String) -> bool:
	return id == "lift" and level("lift") >= level("rope")

func lift_depth() -> int:
	return level("lift") - 1

func buy_upgrade(id: String) -> bool:
	var cost := upgrade_cost(id)
	if cost < 0 or money < cost or upgrade_locked(id):
		return false
	money -= cost
	upgrades[id] = level(id) + 1
	if id == "lantern":
		oil = oil_max()  # a new lantern comes with a full tank
	save_game()
	changed.emit()
	return true

func pick_cost() -> float:
	return float([2.0, 1.5, 1.0][level("pick") - 1]) * strike_cost_mult()

func hammer_cost() -> float:
	return float([6.0, 7.0, 5.0][level("hammer") - 1]) * strike_cost_mult()

func hammer_is_wide() -> bool:
	return level("hammer") >= 2

func detector_range_cells() -> int:
	var cells: int = [7, 11, 16][level("detector") - 1]
	if day_event == "dust":
		cells = cells / 2
	return cells

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
	if item.get("shine", false):
		base *= GLEAM_MULT
	return int(round(base * float(CONDITIONS[int(item["cond"])]["mult"])))

func item_label(item: Dictionary) -> String:
	var title: String = TREASURES[item["id"]]["name"]
	if item.get("shine", false):
		title = "Gleaming " + title
	return "%s (%s)" % [title, CONDITIONS[int(item["cond"])]["name"]]

## Puts a find in the backpack. Returns the first-discovery bonus (0 if this
## kind of treasure has been found before).
func add_to_bag(id: String, cond: int, shine: bool = false) -> int:
	bag.append({"id": id, "cond": cond, "shine": shine})
	if shine:
		bump("gleams")
	return _record_find(id)


## Logs a find in the collection; pays the first-find bonus and announces
## any set it completes. Returns the bonus.
func _record_find(id: String) -> int:
	var bonus := 0
	if not collection.has(id):
		bonus = int(TREASURES[id]["value"]) / 2
		money += bonus
	var done_before: Array = []
	for s in SETS:
		done_before.append(set_progress(s) >= s["ids"].size())
	collection[id] = int(collection.get(id, 0)) + 1
	for i in SETS.size():
		if not done_before[i] and set_progress(SETS[i]) >= SETS[i]["ids"].size():
			set_completed.emit(SETS[i]["name"])
	stat_max("sets", completed_sets())
	changed.emit()
	return bonus

func sell(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	var price := sell_price(bag[index])
	money += price
	bag.remove_at(index)
	bump("earned", price)
	save_game()
	changed.emit()

func sell_all() -> void:
	var total := 0
	for item in bag:
		total += sell_price(item)
	money += total
	bag = []
	bump("earned", total)
	save_game()
	changed.emit()

func bag_value() -> int:
	var total := 0
	for item in bag:
		total += sell_price(item)
	return total

# ------------------------------------------------- days, sets and supplies

## What the trader pays for an item right now (sets, wanted item, events).
func sell_price(item: Dictionary) -> int:
	var mult := 1.0 + SET_BONUS * completed_sets()
	if item["id"] == wanted:
		mult *= WANTED_MULT
	if day_event == "collector":
		mult *= 1.25
	return int(round(item_value(item) * mult))

func set_progress(s: Dictionary) -> int:
	var n := 0
	for id in s["ids"]:
		if collection.has(id):
			n += 1
	return n

func completed_sets() -> int:
	var n := 0
	for s in SETS:
		if set_progress(s) >= s["ids"].size():
			n += 1
	return n

func next_day() -> void:
	day += 1
	var ids: Array = DAY_EVENTS.keys()
	day_event = "calm" if randf() < 0.25 else str(ids[randi() % ids.size()])
	wanted = roll_treasure(1 + randi() % (2 if day < 4 else 3))
	oil = oil_max()
	dug_sites = {}
	_reset_today()
	contracts = contracts.filter(func(c): return int(c["expires"]) >= day)
	_fill_contracts()
	save_game()
	changed.emit()


# ------------------------------------------- stats, milestones, today

func stat(key: String) -> int:
	return int(stats.get(key, 0))

func bump(key: String, amount: int = 1) -> void:
	stats[key] = stat(key) + amount
	_check_milestones()

## Raises a stat to `value` if it is higher (for "deepest", "pages"...).
func stat_max(key: String, value: int) -> void:
	if value > stat(key):
		stats[key] = value
		_check_milestones()

func _check_milestones() -> void:
	for m in MILESTONES:
		if milestones_done.has(m["id"]) or stat(m["stat"]) < int(m["goal"]):
			continue
		milestones_done[m["id"]] = true
		money += int(m["reward"])
		milestone_reached.emit(m["name"], int(m["reward"]))
		changed.emit()

func _reset_today() -> void:
	today = {"start_money": money, "digs": 0, "cleared": 0, "flawless": 0,
		"finds": 0, "best": "", "best_value": 0}

## Records a dig for the day summary and lifetime stats.
func note_dig(was_cleared: bool, was_flawless: bool) -> void:
	today["digs"] = int(today.get("digs", 0)) + 1
	bump("digs")
	if was_cleared:
		today["cleared"] = int(today.get("cleared", 0)) + 1
		bump("cleared")
	if was_flawless:
		today["flawless"] = int(today.get("flawless", 0)) + 1
		bump("flawless")

func note_find(item: Dictionary) -> void:
	today["finds"] = int(today.get("finds", 0)) + 1
	var value := item_value(item)
	if value > int(today.get("best_value", 0)):
		today["best_value"] = value
		today["best"] = item_label(item)

func explored_cells(d: int) -> Dictionary:
	if not explored.has(d):
		explored[d] = {}
	return explored[d]

func _explored_for_save() -> Dictionary:
	var out: Dictionary = {}
	for d in explored:
		var flat: Array = []
		for cell in explored[d]:
			flat.append(cell.x)
			flat.append(cell.y)
		out[str(d)] = flat
	return out


# ------------------------------------------------- depths, journal, heart

func max_depth() -> int:
	return level("rope") - 1

func depth_name(d: int = -1) -> String:
	return DEPTH_NAMES[clampi(depth if d < 0 else d, 0, MAX_DEPTH)]

## Index of the journal page that can turn up at depth `d`, or -1.
func next_page_for(d: int) -> int:
	if journal < JOURNAL.size() and PAGE_DEPTH[journal] <= d:
		return journal
	return -1

func add_page() -> int:
	journal = mini(journal + 1, JOURNAL.size())
	stat_max("pages", journal)
	save_game()
	changed.emit()
	return journal - 1

## Pays out for the Heart of the Mountain. Returns the reward.
func claim_heart(cond: int) -> int:
	heart_found = true
	var reward := item_value({"id": "heart", "cond": cond})
	money += reward
	collection["heart"] = int(collection.get("heart", 0)) + 1
	save_game()
	changed.emit()
	return reward

func use_flask() -> bool:
	if oil >= oil_max() - 0.5 or not use_supply("flask"):
		return false
	oil = minf(oil + FLASK_OIL, oil_max())
	changed.emit()
	return true


# ------------------------------------------------------------ lantern oil

func oil_max() -> float:
	return [100.0, 160.0, 220.0][level("lantern") - 1]

func light_radius_mult() -> float:
	return [1.0, 1.1, 1.35][level("lantern") - 1]

func refill_oil() -> bool:
	if money < OIL_REFILL_COST or oil >= oil_max() - 0.5:
		return false
	money -= OIL_REFILL_COST
	oil = oil_max()
	save_game()
	changed.emit()
	return true


# ----------------------------------------------------------------- geodes

## Pays the trader to crack the geode at `index` in the pack. Returns the
## treasure id it held, or "" if it could not be cracked.
func crack_geode(index: int) -> String:
	if index < 0 or index >= bag.size() or bag[index]["id"] != "geode" or money < GEODE_CRACK_COST:
		return ""
	money -= GEODE_CRACK_COST
	var total := 0
	for entry in GEODE_TABLE:
		total += int(entry[1])
	var roll := randi() % total
	var gem: String = GEODE_TABLE[0][0]
	for entry in GEODE_TABLE:
		roll -= int(entry[1])
		if roll < 0:
			gem = entry[0]
			break
	bag[index] = {"id": gem, "cond": bag[index]["cond"]}
	_record_find(gem)
	bump("geodes")
	save_game()
	changed.emit()
	return gem


# -------------------------------------------------------------- contracts

func _fill_contracts() -> void:
	while contracts.size() < CONTRACT_COUNT:
		contracts.append(_make_contract())


func _make_contract() -> Dictionary:
	var max_tier := clampi(1 + (day - 1) / 3, 1, 3)
	var ids: Array = []
	var need := 1
	var label := ""
	var avg := 0.0
	var s: Dictionary = SETS[randi() % SETS.size()]
	var eligible: Array = []
	for id in s["ids"]:
		if int(TREASURES[id]["tier"]) <= max_tier and int(TREASURES[id].get("depth", 0)) <= max_depth():
			eligible.append(id)
			avg += float(TREASURES[id]["value"])
	if randf() < 0.5 and not eligible.is_empty():
		avg /= float(eligible.size())
		ids = s["ids"].duplicate()
		need = 2 + randi() % 2
		label = "%d x any %s" % [need, s["name"]]
	else:
		var id := roll_treasure(max_tier, max_depth())
		ids = [id]
		avg = float(TREASURES[id]["value"])
		need = 1 if avg >= 100.0 else 1 + randi() % 2
		label = "%d x %s" % [need, TREASURES[id]["name"]]
	return {
		"label": label, "ids": ids, "need": need,
		"reward": int(round(need * avg * 1.75 / 5.0)) * 5 + 20,
		"expires": day + 2 + randi() % 3,
	}


## Pack indices that would be handed over for a contract (cheapest first,
## never Ruined items).
func contract_items(c: Dictionary) -> Array:
	var matches: Array = []
	for i in bag.size():
		if bag[i]["id"] in c["ids"] and int(bag[i]["cond"]) < CONDITIONS.size() - 1:
			matches.append(i)
	matches.sort_custom(func(a, b): return sell_price(bag[a]) < sell_price(bag[b]))
	return matches.slice(0, int(c["need"]))


func contract_ready(c: Dictionary) -> bool:
	return contract_items(c).size() >= int(c["need"])


func fulfil_contract(index: int) -> bool:
	if index < 0 or index >= contracts.size():
		return false
	var c: Dictionary = contracts[index]
	if not contract_ready(c):
		return false
	var used := contract_items(c)
	used.sort()
	used.reverse()
	for i in used:
		bag.remove_at(i)
	money += int(c["reward"])
	contracts.remove_at(index)
	bump("contracts")
	bump("earned", int(c["reward"]))
	save_game()
	changed.emit()
	return true

func strike_cost_mult() -> float:
	return 0.75 if day_event == "damp" else 1.0

func wall_stability() -> float:
	return max_stability() * (0.8 if day_event == "tremors" else 1.0)

func extra_treasures() -> int:
	return 2 if day_event == "tremors" else 0

func tier_bonus() -> int:
	return 1 if day_event == "rich" else 0

func extra_sites() -> int:
	return 3 if day_event == "dust" else 0

func supply_count(id: String) -> int:
	return int(supplies.get(id, 0))

func buy_supply(id: String) -> bool:
	var cost := int(SUPPLIES[id]["cost"])
	if money < cost or supply_count(id) >= SUPPLY_MAX:
		return false
	money -= cost
	supplies[id] = supply_count(id) + 1
	save_game()
	changed.emit()
	return true

func use_supply(id: String) -> bool:
	if supply_count(id) <= 0:
		return false
	supplies[id] = supply_count(id) - 1
	changed.emit()
	return true


## Like roll_treasure, but prefers treasure of the given kinds (for site
## traits such as "Gem pocket").
func roll_treasure_of(kinds: Array, tier: int, at_depth: int = 0) -> String:
	var id := roll_treasure(tier, at_depth)
	for attempt in 15:
		if str(TREASURES[id]["kind"]) in kinds:
			return id
		id = roll_treasure(tier, at_depth)
	return id


## Random treasure id that can appear in a dig site of the given tier.
func roll_treasure(tier: int, at_depth: int = 0) -> String:
	var pool: Array = []
	var total := 0.0
	for id in TREASURES:
		var t: Dictionary = TREASURES[id]
		var t_depth := int(t.get("depth", 0))
		if int(t["tier"]) > tier or t_depth > at_depth or float(t["weight"]) <= 0.0:
			continue
		# Richer sites lean towards their own tier's treasure, and each depth
		# towards the treasure only found there.
		var w: float = float(t["weight"])
		if int(t["tier"]) == tier:
			w *= 2.0
		if t_depth > 0 and t_depth == at_depth:
			w *= 2.5
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
		"day_event": day_event, "wanted": wanted, "supplies": supplies,
		"oil": oil, "contracts": contracts,
		"world_seed": world_seed, "dug_sites": dug_sites,
		"journal": journal, "heart_found": heart_found,
		"stats": stats, "milestones_done": milestones_done, "today": today,
		"explored": _explored_for_save(),
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
	var saved_event = str(data.get("day_event", "calm"))
	if DAY_EVENTS.has(saved_event):
		day_event = saved_event
	var saved_wanted = str(data.get("wanted", "copper"))
	if TREASURES.has(saved_wanted):
		wanted = saved_wanted
	var saved_sup = data.get("supplies", {})
	if typeof(saved_sup) == TYPE_DICTIONARY:
		for id in SUPPLIES:
			supplies[id] = clampi(int(saved_sup.get(id, 0)), 0, SUPPLY_MAX)
	var saved_up = data.get("upgrades", {})
	if typeof(saved_up) == TYPE_DICTIONARY:
		for id in UPGRADES:
			upgrades[id] = clampi(int(saved_up.get(id, 1)), 1, max_level(id))
	var saved_bag = data.get("bag", [])
	if typeof(saved_bag) == TYPE_ARRAY:
		for item in saved_bag:
			if typeof(item) == TYPE_DICTIONARY and TREASURES.has(item.get("id", "")):
				bag.append({"id": str(item["id"]), "cond": clampi(int(item.get("cond", 0)), 0, CONDITIONS.size() - 1), "shine": bool(item.get("shine", false))})
	var saved_col = data.get("collection", {})
	if typeof(saved_col) == TYPE_DICTIONARY:
		for id in saved_col:
			if TREASURES.has(id):
				collection[id] = int(saved_col[id])
	oil = clampf(float(data.get("oil", oil_max())), 0.0, oil_max())
	var saved_con = data.get("contracts", null)
	if typeof(saved_con) == TYPE_ARRAY:
		contracts = []
		for c in saved_con:
			if typeof(c) != TYPE_DICTIONARY or typeof(c.get("ids", null)) != TYPE_ARRAY:
				continue
			var ids: Array = []
			for id in c["ids"]:
				if TREASURES.has(str(id)):
					ids.append(str(id))
			if ids.is_empty():
				continue
			contracts.append({
				"label": str(c.get("label", "")), "ids": ids,
				"need": maxi(int(c.get("need", 1)), 1),
				"reward": int(c.get("reward", 0)),
				"expires": int(c.get("expires", day)),
			})
		_fill_contracts()
	world_seed = int(data.get("world_seed", world_seed))
	var saved_dug = data.get("dug_sites", {})
	if typeof(saved_dug) == TYPE_DICTIONARY:
		dug_sites = {}
		for key in saved_dug:
			dug_sites[str(key)] = true
	journal = clampi(int(data.get("journal", 0)), 0, JOURNAL.size())
	heart_found = bool(data.get("heart_found", false))
	var saved_stats = data.get("stats", {})
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for key in saved_stats:
			stats[str(key)] = int(saved_stats[key])
	var saved_done = data.get("milestones_done", {})
	if typeof(saved_done) == TYPE_DICTIONARY:
		for key in saved_done:
			milestones_done[str(key)] = true
	var saved_today = data.get("today", {})
	if typeof(saved_today) == TYPE_DICTIONARY and saved_today.has("start_money"):
		for key in today:
			if saved_today.has(key):
				today[key] = str(saved_today[key]) if key == "best" else int(saved_today[key])
	else:
		today["start_money"] = money
	var saved_map = data.get("explored", {})
	if typeof(saved_map) == TYPE_DICTIONARY:
		for key in saved_map:
			var flat = saved_map[key]
			if typeof(flat) != TYPE_ARRAY:
				continue
			var cells: Dictionary = {}
			for i in range(0, flat.size() - 1, 2):
				cells[Vector2i(int(flat[i]), int(flat[i + 1]))] = true
			explored[int(key)] = cells
	changed.emit()


# ---------------------------------------------------------------- drawing
# Treasures are drawn with code so no extra art is needed. Fossils use the
# skeletons in Art/fossils3.PNG (its green background is removed at runtime).

## Sparkles drawn over a gleaming treasure.
func draw_gleam(ci: CanvasItem, rect: Rect2, alpha: float = 1.0) -> void:
	var s := minf(rect.size.x, rect.size.y)
	for p in [Vector2(0.2, 0.22), Vector2(0.8, 0.35), Vector2(0.55, 0.82)]:
		var c: Vector2 = rect.position + p * rect.size
		var r := s * 0.14
		var k := r * 0.25
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(k, -k), c + Vector2(r, 0), c + Vector2(k, k),
			c + Vector2(0, r), c + Vector2(-k, k), c + Vector2(-r, 0), c + Vector2(-k, -k)]), Color(1.0, 1.0, 0.85, alpha))


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
		"trilobite":
			ci.draw_colored_polygon(_pts(r, [0.5, 0.06, 0.78, 0.18, 0.88, 0.45, 0.8, 0.78, 0.5, 0.95, 0.2, 0.78, 0.12, 0.45, 0.22, 0.18]), col.darkened(0.25))
			ci.draw_colored_polygon(_pts(r, [0.5, 0.1, 0.62, 0.2, 0.62, 0.9, 0.5, 0.94, 0.38, 0.9, 0.38, 0.2]), col)
			for i in 6:
				var y := 0.3 + i * 0.1
				ci.draw_line(r.position + Vector2(0.18, y) * r.size, r.position + Vector2(0.82, y) * r.size, col.darkened(0.45), 1.0)
		"idol":
			ci.draw_circle(r.position + Vector2(0.5, 0.18) * r.size, r.size.x * 0.22, col)
			ci.draw_colored_polygon(_pts(r, [0.3, 0.3, 0.7, 0.3, 0.82, 0.62, 0.7, 0.95, 0.3, 0.95, 0.18, 0.62]), col)
			ci.draw_rect(_sub(r, 0.38, 0.15, 0.08, 0.04), Color(0.9, 0.3, 0.9, alpha))
			ci.draw_rect(_sub(r, 0.56, 0.15, 0.08, 0.04), Color(0.9, 0.3, 0.9, alpha))
			ci.draw_line(r.position + Vector2(0.4, 0.35) * r.size, r.position + Vector2(0.45, 0.85) * r.size, col.lightened(0.35), 1.0)
		"cluster":
			for shard in [[0.5, 0.05, 0.62, 0.95, 0.38, 0.95], [0.25, 0.25, 0.42, 0.95, 0.15, 0.95], [0.78, 0.2, 0.86, 0.95, 0.58, 0.95]]:
				ci.draw_colored_polygon(_pts(r, shard), col)
				ci.draw_colored_polygon(_pts(r, [shard[0], shard[1], shard[2], shard[3], (shard[0] + shard[2]) * 0.5, shard[3]]), col.lightened(0.45))
		"meteorite":
			_draw_nugget(ci, r, col)
			for p in [Vector2(0.35, 0.4), Vector2(0.6, 0.3), Vector2(0.55, 0.65), Vector2(0.3, 0.68), Vector2(0.75, 0.52)]:
				ci.draw_circle(r.position + p * r.size, minf(r.size.x, r.size.y) * 0.04, Color(0.85, 0.9, 1.0, alpha))
		"heart":
			ci.draw_colored_polygon(_pts(r, [0.5, 0.04, 0.8, 0.16, 0.96, 0.45, 0.86, 0.8, 0.5, 0.97, 0.14, 0.8, 0.04, 0.45, 0.2, 0.16]), col.darkened(0.45))
			ci.draw_colored_polygon(_pts(r, [0.5, 0.14, 0.74, 0.25, 0.86, 0.47, 0.77, 0.74, 0.5, 0.88, 0.23, 0.74, 0.14, 0.47, 0.26, 0.25]), col)
			ci.draw_colored_polygon(_pts(r, [0.5, 0.28, 0.64, 0.4, 0.6, 0.62, 0.5, 0.72, 0.4, 0.62, 0.36, 0.4]), Color(1.0, 0.85, 0.5, alpha))
			ci.draw_circle(r.position + Vector2(0.42, 0.36) * r.size, r.size.x * 0.04, Color(1, 1, 0.9, alpha))
		"page":
			ci.draw_colored_polygon(_pts(r, [0.18, 0.1, 0.78, 0.06, 0.86, 0.88, 0.24, 0.94]), col)
			for i in 4:
				var y := 0.28 + i * 0.15
				ci.draw_line(r.position + Vector2(0.3, y) * r.size, r.position + Vector2(0.72, y - 0.02) * r.size, Color(0.35, 0.28, 0.2, alpha), 1.0)
		"geode":
			ci.draw_colored_polygon(_pts(r, [0.2, 0.25, 0.5, 0.1, 0.8, 0.22, 0.92, 0.55, 0.75, 0.88, 0.35, 0.92, 0.1, 0.6]), col)
			ci.draw_colored_polygon(_pts(r, [0.3, 0.3, 0.5, 0.2, 0.72, 0.32, 0.78, 0.6, 0.62, 0.78, 0.38, 0.8, 0.24, 0.58]), col.darkened(0.15))
			ci.draw_polyline(_pts(r, [0.45, 0.15, 0.52, 0.42, 0.42, 0.6, 0.5, 0.9]), Color(0.12, 0.1, 0.1, alpha), 1.0)
			ci.draw_colored_polygon(_pts(r, [0.52, 0.4, 0.6, 0.5, 0.52, 0.6, 0.44, 0.5]), Color(0.75, 0.5, 1.0, alpha))
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


var _light_tex: Texture2D

## Soft round texture shared by every lantern / campfire light.
func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_light_tex = t
	return _light_tex
