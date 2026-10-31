class_name SubstrateAgent
extends Enemy

var role := "scout"
var task := "PATROL"
var stable_id := ""


func set_gravity_velocity(value: Vector2) -> void:
	if role != "relay":
		super.set_gravity_velocity(value)


func apply_impulse(value: Vector2) -> void:
	if role != "relay":
		super.apply_impulse(value)


func _draw() -> void:
	super._draw()
	if not is_alive():
		return
	var color := Color("8de6ce") if role == "scout" else Color("ffc36b")
	if role == "relay":
		color = Color("b4a0ff")
		draw_arc(Vector2.ZERO, 26, 0, TAU, 32, color, 2, true)
		draw_line(Vector2(-31, 0), Vector2(31, 0), color, 1)
		draw_line(Vector2(0, -31), Vector2(0, 31), color, 1)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-48, -34), role.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 96, 10, color)
	draw_string(font, Vector2(-64, 35), task, HORIZONTAL_ALIGNMENT_CENTER, 128, 9, Color("91aab3"))
