class_name BossHealthBar
extends Node2D

const MAGENTA := Color("ff4fd8")
const OFFSET := Vector2(0, -70)
var health_ratio := 1.0


func _ready() -> void:
	# Keep scene ownership/lifetime, but never inherit the boss's spin or scale.
	top_level = true
	z_index = 1
	_process(0.0)


func _process(_delta: float) -> void:
	var boss = get_parent()
	if not is_instance_valid(boss):
		return
	global_position = boss.global_position + OFFSET
	global_rotation = 0.0
	health_ratio = boss.get_health_ratio()
	visible = not boss.is_dead
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(-52, 0, 104, 7)
	draw_rect(bar, Color(0.08, 0.02, 0.08, 0.92), true)
	draw_rect(Rect2(bar.position + Vector2.ONE, Vector2(102 * health_ratio, 5)), MAGENTA, true)
	draw_rect(bar, Color(MAGENTA, 0.72), false, 1)
