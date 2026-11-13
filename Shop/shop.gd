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
	sell_all_button = Button.new()
	sell_all_button.pressed.connect(Game.sell_all)
	sell_tab.add_child(sell_all_button)

	# --- Upgrades
	var up_scroll := ScrollContainer.new()
	up_scroll.name = "Upgrades"
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
	rest.text = "Rest until tomorrow (new dig sites)"
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
		closed.emit()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func refresh() -> void:
	money_label.text = "$%d" % Game.money

	# Sell list
	_clear(sell_list)
	if Game.bag.is_empty():
		var empty := Label.new()
		empty.text = "Your pack is empty. Go dig something up!"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		sell_list.add_child(empty)
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
		row.add_child(label)
		var price := Label.new()
		price.text = "$%d" % Game.item_value(item)
		row.add_child(price)
		var sell := Button.new()
		sell.text = "Sell"
		sell.pressed.connect(Game.sell.bind(i))
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
			buy.pressed.connect(Game.buy_upgrade.bind(id))
		row.add_child(buy)
		upgrade_list.add_child(row)

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
	collection_label.text = "Discovered %d of %d. First finds earn a bonus of half their value." % [found, Game.TREASURES.size()]
