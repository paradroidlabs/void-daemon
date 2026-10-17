class_name GravitonField
extends Node2D

const COLOR := Color("b5a0ff")
var radius := 220.0
var lifetime := 2.8
var age := 0.0
var expired := false
var released := false
var affected_ids: Dictionary = {}
var contacts: Array[Vector2] = []
var _captured: Array[Node2D] = []
var _selection_left := 0.0


func configure(center: Vector2, range_radius: float = 220.0) -> void:
	global_position = center
	radius = range_radius
	z_index = -2
	add_to_group("graviton_fields")


func release_field() -> void:
	released = true
	lifetime = minf(lifetime, age + 1.15)


func tick(delta: float, enemies: Array[Node]) -> void:
	if expired:
		return
	age += delta
	contacts.clear()
	if age >= lifetime:
		expired = true
		queue_free()
		return
	# Hold has a bounded control window; waiting at full charge cannot freeze a
	# formation forever. The release extends the existing window only up to cap.
	var strength := 0.35 if age > 1.65 and not released else 1.0
	_selection_left -= delta
	if _selection_left <= 0:
		_selection_left = 0.10
		var candidates: Array[Node2D] = []
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy is Node2D and enemy.has_method("is_alive") and enemy.is_alive() and enemy.has_method("set_gravity_velocity"):
				if enemy.global_position.distance_to(global_position) <= radius:
					candidates.append(enemy)
		candidates.sort_custom(func(a: Node2D, b: Node2D): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
		_captured.assign(candidates.slice(0, 12))
	for enemy in _captured:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.is_alive() or enemy.global_position.distance_to(global_position) > radius:
			continue
		var offset: Vector2 = global_position - enemy.global_position
		# A small orbital core retains readable silhouettes instead of placing
		# twelve collision centers on the exact same pixel.
		var pull := clampf((offset.length() - 34.0) * 5.0, -90.0, 290.0) * strength
		if enemy.has_method("get_state") and enemy.get_state() in [&"charge", &"windup"]:
			pull *= 0.18
		var orbit := offset.normalized().orthogonal() * (22.0 * strength if offset.length() < 90 else 0.0)
		enemy.set_gravity_velocity(offset.normalized() * pull + orbit)
		affected_ids[enemy.get_instance_id()] = true
		contacts.append(enemy.global_position - global_position)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - age) / 0.35, 0.0, 1.0)
	var outer := radius * minf(1.0, age * 6.0)
	draw_circle(Vector2.ZERO, outer, Color(COLOR, 0.025 * fade))
	draw_arc(Vector2.ZERO, outer, age, age + TAU * 0.86, 64, Color(COLOR, 0.45 * fade), 1.3, true)
	draw_arc(Vector2.ZERO, 24 + sin(age * 9) * 4, -age * 2, -age * 2 + TAU * 0.74, 32, Color(COLOR, fade), 2, true)
	draw_arc(Vector2.ZERO, 11, age * 3, age * 3 + TAU * 0.6, 20, Color("e3d9ff"), 2, true)
	for index in range(18):
		var phase := fmod(age * 0.5 + float(index) / 18.0, 1.0)
		var point := Vector2.RIGHT.rotated(index * 2.4 + age * 0.65) * outer * (1.0 - phase)
		draw_line(point, point.normalized() * maxf(0, point.length() - 8), Color(COLOR, fade * phase), 1.5, true)
	for point in contacts:
		draw_line(point, point * 0.78, Color(COLOR, 0.35 * fade), 1, true)
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color("f1eaff"), 1.3)
	draw_line(Vector2(0, -8), Vector2(0, 8), Color("f1eaff"), 1.3)
