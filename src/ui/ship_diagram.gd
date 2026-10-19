extends Control

var upgrades: Dictionary = {}
var charge := 0.0
var primary_flash := 0.0
var arc_flash := 0.0
var fork_flash := 0.0
var chassis := "COURIER"
var show_upgrade_list := true
const CYAN := Color("68f7e5")
const AMBER := Color("ffbd4a")
const ARC := Color("9aa7ff")

func _process(delta: float) -> void:
	fork_flash = maxf(0.0, fork_flash - delta)
	queue_redraw()

func _draw() -> void:
	draw_style_box(_box(), Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, 22), "%s // MODULES" % chassis, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CYAN)
	var origin := Vector2(75, 88)
	var ship := PackedVector2Array([origin + Vector2(25, 0), origin + Vector2(-18, -19), origin + Vector2(-9, 0), origin + Vector2(-18, 19), origin + Vector2(25, 0)])
	if chassis == "BASTION":
		ship = PackedVector2Array([origin + Vector2(25, 0), origin + Vector2(9, -22), origin + Vector2(-20, -22), origin + Vector2(-20, 22), origin + Vector2(9, 22), origin + Vector2(25, 0)])
	elif chassis == "REDLINE":
		ship = PackedVector2Array([origin + Vector2(29, 0), origin + Vector2(-22, -12), origin + Vector2(-4, 0), origin + Vector2(-22, 12), origin + Vector2(29, 0)])
	elif chassis == "CONDUCTOR":
		ship = PackedVector2Array([origin + Vector2(22, 0), origin + Vector2(0, -22), origin + Vector2(-22, 0), origin + Vector2(0, 22), origin + Vector2(22, 0)])
	draw_polyline(ship, CYAN, 2.0)
	draw_line(origin + Vector2(25, 0), Vector2(130, 65), CYAN, 1.0)
	draw_circle(Vector2(132, 65), 5, CYAN if primary_flash > 0.0 else Color("1f827e"))
	draw_string(font, Vector2(146, 70), "AUTO DRIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CYAN)
	draw_line(origin + Vector2(0, 16), Vector2(130, 96), ARC, 1.0)
	draw_circle(Vector2(132, 96), 5, ARC if arc_flash > 0.0 else ARC.darkened(0.6))
	draw_string(font, Vector2(146, 101), "AUTO ARC: NEARBY CHAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ARC)
	draw_arc(origin, 33, -PI / 2, -PI / 2 + TAU * maxf(charge, 0.001), 40, AMBER, 3.0)
	draw_string(font, Vector2(12, 139), "M1 CHARGE %d%% -> RELEASE" % int(charge * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)
	var fork_rank := int(upgrades.get("FORK_ON_KILL", 0))
	draw_string(font, Vector2(12, 161), "KILL -> %d CHILD SHOTS" % fork_rank if fork_rank > 0 else "FORK: NOT INSTALLED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER if fork_rank > 0 else CYAN.darkened(0.6))
	for index in range(fork_rank):
		var child := Vector2(240 + index * 25, 153)
		draw_line(Vector2(222, 154), child, AMBER, 1.0)
		draw_circle(child, 4, AMBER if fork_flash > 0.0 else AMBER.darkened(0.6))
	draw_string(font, Vector2(12, 181), "CHILD = 45% DMG; NO FURTHER FORKS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, AMBER.darkened(0.2))
	if upgrades.has("RETURN_VECTOR"):
		draw_arc(origin, 26, PI * 0.45, PI * 1.55, 16, AMBER, 2.0)
	if upgrades.has("ARC_FANOUT"):
		for index in range(int(upgrades["ARC_FANOUT"])):
			draw_line(Vector2(132, 96), Vector2(128 - index * 12, 118), ARC, 2.0)
	if upgrades.has("DRIVER_RAIL"):
		draw_line(origin + Vector2(12, -7), origin + Vector2(37, -7), CYAN, 3.0)
	if upgrades.has("SHIELD_CAPACITOR") or upgrades.has("HULL_PLATING"):
		draw_arc(origin, 38, PI * 0.5, PI * 1.5, 16, CYAN, 2.0)
	var y := 205.0
	if not show_upgrade_list:
		return
	for id in upgrades:
		draw_string(font, Vector2(12, y), "%s R%d" % [id, upgrades[id]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CYAN)
		y += 15
	if upgrades.is_empty():
		draw_string(font, Vector2(12, y), "BASELINE // NO MODIFICATIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CYAN.darkened(0.4))

func _box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.01, 0.03, 0.04, 0.9)
	box.border_color = CYAN.darkened(0.55)
	box.set_border_width_all(1)
	return box
