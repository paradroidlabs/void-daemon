class_name ArenaBackdrop
extends Node2D

const VOID := Color("02070c")
const GRID := Color("0b2930")
const EDGE := Color("275e66")
const STAR := Color("7ce9da")
const AMBER := Color("ffbd4a")

var arena_bounds := Rect2(-1600.0, -900.0, 3200.0, 1800.0)
var run_seed: int = 1


func configure(bounds: Rect2, seed_value: int) -> void:
	arena_bounds = bounds
	run_seed = seed_value
	queue_redraw()


func _draw() -> void:
	draw_rect(arena_bounds, VOID, true)
	var grid_step := 160.0
	var first_x := floorf(arena_bounds.position.x / grid_step) * grid_step
	var first_y := floorf(arena_bounds.position.y / grid_step) * grid_step
	var x := first_x
	while x <= arena_bounds.end.x:
		draw_line(Vector2(x, arena_bounds.position.y), Vector2(x, arena_bounds.end.y), GRID, 1.0)
		x += grid_step
	var y := first_y
	while y <= arena_bounds.end.y:
		draw_line(Vector2(arena_bounds.position.x, y), Vector2(arena_bounds.end.x, y), GRID, 1.0)
		y += grid_step

	for index in range(230):
		var h1 := _hash(index * 2 + run_seed)
		var h2 := _hash(index * 2 + 1 + run_seed * 3)
		var px := lerpf(arena_bounds.position.x + 20.0, arena_bounds.end.x - 20.0, float(h1 & 0xffff) / 65535.0)
		var py := lerpf(arena_bounds.position.y + 20.0, arena_bounds.end.y - 20.0, float(h2 & 0xffff) / 65535.0)
		var radius := 0.7 + float((h1 >> 16) & 3) * 0.35
		var alpha := 0.18 + float((h2 >> 18) & 7) * 0.045
		draw_circle(Vector2(px, py), radius, Color(STAR, alpha))

	# Decorative relay/anomaly marks. They do not affect collision in this proof.
	for index in range(7):
		var h1 := _hash(run_seed + 1000 + index * 7)
		var h2 := _hash(run_seed + 2000 + index * 11)
		var center := Vector2(
			lerpf(arena_bounds.position.x + 260.0, arena_bounds.end.x - 260.0, float(h1 & 0xffff) / 65535.0),
			lerpf(arena_bounds.position.y + 180.0, arena_bounds.end.y - 180.0, float(h2 & 0xffff) / 65535.0)
		)
		var radius := 30.0 + float((h1 >> 17) & 31)
		draw_arc(center, radius, 0.0, TAU, 32, Color(AMBER, 0.12), 1.0)
		draw_line(center - Vector2(radius + 12.0, 0.0), center + Vector2(radius + 12.0, 0.0), Color(AMBER, 0.08), 1.0)
		draw_line(center - Vector2(0.0, radius + 12.0), center + Vector2(0.0, radius + 12.0), Color(AMBER, 0.08), 1.0)

	draw_rect(arena_bounds, EDGE, false, 3.0)
	draw_rect(arena_bounds.grow(-12.0), Color(EDGE, 0.35), false, 1.0)


func _hash(value: int) -> int:
	var x := value & 0xffffffff
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xffffffff
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xffffffff
	return (x ^ (x >> 16)) & 0xffffffff

