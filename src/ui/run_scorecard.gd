class_name RunScorecard
extends Control

## One-sheet run debrief. Compact viewports use four fixed pages, never scroll.
## All graphs use the frozen run snapshot; there are no invented scores/grades.
const PAPER := Color("e2efef")
const MUTED := Color("8ba5ad")
const CYAN := Color("62e5dc")
const AMBER := Color("ffc36b")
const RED := Color("ff657b")
const BLUE := Color("94afff")
const GREEN := Color("8bdfa4")
const EDGE := Color("29424e")
const PANEL := Color("101e28")
const TRACK := Color("1e333e")
const SOURCE_ORDER := ["MASS_DRIVER", "ARC_EXE", "MASS_DRIVER_RETURN", "MASS_DRIVER_FORK", "VENT"]
const SOURCE_COLORS := [CYAN, BLUE, AMBER, GREEN, RED]

var page: int = 0
var report: Dictionary = {}
var data: Dictionary = {}
var victory: bool = false
var _font: Font
var _sections: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	resized.connect(queue_redraw)


func set_report(won: bool, snapshot: Dictionary) -> void:
	victory = won
	report = snapshot.duplicate(true)
	data = report.get("scorecard", {})
	_sections.clear()
	for section: Dictionary in report.get("sections", []):
		_sections[String(section.get("title", ""))] = section.get("rows", {})
	page = 0
	queue_redraw()


func is_compact() -> bool:
	return size.x < 940.0 or size.y < 530.0


func _draw() -> void:
	if _font == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var compact := is_compact()
	var portrait := size.x < size.y
	var canvas := Vector2(1200, 584)
	if not data.get("combo", {}).is_empty():
		canvas.y = 642
	if compact:
		canvas = Vector2(360, 500) if portrait else Vector2(680, 250)
	var zoom := minf(size.x / canvas.x, size.y / canvas.y)
	var origin := (size - canvas * zoom) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
	_header(canvas.x, compact)
	if not compact:
		_metrics(Rect2(0, 82, 1200, 79), 5)
		_arsenal(Rect2(0, 175, 598, 251))
		_ship(Rect2(610, 175, 286, 251))
		_reactor(Rect2(908, 175, 292, 251))
		var bottom := 440.0
		if not data.get("combo", {}).is_empty():
			_combo_details(Rect2(0, 440, 1200, 44), true)
			bottom = 498
		_recovery(Rect2(0, bottom, 330, 144))
		_build(Rect2(342, bottom, 858, 144), 4)
	else:
		var body := Rect2(0, 56, canvas.x, canvas.y - 56)
		match page:
			0:
				var metric_height := 180.0 if portrait else 88.0
				_metrics(Rect2(0, 56, canvas.x, metric_height), 2 if portrait else 3, true)
				_recovery(Rect2(0, 66 + metric_height, canvas.x, canvas.y - metric_height - 66))
			1:
				_arsenal(body, portrait)
			2:
				if portrait:
					_ship(Rect2(0, 56, 360, 216))
					_reactor(Rect2(0, 282, 360, 218))
				else:
					_ship(Rect2(0, 56, 334, 194))
					_reactor(Rect2(346, 56, 334, 194))
			3:
				_build(body, 2 if portrait else 4)
			4:
				_combo_details(body)
	draw_set_transform(Vector2.ZERO)


func _header(w: float, compact: bool) -> void:
	var accent := GREEN if victory else RED
	draw_line(Vector2.ZERO, Vector2(w, 0), accent, 3.0)
	if compact:
		_text("RUN COMPLETE" if victory else "PROCESS TERMINATED", Vector2(0, 24), 21, PAPER, w * 0.74)
		_text("VOID//DAEMON", Vector2(w * 0.76, 23), 11, accent, w * 0.24, HORIZONTAL_ALIGNMENT_RIGHT)
		_text("SEED " + str(data.get("seed", "--")), Vector2(0, 44), 10, MUTED, w * 0.66)
		_text(str(data.get("mode", "STANDARD")), Vector2(w * 0.67, 44), 10, AMBER, w * 0.33, HORIZONTAL_ALIGNMENT_RIGHT)
		return
	_text("VOID//DAEMON     /     FLIGHT RECORDER", Vector2(0, 22), 12, MUTED, 800)
	_text("TRANSMISSION COMPLETE" if victory else "PROCESS TERMINATED", Vector2(0, 54), 29, PAPER, 800)
	_text("SEED " + str(data.get("seed", "--")) + "   /   " + str(data.get("sector", "STATIC_PROOF")), Vector2(0, 73), 11, MUTED, 800)
	_text(str(data.get("chassis", "COURIER / 01")), Vector2(w - 280, 23), 12, CYAN, 190, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("BOSS: " + str(data.get("boss", "NOT REACHED")), Vector2(w - 340, 47), 11, accent, 250, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(str(data.get("mode", "STANDARD")), Vector2(w - 340, 68), 11, MUTED, 250, HORIZONTAL_ALIGNMENT_RIGHT)
	var c := Vector2(w - 37, 43)
	draw_arc(c, 29, 0, TAU, 32, EDGE, 1, true)
	draw_line(c + Vector2(-37, 0), c + Vector2(37, 0), EDGE)
	draw_line(c + Vector2(0, -34), c + Vector2(0, 34), EDGE)
	var outline := PackedVector2Array([c + Vector2(0, -23), c + Vector2(18, 19), c + Vector2(0, 10), c + Vector2(-18, 19), c + Vector2(0, -23)])
	draw_polyline(outline, CYAN, 1.8, true)
	draw_circle(c, 3, accent)


func _metrics(r: Rect2, columns: int, include_dps: bool = false) -> void:
	var values := [
		["SURVIVAL TIME", _time(float(data.get("time", 0))), "RECORDED DURATION", PAPER],
		["ENEMIES PURGED", _number(data.get("kills", 0)), "%.1f / MIN" % float(data.get("kills_per_minute", 0)), CYAN],
		["DAMAGE DEALT", _number(data.get("damage", 0), true), "ACTUAL HEALTH REMOVED", AMBER],
		["AVERAGE DPS", "%.1f" % float(data.get("dps", 0)), "ACROSS THE WHOLE RUN", BLUE],
		["COMPILE LEVEL", str(data.get("level", 1)), "%d PATCH RANKS" % int(data.get("patch_ranks", 0)), GREEN],
	]
	if include_dps:
		values.append(["PICKUPS", _number(data.get("pickups", 0)), "%s XP COLLECTED" % _number(data.get("xp", 0)), CYAN])
	var rows := ceili(float(values.size()) / columns)
	var cell := Vector2((r.size.x - 8 * (columns - 1)) / columns, (r.size.y - 8 * (rows - 1)) / rows)
	for index in values.size():
		var rect := Rect2(r.position + Vector2(index % columns, index / columns) * (cell + Vector2(8, 8)), cell)
		draw_rect(rect, PANEL)
		draw_line(rect.position, rect.position + Vector2(0, rect.size.y), values[index][3], 2)
		var short := rect.size.y < 60
		_text(values[index][0], rect.position + Vector2(12, 14), 10, MUTED, cell.x - 24)
		_text(values[index][1], rect.position + Vector2(12, 35 if short else 47), 22 if short else 31, values[index][3], cell.x - 24)
		if not short:
			_text(values[index][2], rect.position + Vector2(12, cell.y - 11), 10, MUTED, cell.x - 24)


func _panel(r: Rect2, title: String, note: String = "") -> void:
	draw_rect(r, PANEL)
	draw_rect(r, EDGE, false, 1)
	_text(title, r.position + Vector2(14, 22), 12, PAPER, r.size.x - 28)
	if not note.is_empty():
		_text(note, r.position + Vector2(r.size.x * 0.48, 22), 10, MUTED, r.size.x * 0.52 - 14, HORIZONTAL_ALIGNMENT_RIGHT)


func _arsenal(r: Rect2, portrait: bool = false) -> void:
	_panel(r, "01 / DAMAGE DISTRIBUTION")
	var sources: Dictionary = data.get("sources", {})
	var total := maxf(float(data.get("damage", 0)), 0.001)
	var duration := maxf(float(data.get("time", 0)), 0.001)
	var x := r.position.x + 14
	var y := r.position.y + 43
	var width := r.size.x - 28
	var ids: Array = SOURCE_ORDER.duplicate()
	if not data.get("combo", {}).is_empty():
		ids = ["GRAVITON_SALVO", "MASS_DRIVER", "ARC_EXE", "MASS_DRIVER_RETURN", "MASS_DRIVER_FORK"]
	for id: String in sources:
		if not ids.has(id) and not (id == "VENT" and not data.get("combo", {}).is_empty()):
			ids.append(id)
	if not portrait:
		_text("PROCESS", Vector2(x, y), 9, MUTED, width * 0.29)
		for item in [["DAMAGE", 0.30, 0.16], ["DPS", 0.47, 0.11], ["FIRED", 0.59, 0.09], ["HITS", 0.69, 0.09], ["KILLS", 0.79, 0.09], ["SHARE", 0.89, 0.11]]:
			_text(item[0], Vector2(x + width * item[1], y), 9, MUTED, width * item[2], HORIZONTAL_ALIGNMENT_RIGHT)
		y += 10
	var row_height := (r.end.y - 52 - y) / maxi(ids.size(), 1)
	for index in ids.size():
		var id: String = ids[index]
		var entry: Dictionary = sources.get(id, {})
		var damage := float(entry.get("damage", 0))
		var share := damage / total
		var color: Color = {"GRAVITON_SALVO": Color("b5a0ff"), "MASS_DRIVER": CYAN, "ARC_EXE": BLUE, "MASS_DRIVER_RETURN": AMBER, "MASS_DRIVER_FORK": GREEN, "VENT": RED}.get(id, SOURCE_COLORS[index % SOURCE_COLORS.size()])
		var baseline := y + 12
		_text(_source_label(id), Vector2(x, baseline), 11, color, width * (0.62 if portrait else 0.29))
		if portrait:
			_text(_number(damage, true) + " / %.1f%%" % (share * 100), Vector2(x + width * 0.61, baseline), 12, PAPER, width * 0.39, HORIZONTAL_ALIGNMENT_RIGHT)
			_text("%.1f DPS   %d FIRED   %d HITS   %d KILLS" % [damage / duration, entry.get("attacks", 0), entry.get("hits", 0), entry.get("kills", 0)], Vector2(x, baseline + 21), 10, MUTED, width)
			_bar(Rect2(x, baseline + 29, width, 4), share, color)
		else:
			var cells := [[_number(damage, true), 0.30, 0.16], ["%.1f" % (damage / duration), 0.47, 0.11], [str(entry.get("attacks", 0)), 0.59, 0.09], [str(entry.get("hits", 0)), 0.69, 0.09], [str(entry.get("kills", 0)), 0.79, 0.09], ["%.1f%%" % (share * 100), 0.89, 0.11]]
			for cell in cells:
				_text(cell[0], Vector2(x + width * cell[1], baseline), 11, PAPER, width * cell[2], HORIZONTAL_ALIGNMENT_RIGHT)
			_bar(Rect2(x, baseline + 5, width * 0.285, 3), share, color)
		y += row_height
	var driver: Dictionary = _sections.get("MASS_DRIVER", {})
	var arc: Dictionary = _sections.get("ARC.EXE", {})
	_text("DRIVER  DMG / TARGETS " + str(driver.get("Round damage / target capacity", "24 / 2")) + "   INTERVAL " + str(driver.get("Fire interval (before heat)", "0.720s")), Vector2(x, r.end.y - 29), 10, MUTED, width)
	_text("ARC  DMG 13 / -10% PER JUMP   BRANCH / HITS " + str(arc.get("Branches / targets per chain", "1 / 3")) + "   " + str(arc.get("Cast interval (before heat)", "1.180s")), Vector2(x, r.end.y - 13), 10, MUTED, width)


func _ship(r: Rect2) -> void:
	_panel(r, "02 / HULL & SHIELD")
	var ship: Dictionary = data.get("ship", {})
	var config: Dictionary = _sections.get("SHIP / FINAL CONFIGURATION", {})
	var width := r.size.x - 28
	var x := r.position.x + 14
	var y := r.position.y + 42
	for item in [["HULL", "hull", "max_hull", GREEN], ["SHIELD", "shield", "max_shield", BLUE]]:
		_text(item[0], Vector2(x, y), 10, MUTED, width * 0.5)
		_text("%.1f / %.1f" % [float(data.get(item[1], 0)), float(data.get(item[2], 0))], Vector2(x + width * 0.5, y), 11, PAPER, width * 0.5, HORIZONTAL_ALIGNMENT_RIGHT)
		_bar(Rect2(x, y + 5, width, 3), float(data.get(item[1], 0)) / maxf(float(data.get(item[2], 1)), 1), item[3])
		y += 24
	var entries := [
		["DAMAGE TAKEN / HITS", "%.1f / %d" % [float(ship.get("hull_damage", 0)) + float(ship.get("shield_absorbed", 0)), ship.get("hits_taken", 0)]],
		["HULL LOST / ABSORBED", "%.1f / %.1f" % [ship.get("hull_damage", 0), ship.get("shield_absorbed", 0)]],
		["REPAIR / RESTORE", "%.1f / %.1f" % [ship.get("hull_repaired", 0), ship.get("shield_restored", 0)]],
		["MOVE SPEED", config.get("Move speed", "--")],
		["DISTANCE", config.get("Distance traveled", "--")],
		["SHIELD RECHARGE", config.get("Shield recharge", "--")],
		["HIT PROTECTION", config.get("Hit protection", "--")],
	]
	_rows(entries, Vector2(x, y), width, (r.end.y - 12 - y) / 6)


func _reactor(r: Rect2) -> void:
	_panel(r, "03 / REACTOR")
	var ship: Dictionary = data.get("ship", {})
	var config: Dictionary = _sections.get("REACTOR / VENT", {})
	var width := r.size.x - 28
	var x := r.position.x + 14
	var y := r.position.y + 44
	_text("FINAL HEAT", Vector2(x, y), 10, MUTED, width * 0.50)
	_text("%.1f / %.0f" % [data.get("heat", 0), data.get("max_heat", 100)], Vector2(x + width * 0.50, y), 17, AMBER, width * 0.50, HORIZONTAL_ALIGNMENT_RIGHT)
	_bar(Rect2(x, y + 8, width, 7), float(data.get("heat", 0)) / maxf(float(data.get("max_heat", 100)), 1), AMBER)
	y += 38
	var entries := [
		["PEAK HEAT", "%.1f" % float(ship.get("peak_heat", 0))],
		["GENERATED / VENTED", "%.1f / %.1f" % [ship.get("heat_generated", 0), ship.get("heat_vented", 0)]],
		["COOLING", config.get("Cooling", "--")],
		["THROTTLED", "%.1fs" % float(ship.get("throttled_seconds", 0))],
		["VENTS / HOT VENTS", "%d / %d" % [ship.get("vents", 0), ship.get("hot_vents", 0)]],
		["VENT COOLDOWN", config.get("VENT cooldown", "--")],
	]
	if not data.get("combo", {}).is_empty():
		entries = [
			["PEAK HEAT", "%.1f" % float(ship.get("peak_heat", 0))],
			["HEAT GENERATED", "%.1f" % float(ship.get("heat_generated", 0))],
			["KIT HEAT SPENT", "%.1f" % float(data["combo"].get("heat_spent", 0))],
			["COOLING", config.get("Cooling", "--")],
			["THROTTLED", "%.1fs" % float(ship.get("throttled_seconds", 0))],
			["PHASE COOLDOWN", "4.20s / NO HEAT COST"],
		]
	_rows(entries, Vector2(x, y), width, (r.end.y - 12 - y) / 5)


func _combo_details(r: Rect2, strip: bool = false) -> void:
	var kit: Dictionary = data.get("combo", {})
	var items := [
		["CHARGES / CANCELED", "%d / %d" % [kit.get("charges", 0), kit.get("cancels", 0)]],
		["SALVOS / FULL RACK", "%d / %d" % [kit.get("salvos", 0), kit.get("full_salvos", 0)]],
		["MISSILES / CONNECTED", "%d / %d" % [kit.get("missiles", 0), kit.get("hits", 0)]],
		["PULL CONTACTS / RETARGETS", "%d / %d" % [kit.get("grouped", 0), kit.get("retargets", 0)]],
		["CHARGING / HEAT SPENT", "%.1fs / %.1f" % [kit.get("charge_seconds", 0), kit.get("heat_spent", 0)]],
		["PHASE USES / DISTANCE", "%d / %.0f" % [kit.get("phase_uses", 0), kit.get("phase_distance", 0)]],
	]
	if strip:
		for index in items.size():
			var cell := Rect2(r.position + Vector2(index * r.size.x / 6, 0), Vector2(r.size.x / 6 - 8, r.size.y))
			draw_rect(cell, PANEL)
			_text(items[index][0], cell.position + Vector2(9, 13), 9, MUTED, cell.size.x - 18)
			_text(items[index][1], cell.position + Vector2(9, 33), 15, CYAN, cell.size.x - 18)
	else:
		_panel(r, "06 / GRAVITON + SALVO KIT")
		_rows(items, r.position + Vector2(14, 58), r.size.x - 28, (r.size.y - 80) / 6)


func _recovery(r: Rect2) -> void:
	_panel(r, "04 / CONTACTS & SALVAGE")
	var x := r.position.x + 14
	var y := r.position.y + 45
	var width := r.size.x - 28
	var enemies: Dictionary = data.get("enemies", {})
	var short := r.size.y < 130
	var slot := width * (0.48 if short else 1.0) / 4
	for i in range(4):
		var id: String = ["bit", "vector", "sentry", "boss"][i]
		var color: Color = [RED, AMBER, BLUE, CYAN][i]
		var offset := Vector2(x + slot * i + 5, y - 4)
		if i == 1:
			draw_polyline(PackedVector2Array([offset + Vector2(-4, 4), offset + Vector2(4, 0), offset + Vector2(-4, -4)]), color, 1.5, true)
		elif i == 2:
			draw_rect(Rect2(offset - Vector2(4, 4), Vector2(8, 8)), color, false, 1.5)
		else:
			draw_circle(offset, 4, color, false, 1.5, true)
		_text(str(enemies.get(id, 0)), Vector2(x + slot * i + 16, y), 17, PAPER, slot - 20)
		_text(id.to_upper(), Vector2(x + slot * i, y + 17), 9, MUTED, slot - 3)
	if short:
		var xp_x := x + width * 0.53
		var xp_width := width * 0.47
		_text("LEVEL %d   /   %d:%d XP" % [data.get("level", 1), data.get("level_xp", 0), data.get("next_xp", 1)], Vector2(xp_x, y), 11, GREEN, xp_width)
		_bar(Rect2(xp_x, y + 6, xp_width, 4), float(data.get("level_xp", 0)) / maxf(float(data.get("next_xp", 1)), 1), GREEN)
		_text("%s XP / %s PICKUPS" % [_number(data.get("xp", 0)), _number(data.get("pickups", 0))], Vector2(xp_x, y + 24), 10, PAPER, xp_width)
		_text("%.1f KILLS/MIN   /   BOSS %s   /   %s" % [float(data.get("kills_per_minute", 0)), data.get("boss", "NOT REACHED"), data.get("sector", "STATIC_PROOF")], Vector2(x, r.end.y - 8), 9, MUTED, width)
		return
	var progress_y := y + 36
	_text("LEVEL %d" % int(data.get("level", 1)), Vector2(x, progress_y), 10, GREEN, width * 0.4)
	_text("%d / %d XP" % [data.get("level_xp", 0), data.get("next_xp", 1)], Vector2(x + width * 0.4, progress_y), 10, MUTED, width * 0.6, HORIZONTAL_ALIGNMENT_RIGHT)
	_bar(Rect2(x, progress_y + 7, width, 5), float(data.get("level_xp", 0)) / maxf(float(data.get("next_xp", 1)), 1), GREEN)
	_text("%s XP   /   %s PICKUPS" % [_number(data.get("xp", 0)), _number(data.get("pickups", 0))], Vector2(x, progress_y + 29), 11, PAPER, width)
	if r.size.y > 180:
		_text("BOSS  " + str(data.get("boss", "NOT REACHED")), Vector2(x, progress_y + 61), 12, CYAN, width)
		_text("SECTOR  " + str(data.get("sector", "STATIC_PROOF")), Vector2(x, progress_y + 83), 11, MUTED, width)
		_text("%.1f KILLS / MIN" % float(data.get("kills_per_minute", 0)), Vector2(x, r.end.y - 15), 11, MUTED, width)
	elif is_compact():
		_text("BOSS " + str(data.get("boss", "NOT REACHED")) + " / " + str(data.get("sector", "STATIC_PROOF")), Vector2(x, r.end.y - 8), 9, MUTED, width)


func _build(r: Rect2, columns: int) -> void:
	var patches: Array = data.get("patches", [])
	_panel(r, "05 / INSTALLED PATCHES", "%d TYPES / %d RANKS" % [patches.size(), data.get("patch_ranks", 0)] if r.size.x > 500 else "")
	if patches.is_empty():
		_text("BASELINE / NO PATCHES INSTALLED", r.position + Vector2(16, 58), 15, MUTED, r.size.x - 32)
		return
	var width := (r.size.x - 28 - (columns - 1) * 8) / columns
	var rows := ceili(float(patches.size()) / columns)
	var height := minf(46.0 if r.size.y > 200 else 24.0, (r.size.y - 44) / rows)
	for index in patches.size():
		var patch: Dictionary = patches[index]
		var cell := Rect2(r.position + Vector2(14 + (index % columns) * (width + 8), 35 + (index / columns) * height), Vector2(width, height - 3))
		var color := CYAN
		var target := str(patch.get("target", ""))
		if target.contains("ARC"):
			color = BLUE
		elif target.contains("HULL") or target.contains("SHIELD"):
			color = GREEN
		elif target.contains("VENT") or target.contains("ALL"):
			color = AMBER
		draw_rect(cell, Color("192c36"))
		var two_lines := height > 35
		_text(str(patch.get("id", "PATCH")), cell.position + Vector2(7, 14), 10, PAPER, width - (12 if two_lines else 43))
		var rank := int(patch.get("rank", 0))
		var maximum := int(patch.get("max_rank", 3))
		var pip_origin := cell.position + Vector2(8, 29) if two_lines else cell.position + Vector2(width - 33, 8)
		for pip in maximum:
			draw_rect(Rect2(pip_origin + Vector2(pip * 9, 0), Vector2(6, 6)), color if pip < rank else EDGE)
		if two_lines:
			_text("R%d / %d" % [rank, maximum], cell.position + Vector2(width - 61, 34), 10, color, 54, HORIZONTAL_ALIGNMENT_RIGHT)
	if r.size.y > 200:
		_text("%d PATCH TYPES  /  %d TOTAL RANKS" % [patches.size(), data.get("patch_ranks", 0)], Vector2(r.position.x + 14, r.end.y - 17), 11, MUTED, r.size.x - 28)


func _rows(entries: Array, start: Vector2, width: float, step: float) -> void:
	for index in entries.size():
		var point := start + Vector2(0, step * index)
		_text(str(entries[index][0]), point, 9, MUTED, width * 0.52)
		_text(str(entries[index][1]), point + Vector2(width * 0.53, 0), 11, PAPER, width * 0.47, HORIZONTAL_ALIGNMENT_RIGHT)


func _bar(r: Rect2, fraction: float, color: Color) -> void:
	draw_rect(r, TRACK)
	if fraction > 0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(fraction, 0, 1), r.size.y)), color)


func _text(value: String, position: Vector2, font_size: int, color: Color, width: float, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# Shrink isolated long values, never let content expand a panel offscreen.
	var fitted := font_size
	while fitted > 8 and _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	var visible := value
	while visible.length() > 1 and _font.get_string_size(visible, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		visible = visible.left(visible.length() - 2) + "…"
	draw_string(_font, position, visible, alignment, width, fitted, color)


func _number(value: Variant, keep_fraction: bool = false) -> String:
	var rounded := roundf(float(value) * 10.0) / 10.0 if keep_fraction else roundf(float(value))
	var digits := str(int(rounded))
	var output := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			output += ","
		output += digits[index]
	var fraction := int(roundf((rounded - floorf(rounded)) * 10.0))
	if keep_fraction and fraction > 0:
		output += ".%d" % fraction
	return output


func _time(seconds: float) -> String:
	return "%02d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func _source_label(id: String) -> String:
	return {"GRAVITON_SALVO": "GRAVITON SALVO", "MASS_DRIVER": "MASS DRIVER", "ARC_EXE": "ARC.EXE", "MASS_DRIVER_RETURN": "RETURN VECTOR", "MASS_DRIVER_FORK": "FORK ON KILL", "VENT": "VENT PULSE"}.get(id, id)
