extends Control

var snapshot := {}
var combat_text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 82


func set_snapshot(value: Dictionary) -> void:
	snapshot = value
	queue_redraw()


func text(value: String, at: Vector2, width: float, color: Color, font_size: int = 12, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var font := get_theme_default_font()
	var fitted := value
	while fitted.length() > 1 and font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		fitted = fitted.left(fitted.length() - 2) + "…"
	draw_string(font, at, fitted, align, width, font_size, color)


func _draw() -> void:
	var cyan := Color("68f7e5")
	var muted := Color("86a6af")
	draw_rect(Rect2(Vector2.ZERO, size), Color("09131c"))
	draw_line(Vector2(0, 81), Vector2(size.x, 81), Color("29434e"), 1)
	var seconds := float(snapshot.get("time", 0))
	var chassis: String = String(snapshot.get("chassis", "COURIER")).to_upper()
	text("VOID//DAEMON / %s.R%02d" % [chassis, snapshot.get("level", 1)], Vector2(12, 19), size.x * 0.47, cyan, 14)
	text("%02d:%04.1f  /  PURGED %04d" % [int(seconds) / 60, fmod(seconds, 60), snapshot.get("kills", 0)], Vector2(size.x * 0.53, 19), size.x * 0.47 - 12, Color("ffbd4a"), 12, HORIZONTAL_ALIGNMENT_RIGHT)
	var width := (size.x - 40) / 3
	var entries := [["HULL + SHIELD", "integrity", "max_integrity", cyan], ["HEAT", "heat", "max_heat", Color("ffbd4a")], ["COMPILE", "xp", "xp_next", Color("b5a0ff")]]
	for index in 3:
		var item: Array = entries[index]
		var x := 12 + index * (width + 8)
		var value := float(snapshot.get(item[1], 0))
		var maximum := maxf(1, snapshot.get(item[2], 100))
		text("%s %03d / %03d" % [item[0], value, maximum], Vector2(x, 39), width, muted, 11)
		draw_rect(Rect2(x, 46, width, 4), Color("243742"))
		draw_rect(Rect2(x, 46, width * clampf(value / maximum, 0, 1), 4), item[3])
	var detail := combat_text
	if snapshot.has("maneuver_name"):
		var cooldown := float(snapshot.get("phase_cooldown", 0))
		detail = "%s / %s / %s" % [snapshot.get("attack_name", "M1"), snapshot["maneuver_name"], "READY" if cooldown <= 0 else "%.1fs" % cooldown]
		if size.x > 1000:
			detail += "    SEED " + String(snapshot.get("seed", "--"))
	if detail.is_empty():
		detail = "SPACE / VENT    SEED " + String(snapshot.get("seed", "--"))
	text(detail, Vector2(12, 71), size.x - 24, muted, 11)
