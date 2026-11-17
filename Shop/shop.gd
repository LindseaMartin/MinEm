extends Control
## The trader's camp: sell finds, buy upgrades, browse the collection and
## rest until tomorrow (which seeds the mine with fresh dig sites).

signal closed
signal rest_requested

const IconScript := preload("res://UI/treasure_icon.gd")

var money_label: Label
var sell_list: VBoxContainer
var sell_all_button: Button
var upgrade_list: VBoxContainer
var collection_grid: GridContainer
var collection_label: Label
var news_label: Label
var result_label: Label
var contract_list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(30, 10)
	panel.size = Vector2(420, 250)
	add_child(panel)

	var root := VBoxContainer.new()
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var title := Label.new()
	title.text = "Trader's Camp"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	header.add_child(title)
	money_label = Label.new()
	header.add_child(money_label)

	news_label = Label.new()
	news_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news_label.custom_minimum_size = Vector2(400, 0)
	news_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	root.add_child(news_label)

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
	con_help.custom_minimum_size = Vector2(400, 0)
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
	collection_grid.columns = 5
	collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_scroll.add_child(collection_grid)

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
	Sfx.play("coin", randf_range(0.95, 1.1))
	Game.sell(index)


func _sell_all() -> void:
	Sfx.play("coin")
	Game.sell_all()


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
	if Game.fulfil_contract(index):
		Sfx.play("fanfare")
	else:
		Sfx.play("deny")


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
		icon.custom_minimum_size = Vector2(18, 18)
		row.add_child(icon)
		var label := Label.new()
		label.text = Game.item_label(item)
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
		desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		text.add_child(desc)
		row.add_child(text)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(70, 0)
		if cost < 0:
			buy.text = "MAX"
			buy.disabled = true
		else:
			buy.text = "Buy $%d" % cost
			buy.disabled = Game.money < cost
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
		text.add_child(desc)
		row.add_child(text)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(70, 0)
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
	oil_text.add_child(oil_desc)
	oil_row.add_child(oil_text)
	var refill := Button.new()
	refill.custom_minimum_size = Vector2(70, 0)
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
		text.add_child(desc)
		row.add_child(text)
		var deliver := Button.new()
		deliver.custom_minimum_size = Vector2(70, 0)
		deliver.text = "Deliver"
		deliver.disabled = not Game.contract_ready(c)
		deliver.pressed.connect(_deliver.bind(i))
		row.add_child(deliver)
		contract_list.add_child(row)

	# Collection
	_clear(collection_grid)
	var found := 0
	for id in Game.TREASURES:
		var def: Dictionary = Game.TREASURES[id]
		var known: bool = Game.collection.has(id)
		if known:
			found += 1
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(74, 0)
		cell.add_theme_constant_override("separation", 0)
		var icon = IconScript.new()
		icon.treasure_id = id
		icon.known = known
		icon.custom_minimum_size = Vector2(74, 26)
		cell.add_child(icon)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if known:
			label.text = "%s x%d" % [def["name"], int(Game.collection[id])]
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
		found, Game.TREASURES.size(), Game.completed_sets() * 10, sets_text]
