extends TabContainer

const CYAN := Color("59f2ff")
const DIM := Color("73a4ad")
const AMBER := Color("ffbd4a")
var pages: Dictionary = {}
var snapshot: Dictionary = {}

func _ready() -> void:
	add_theme_font_size_override("font_size", 16)
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus"]:
		var tab_box := StyleBoxFlat.new()
		tab_box.bg_color = Color("12313c") if state != "tab_unselected" else Color("081820")
		tab_box.border_color = CYAN if state == "tab_selected" or state == "tab_focus" else Color("245360")
		tab_box.border_width_bottom = 2
		tab_box.content_margin_left = 16
		tab_box.content_margin_right = 16
		tab_box.content_margin_top = 12
		tab_box.content_margin_bottom = 12
		add_theme_stylebox_override(state, tab_box)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("061218")
	background.content_margin_top = 12
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_bottom = 12
	add_theme_stylebox_override("panel", background)
	for title in ["SHIP", "WEAPONS", "UPGRADES", "STATS"]:
		var scroll := ScrollContainer.new()
		scroll.name = title
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 12)
		scroll.add_child(content)
		pages[title] = content
	resized.connect(_refresh)

func update_snapshot(value: Dictionary) -> void:
	snapshot = value
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if snapshot.is_empty():
		return
	for page in pages.values():
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
	var overview: VBoxContainer = pages["SHIP"]
	var layout: BoxContainer = HBoxContainer.new() if size.x >= 760 else VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	overview.add_child(layout)
	var ship_column := VBoxContainer.new()
	ship_column.custom_minimum_size.x = 330
	layout.add_child(ship_column)
	var diagram := preload("res://src/ui/ship_diagram.gd").new()
	diagram.custom_minimum_size = Vector2(330, 195)
	diagram.set("chassis", snapshot.get("chassis", "COURIER"))
	diagram.set("upgrades", snapshot.get("mods", {}))
	diagram.set("show_upgrade_list", false)
	ship_column.add_child(diagram)
	_label(ship_column, "AUTOMATIC SYSTEMS KEEP FIRING", 14, CYAN)
	_label(ship_column, "Driver targets ahead. ARC chains nearby.\nPrecision, guard and boost are your decisions.", 14, DIM)
	var vitals := VBoxContainer.new()
	vitals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(vitals)
	_label(vitals, "SHIP CONDITION", 16, CYAN)
	for meter in snapshot.get("meters", []):
		_label(vitals, "%s   %s / %s" % [meter[0], meter[1], meter[2]], 14, DIM)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 12
		bar.max_value = maxf(1, float(meter[2]))
		bar.value = float(meter[1])
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(meter[3])
		bar.add_theme_stylebox_override("fill", fill)
		vitals.add_child(bar)
	_cards(overview, snapshot.get("summary", []), 3)
	_label(overview, "CONTROL DECK", 16, CYAN)
	_cards(overview, [
		["PRECISION", "Hold M1 / release", "Touch: hold + drag right pad.\n0.9s full charge; guard cancels."],
		["GUARD", "Hold M2 / Space", "Touch: hold GUARD.\n80% mitigation; slows movement."],
		["VENT + BOOST", "Press Shift", "Touch: tap BOOST.\nClears heat; dashes in move direction."]], 3)
	_label(pages["WEAPONS"], "AUTOMATIC + MANUAL // INDEPENDENT SYSTEMS", 16, CYAN)
	_cards(pages["WEAPONS"], snapshot.get("weapons", []), 2)
	_label(pages["WEAPONS"], "DAMAGE CONTRIBUTION // ACTUAL HEALTH REMOVED", 16, CYAN)
	_stats(pages["WEAPONS"], snapshot.get("sources", []))
	var upgrades: Array = snapshot.get("upgrade_cards", [])
	_label(pages["UPGRADES"], "%d INSTALLED MODULES // RANKS + EFFECTS" % upgrades.size(), 16, CYAN)
	if upgrades.is_empty():
		_label(pages["UPGRADES"], "BASELINE SHIP\nCollect experience and choose modules to modify your build.", 16, DIM)
	_cards(pages["UPGRADES"], upgrades, 2)
	for group in snapshot.get("stat_groups", []):
		_label(pages["STATS"], group[0], 16, CYAN)
		_stats(pages["STATS"], group[1])

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _cards(parent: Node, entries: Array, wide_columns: int) -> void:
	var grid := GridContainer.new()
	grid.columns = wide_columns if size.x >= 760 else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	for entry in entries:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := StyleBoxFlat.new()
		box.bg_color = Color("0b2029")
		box.border_color = Color("245360")
		box.set_border_width_all(1)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		panel.add_theme_stylebox_override("panel", box)
		grid.add_child(panel)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 6)
		panel.add_child(rows)
		_label(rows, str(entry[0]), 14, DIM)
		_label(rows, str(entry[1]), 20, AMBER)
		if entry.size() > 2:
			_label(rows, str(entry[2]), 14, CYAN)

func _stats(parent: Node, entries: Array) -> void:
	for entry in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		parent.add_child(row)
		_label(row, str(entry[0]), 15, DIM)
		var value := _label(row, str(entry[1]), 15, CYAN)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
