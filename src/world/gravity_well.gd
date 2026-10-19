class_name GravityWell
extends Node2D

var field_radius := 560.0
var softening := 130.0
var peak_acceleration := 180.0


func _ready() -> void:
	z_index = -2
	queue_redraw()


func acceleration_at(point: Vector2) -> Vector2:
	var offset := global_position - point
	var distance := offset.length()
	if distance < 0.001 or distance >= field_radius:
		return Vector2.ZERO
	var x := distance / softening
	var softened := x / pow(1.0 + x * x, 1.5) / 0.3849
	var edge := 1.0 - smoothstep(field_radius * 0.7, field_radius, distance)
	return offset / distance * peak_acceleration * softened * edge


func _draw() -> void:
	var ink := Color("b39cff")
	draw_circle(Vector2.ZERO, 17, Color("120f21"))
	draw_arc(Vector2.ZERO, 19, 0, TAU, 40, ink, 2, true)
	for radius in [65.0, 130.0, 260.0, field_radius]:
		for index in range(24):
			var angle := TAU * float(index) / 24
			draw_arc(Vector2.ZERO, radius, angle, angle + 0.13, 4, Color(ink, 0.32 if radius == field_radius else 0.13), 1, true)
	for index in range(8):
		var axis := Vector2.RIGHT.rotated(TAU * float(index) / 8)
		var p := axis * 175
		draw_line(p + axis * 10, p - axis * 10, Color(ink, 0.4), 1, true)
		draw_line(p - axis * 10, p - axis * 3 + axis.orthogonal() * 4, Color(ink, 0.4), 1, true)
	draw_string(ThemeDB.fallback_font, Vector2(-43, -31), "MASS WELL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink)
	draw_string(ThemeDB.fallback_font, Vector2(-54, 42), "ESCAPABLE / NO DAMAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(ink, 0.7))
