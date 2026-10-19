class_name FlightTelemetry
extends Control

const CYAN := Color("68f7e5")
const AMBER := Color("ffbd4a")
const PURPLE := Color("b39cff")
const MUTED := Color("7999a5")
var data: Dictionary = {}
var dock_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 72) if dock_mode else Vector2(254, 178)
	size = custom_minimum_size


func set_flight(snapshot: Dictionary) -> void:
	data = snapshot
	queue_redraw()


func _draw_dock() -> void:
	var throttle := float(data.get("throttle", 0))
	var mode := "BRAKING" if data.get("counterthrust", false) else ("THRUST" if throttle > 0.05 else "COAST")
	_text("FLIGHT / " + mode, Vector2(0, 11), MUTED, 10)
	_text("%05.1f u/s" % float(data.get("speed", 0)), Vector2(0, 31), AMBER, 18)
	var track := float(data.get("track", -1))
	_text("HDG %03.0f  TRK %s  SLIP %03.0f" % [data.get("heading", 0), "%03.0f" % track if track >= 0 else "---", data.get("drift", 0)], Vector2(0, 48), CYAN, 10)
	_text("THR %03.0f%% / DRAG %.2f / G %.0f" % [throttle * 100, data.get("drag", 0), Vector2(data.get("gravity", Vector2.ZERO)).length()], Vector2(0, 65), PURPLE, 10)
	if size.x < 300:
		return
	var center := Vector2(size.x - 36, 34)
	draw_arc(center, 25, 0, TAU, 32, MUTED, 1, true)
	var heading := Vector2.RIGHT.rotated(deg_to_rad(float(data.get("heading", 90)) - 90))
	draw_line(center, center + heading * 22, CYAN, 2, true)
	if track >= 0:
		var travel := Vector2.RIGHT.rotated(deg_to_rad(track - 90)) * 19
		draw_line(center, center + travel, AMBER, 1, true)
		draw_arc(center + travel, 3, 0, TAU, 12, AMBER, 1, true)


func _text(value: String, position: Vector2, color: Color = CYAN, font_size: int = 12) -> void:
	draw_string(get_theme_default_font(), position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if data.is_empty():
		return
	if dock_mode:
		_draw_dock()
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1721"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("29434e"), false, 1)
	var throttle := float(data.get("throttle", 0))
	var mode := "COUNTERTHRUST" if data.get("counterthrust", false) else ("THRUST" if throttle > 0.05 else "COAST")
	if not data.get("inertial", false):
		mode = "DIRECT / A-B"
	_text("FLIGHT RECORDER  /  " + mode, Vector2(10, 17), MUTED, 11)
	_text("%05.1f" % float(data.get("speed", 0)), Vector2(12, 50), AMBER, 26)
	_text("u/s  /  ARENA RELATIVE", Vector2(13, 67), MUTED, 10)
	var center := Vector2(200, 64)
	draw_arc(center, 35, 0, TAU, 48, Color("315562"), 1, true)
	draw_line(center - Vector2(40, 0), center + Vector2(40, 0), Color("223c48"), 1)
	draw_line(center - Vector2(0, 40), center + Vector2(0, 40), Color("223c48"), 1)
	_text("N", center + Vector2(-3, -24), MUTED, 9)
	var heading := Vector2.RIGHT.rotated(deg_to_rad(float(data.get("heading", 90)) - 90))
	var nose := center + heading * 24
	draw_polyline(PackedVector2Array([center + heading.orthogonal() * 6, nose, center - heading.orthogonal() * 6]), CYAN, 2, true)
	var track := float(data.get("track", -1))
	if track >= 0:
		var prograde := Vector2.RIGHT.rotated(deg_to_rad(track - 90)) * 28
		draw_line(center, center + prograde, AMBER, 1.4, true)
		draw_arc(center + prograde, 4, 0, TAU, 16, AMBER, 1.4, true)
	var gravity: Vector2 = data.get("gravity", Vector2.ZERO)
	if gravity.length_squared() > 1:
		draw_line(center, center + gravity.normalized() * 18, PURPLE, 2, true)
	var track_text := "%03.0f" % track if track >= 0 else "---"
	_text("HDG %03.0f  TRK %s  SLIP %03.0f" % [data.get("heading", 0), track_text, data.get("drift", 0)], Vector2(12, 94), CYAN, 11)
	var speed_ratio := clampf(float(data.get("speed", 0)) / maxf(1, data.get("speed_limit", 1)), 0, 1)
	draw_rect(Rect2(12, 104, 230, 4), Color("263b48"))
	draw_rect(Rect2(12, 104, 230 * speed_ratio, 4), AMBER)
	var cruise_x := 12 + 230 * float(data.get("cruise", 285)) / float(data.get("speed_limit", 627))
	draw_line(Vector2(cruise_x, 101), Vector2(cruise_x, 111), CYAN, 1)
	_text("THRUST %03.0f%%" % (throttle * 100), Vector2(12, 127), AMBER, 11)
	draw_rect(Rect2(117, 119, 125, 5), Color("263b48"))
	draw_rect(Rect2(117, 119, 125 * throttle, 5), AMBER)
	_text("DRAG %.2f/s   GRAV %05.1f u/s2" % [data.get("drag", 0), gravity.length()], Vector2(12, 147), PURPLE, 11)
	_text("CYAN: NOSE / AMBER: TRAVEL", Vector2(12, 166), MUTED, 10)
