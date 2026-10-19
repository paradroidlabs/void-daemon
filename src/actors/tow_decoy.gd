class_name TowDecoy
extends Node2D

var player: Node2D
var lifetime := 1.4
var _captured: Array[Node2D] = []


func _ready() -> void:
	z_index = 10
	for enemy in get_tree().get_nodes_in_group("enemy_normal"):
		if _captured.size() >= 12:
			break
		if enemy.global_position.distance_to(global_position) < 320 and enemy.is_alive() and enemy.get_state() not in [&"charge", &"windup"]:
			enemy.set_target(self)
			_captured.append(enemy)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
	queue_redraw()


func _exit_tree() -> void:
	if is_instance_valid(player):
		for enemy in _captured:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
				enemy.set_target(player)


func _draw() -> void:
	var color := Color(0.48, 0.88, 0.67, clampf(lifetime / 1.4, 0, 1))
	draw_arc(Vector2.ZERO, 24, 0, TAU, 24, color, 1.5, true)
	draw_polyline(PackedVector2Array([Vector2(15,0),Vector2(-12,-12),Vector2(-6,0),Vector2(-12,12),Vector2(15,0)]), color, 1.5, true)
	draw_string(ThemeDB.fallback_font, Vector2(-30, -34), "TOW ECHO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
