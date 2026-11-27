extends Control
## The trader's camp: sell finds, buy upgrades, browse the collection and
## rest until tomorrow (which seeds the mine with fresh dig sites).

signal closed
signal rest_requested

const IconScript := preload("res://UI/treasure_icon.gd")
const FloatScript := preload("res://UI/float_text.gd")
const UiTheme := preload("res://UI/ui_theme.gd")
const WIDE := 820.0   # width for wrapped text inside the window
const TRADER := "Mags"
## Mags' tip of the day. Entries are [text, condition]; see _tip_allowed().
const TIPS := [
	["Scan before you swing. A canary's cheaper than a cave-in.", "no_canary"],
	["Gas likes to sit where the stone looks stained yellow. Chip around it.", ""],
	["Fault lines cost you dear. Those cracked cells? Leave 'em be if you can.", ""],
	["Bats go for the light. Keep walking and they lose interest.", "deep"],
	["The deeper seams pay better, but bring oil. Lots of oil.", ""],
	["Finish a collection set and every buyer in town pays you more. For good.", ""],
	["Old crates in the dead ends get restocked overnight. Don't ask me who does it.", ""],
	["Heard the Crystal Caverns hold sapphires as big as your fist.", ""],
	["Edda Thorn? Stubborn as rock. Sealed something at the bottom and never said what.", ""],
	["A flawless wall pays double the clear bonus. Patience is money.", ""],
	["Dynamite's quick, sure. Ask the last fella what it did to his fossils.", ""],
	["Hold on to anything I'm asking for. The wanted list changes every morning.", ""],
	["Lost in the dark? Tab shows a map of everywhere your lantern's been.", ""],
	["Geodes look dull, but I'll crack one for you. Sometimes there's a diamond inside.", ""],
	["Contracts pay well over market. Just don't let them run out on you.", ""],
	["Every wall wobbles. Wedge a timber prop in before it's too late, not after.", ""],
]

var money_label: Label
var sell_list: VBoxContainer
var sell_all_button: Button
var upgrade_list: VBoxContainer
var collection_grid: GridContainer
var collection_label: Label
var news_label: Label
var tip_label: Label
var result_label: Label
var contract_list: VBoxContainer
var journal_list: VBoxContainer
var records_list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 500)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Trader's Camp  -  " + TRADER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_font_size_override("font_size", Settings.title_size())
	header.add_child(title)
	money_label = Label.new()
	money_label.add_theme_color_override("font_color", UiTheme.GOLD)
	money_label.add_theme_font_size_override("font_size", Settings.title_size())
	header.add_child(money_label)

	news_label = Label.new()
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news_label.custom_minimum_size = Vector2(WIDE, 0)
	news_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	root.add_child(news_label)

	tip_label = Label.new()
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.custom_minimum_size = Vector2(WIDE, 0)
	tip_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.6))
	tip_label.text = "%s: \"%s\"" % [TRADER, _tip_of_the_day()]
	root.add_child(tip_label)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	# --- Sell
	var sell_tab := VBoxContainer.new()
	sell_tab.name = "Sell"
	tabs.add_child(sell_tab)
	var sell_scroll := ScrollContainer.new()
	sell_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_tab.add_child(sell_scroll)
	sell_list = VBoxContainer.new()
	sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_scroll.add_child(sell_list)
	result_label = Label.new()
	result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	sell_tab.add_child(result_label)
	sell_all_button = Button.new()
	sell_all_button.pressed.connect(_sell_all)
	sell_tab.add_child(sell_all_button)

	# --- Contracts
	var con_tab := VBoxContainer.new()
	con_tab.name = "Contracts"
	tabs.add_child(con_tab)
	var con_help := Label.new()
	con_help.text = "Requests from the trader's buyers. Deliver before they expire. Ruined items are refused."
	con_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	con_help.custom_minimum_size = Vector2(WIDE, 0)
	con_help.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	con_tab.add_child(con_help)
	var con_scroll := ScrollContainer.new()
	con_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	con_tab.add_child(con_scroll)
	contract_list = VBoxContainer.new()
	contract_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	con_scroll.add_child(contract_list)

	# --- Upgrades
	var up_scroll := ScrollContainer.new()
	up_scroll.name = "Gear"
	tabs.add_child(up_scroll)
	upgrade_list = VBoxContainer.new()
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_scroll.add_child(upgrade_list)

	# --- Collection
	var col_tab := VBoxContainer.new()
	col_tab.name = "Collection"
	tabs.add_child(col_tab)
	collection_label = Label.new()
	col_tab.add_child(collection_label)
	var col_scroll := ScrollContainer.new()
	col_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_tab.add_child(col_scroll)
	collection_grid = GridContainer.new()
	collection_grid.columns = 8
	collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_scroll.add_child(collection_grid)

	# --- Records
	var rec_scroll := ScrollContainer.new()
	rec_scroll.name = "Records"
	tabs.add_child(rec_scroll)
	records_list = VBoxContainer.new()
	records_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	records_list.add_theme_constant_override("separation", 0)
	rec_scroll.add_child(records_list)

	# --- Journal
	var jour_scroll := ScrollContainer.new()
	jour_scroll.name = "Journal"
	tabs.add_child(jour_scroll)
	journal_list = VBoxContainer.new()
	journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jour_scroll.add_child(journal_list)

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var rest := Button.new()
	rest.text = "Rest until tomorrow (refills oil, new dig sites)"
	rest.pressed.connect(func(): rest_requested.emit())
	footer.add_child(rest)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var back := Button.new()
	back.text = "Back to the mine"
	back.pressed.connect(func(): closed.emit())
	footer.add_child(back)

	Game.changed.connect(refresh)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # don't let the mine see it too
		closed.emit()


func _sell(index: int) -> void:
	if index < 0 or index >= Game.bag.size():
		return
	var price := Game.sell_price(Game.bag[index])
	Sfx.play("coin", randf_range(0.95, 1.1))
	Game.sell(index)
	_float_money("+$%d" % price)


func _sell_all() -> void:
	var total := Game.bag_value()
	Sfx.play("coin")
	Game.sell_all()
	_float_money("+$%d" % total)


func _buy_upgrade(id: String) -> void:
	Sfx.play("buy" if Game.buy_upgrade(id) else "deny")


func _buy_supply(id: String) -> void:
	Sfx.play("buy" if Game.buy_supply(id) else "deny")


func _refill_oil() -> void:
	Sfx.play("buy" if Game.refill_oil() else "deny")


func _crack(index: int) -> void:
	var gem := Game.crack_geode(index)
	if gem == "":
		Sfx.play("deny")
		result_label.text = "You need $%d to have a geode cracked." % Game.GEODE_CRACK_COST
		return
	Sfx.play("rock")
	Sfx.play("found")
	result_label.text = "Crack! The geode held a %s!" % Game.TREASURES[gem]["name"]


func _deliver(index: int) -> void:
	var reward := int(Game.contracts[index]["reward"]) if index < Game.contracts.size() else 0
	if Game.fulfil_contract(index):
		Sfx.play("fanfare")
		_float_money("+$%d" % reward)
		tip_label.text = "%s: \"Pleasure doing business. They'll be glad to have those.\"" % TRADER
	else:
		Sfx.play("deny")


func _float_money(text: String) -> void:
	var f = FloatScript.new()
	f.text = text
	f.color = Color(1.0, 0.9, 0.4)
	f.position = money_label.global_position + Vector2(money_label.size.x * 0.5, 30)
	add_child(f)


func _tip_allowed(condition: String) -> bool:
	match condition:
		"no_canary":
			return Game.level("canary") < 2
		"deep":
			return Game.max_depth() >= 1
	return true


func _tip_of_the_day() -> String:
	var pool: Array = []
	for tip in TIPS:
		if _tip_allowed(tip[1]):
			pool.append(tip[0])
	return pool[absi(hash([Game.world_seed, Game.day])) % pool.size()]


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func refresh() -> void:
	money_label.text = "$%d" % Game.money
	var event: Dictionary = Game.DAY_EVENTS[Game.day_event]
	news_label.text = "Day %d - %s: %s\nWanted today: %s (pays double)" % [
		Game.day, event["name"], event["desc"], Game.TREASURES[Game.wanted]["name"]]

	# Sell list
	_clear(sell_list)
	if Game.bag.is_empty():
		var empty := Label.new()
		empty.text = "Your pack is empty. Go dig something up!"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sell_list.add_child(empty)
	var contract_ids: Dictionary = {}
	for c in Game.contracts:
		for id in c["ids"]:
			contract_ids[id] = true
	for i in Game.bag.size():
		var item: Dictionary = Game.bag[i]
		var row := HBoxContainer.new()
		var icon = IconScript.new()
		icon.treasure_id = item["id"]
		icon.shine = item.get("shine", false)
		icon.custom_minimum_size = Vector2(30, 30)
		row.add_child(icon)
		var label := Label.new()
		label.text = Game.item_label(item)
		label.add_theme_color_override("font_color", Game.rarity_color(Game.rarity_of(item)))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item["id"] == Game.wanted:
			label.text += "  - WANTED"
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		elif contract_ids.has(item["id"]):
			label.text += "  - contract"
			label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		row.add_child(label)
		var price := Label.new()
		price.text = "$%d" % Game.sell_price(item)
		row.add_child(price)
		if item["id"] == "geode":
			var crack := Button.new()
			crack.text = "Crack $%d" % Game.GEODE_CRACK_COST
			crack.disabled = Game.money < Game.GEODE_CRACK_COST
			crack.pressed.connect(_crack.bind(i))
			row.add_child(crack)
		var sell := Button.new()
		sell.text = "Sell"
		sell.pressed.connect(_sell.bind(i))
		row.add_child(sell)
		sell_list.add_child(row)
	sell_all_button.text = "Sell everything ($%d)" % Game.bag_value()
	sell_all_button.disabled = Game.bag.is_empty()

	# Upgrades
	_clear(upgrade_list)
	for id in Game.UPGRADES:
		var def: Dictionary = Game.UPGRADES[id]
		var lvl: int = Game.level(id)
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = "%s  -  level %d/%d" % [def["name"], lvl, Game.max_level(id)]
		text.add_child(name_label)
		var desc := Label.new()
		var cost: int = Game.upgrade_cost(id)
		if cost < 0:
			desc.text = str(def["levels"][lvl - 1])
		else:
			desc.text = "Next: " + str(def["levels"][lvl])
			if Game.upgrade_locked(id):
				desc.text += " (needs a longer rope first)"
		desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		desc.add_theme_font_size_override("font_size", Settings.small_size())
		text.add_child(desc)
		row.add_child(text)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(130, 0)
		if cost < 0:
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "Buy $%d" % cost
			buy.disabled = Game.money < cost or Game.upgrade_locked(id)
			buy.pressed.connect(_buy_upgrade.bind(id))
		row.add_child(buy)
		upgrade_list.add_child(row)

	# Supplies (one-use items)
	var supplies_title := Label.new()
	supplies_title.text = "Supplies - used up inside a dig (carry up to %d of each)" % Game.SUPPLY_MAX
	supplies_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	upgrade_list.add_child(supplies_title)
	for id in Game.SUPPLIES:
		var def: Dictionary = Game.SUPPLIES[id]
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = "%s  -  carrying %d" % [def["name"], Game.supply_count(id)]
		text.add_child(name_label)
		var desc := Label.new()
		desc.text = str(def["desc"])
		desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		desc.add_theme_font_size_override("font_size", Settings.small_size())
		text.add_child(desc)
		row.add_child(text)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(130, 0)
		buy.text = "Buy $%d" % int(def["cost"])
		buy.disabled = Game.money < int(def["cost"]) or Game.supply_count(id) >= Game.SUPPLY_MAX
		buy.pressed.connect(_buy_supply.bind(id))
		row.add_child(buy)
		upgrade_list.add_child(row)

	# Lamp oil refill
	var oil_row := HBoxContainer.new()
	var oil_text := VBoxContainer.new()
	oil_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oil_text.add_theme_constant_override("separation", 0)
	var oil_name := Label.new()
	oil_name.text = "Lamp Oil  -  lantern at %d%%" % int(round(100.0 * Game.oil / Game.oil_max()))
	oil_text.add_child(oil_name)
	var oil_desc := Label.new()
	oil_desc.text = "Fill the lantern now instead of waiting for tomorrow."
	oil_desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	oil_desc.add_theme_font_size_override("font_size", Settings.small_size())
	oil_text.add_child(oil_desc)
	oil_row.add_child(oil_text)
	var refill := Button.new()
	refill.custom_minimum_size = Vector2(130, 0)
	refill.text = "Fill $%d" % Game.OIL_REFILL_COST
	refill.disabled = Game.money < Game.OIL_REFILL_COST or Game.oil >= Game.oil_max() - 0.5
	refill.pressed.connect(_refill_oil)
	oil_row.add_child(refill)
	upgrade_list.add_child(oil_row)

	# Contracts
	_clear(contract_list)
	if Game.contracts.is_empty():
		var none := Label.new()
		none.text = "No requests right now. New ones arrive each morning."
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		contract_list.add_child(none)
	for i in Game.contracts.size():
		var c: Dictionary = Game.contracts[i]
		var row := HBoxContainer.new()
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = "Bring %s  -  reward $%d" % [c["label"], int(c["reward"])]
		text.add_child(name_label)
		var desc := Label.new()
		var left: int = int(c["expires"]) - Game.day
		var have: int = Game.contract_items(c).size()
		desc.text = "You have %d/%d.  %s" % [have, int(c["need"]),
			"Last day to deliver!" if left <= 0 else "Due by the end of day %d." % int(c["expires"])]
		desc.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5) if left <= 0 else Color(0.7, 0.75, 0.8))
		desc.add_theme_font_size_override("font_size", Settings.small_size())
		text.add_child(desc)
		row.add_child(text)
		var deliver := Button.new()
		deliver.custom_minimum_size = Vector2(130, 0)
		deliver.text = "Deliver"
		deliver.disabled = not Game.contract_ready(c)
		deliver.pressed.connect(_deliver.bind(i))
		row.add_child(deliver)
		contract_list.add_child(row)

	# Collection
	_clear(collection_grid)
	var found := 0
	var listed := 0
	for id in Game.TREASURES:
		var def: Dictionary = Game.TREASURES[id]
		if def.get("hidden", false):
			continue
		listed += 1
		var known: bool = Game.collection.has(id)
		if known:
			found += 1
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(100, 0)
		cell.add_theme_constant_override("separation", 0)
		var icon = IconScript.new()
		icon.treasure_id = id
		icon.known = known
		icon.custom_minimum_size = Vector2(100, 46)
		cell.add_child(icon)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if known:
			label.text = "%s x%d" % [def["name"], int(Game.collection[id])]
			label.add_theme_color_override("font_color", Game.rarity_color(Game.rarity_of({"id": id, "cond": 0})))
		else:
			label.text = "???"
			label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		label.clip_text = true
		cell.add_child(label)
		collection_grid.add_child(cell)
	var sets_text := ""
	for s in Game.SETS:
		var have: int = Game.set_progress(s)
		var total: int = s["ids"].size()
		sets_text += "%s %d/%d%s   " % [s["name"], have, total, " (done)" if have >= total else ""]
	collection_label.text = "Discovered %d of %d. Each completed set adds +10%% to all sale prices (now +%d%%).\n%s" % [
		found, listed, Game.completed_sets() * 10, sets_text]

	# Records
	_clear(records_list)
	var done := 0
	for m in Game.MILESTONES:
		if Game.milestones_done.has(m["id"]):
			done += 1
	var rec_head := Label.new()
	rec_head.text = "Milestones %d/%d   -   Walls dug %d   Flawless %d   Earned $%d   Deepest: %s" % [
		done, Game.MILESTONES.size(), Game.stat("digs"), Game.stat("flawless"), Game.stat("earned"), Game.depth_name(Game.stat("depth"))]
	rec_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rec_head.custom_minimum_size = Vector2(WIDE, 0)
	rec_head.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	records_list.add_child(rec_head)
	for m in Game.MILESTONES:
		var got: bool = Game.milestones_done.has(m["id"])
		var row := Label.new()
		var progress := mini(Game.stat(m["stat"]), int(m["goal"]))
		row.text = "%s %s - %s  ($%d)%s" % ["[x]" if got else "[ ]", m["name"], m["desc"], int(m["reward"]),
			"" if got else "  %d/%d" % [progress, int(m["goal"])]]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(WIDE, 0)
		row.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75) if got else Color(0.75, 0.75, 0.8))
		records_list.add_child(row)

	# Journal
	_clear(journal_list)
	if Game.journal == 0:
		var none := Label.new()
		none.text = "No pages yet. Old journal pages are sometimes buried in the walls."
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		journal_list.add_child(none)
	for i in Game.journal:
		var head := Label.new()
		head.text = "Page %d" % (i + 1)
		head.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
		journal_list.add_child(head)
		var body := Label.new()
		body.text = Game.JOURNAL[i]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(WIDE, 0)
		journal_list.add_child(body)
	if Game.journal < Game.JOURNAL.size():
		var more := Label.new()
		more.text = "%d more page(s) lie somewhere deeper." % (Game.JOURNAL.size() - Game.journal)
		more.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		journal_list.add_child(more)
