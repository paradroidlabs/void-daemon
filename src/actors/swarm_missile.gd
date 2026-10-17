class_name SwarmMissile
extends Node2D

signal detonated(position: Vector2)
signal retired(hit: bool, retargets: int)
var target: Node2D
var target_position := Vector2.ZERO
var direction := Vector2.RIGHT
var speed := 380.0
var lifetime := 1.8
var age := 0.0
var retargets := 0
var spent := false
var damage := 24.0
var splash_radius := 76.0
var trail: Array[Vector2] = []


func configure(origin: Vector2, aim: Vector2, destination: Vector2, contact: Node2D = null) -> void:
	global_position = origin
	direction = aim.normalized()
	target_position = destination
	target = contact
	z_index = 23
	add_to_group("swarm_missiles")


func _physics_process(delta: float) -> void:
	if spent:
		return
	age += delta
	if is_instance_valid(target) and target.has_method("is_alive") and target.is_alive():
		target_position = target.global_position
	elif retargets < 2:
		_retarget()
	var wanted := target_position - global_position
	direction = Vector2.RIGHT.rotated(rotate_toward(direction.angle(), wanted.angle(), 5.0 * delta))
	speed = minf(720, speed + delta * 600)
	var previous := global_position
	global_position += direction * speed * delta
	trail.push_front(global_position)
	if trail.size() > 12:
		trail.pop_back()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _alive(enemy):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, previous, global_position)
		var hit_radius := float(enemy.collision_radius) + 5.0
		if closest.distance_to(enemy.global_position) <= hit_radius:
			detonate(closest, enemy)
			return
	if wanted.length() < speed * delta + 12 or age >= lifetime:
		detonate(global_position)
	queue_redraw()


func _retarget() -> void:
	var best: Node2D
	var distance := 190.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _alive(enemy):
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if offset.normalized().dot(direction) > -0.15 and offset.length() < distance:
			best = enemy
			distance = offset.length()
	if best != null:
		target = best
		target_position = best.global_position
		retargets += 1


func detonate(position: Vector2, direct: Node2D = null) -> void:
	if spent:
		return
	spent = true
	var hit := false
	# Each receiver appears once. A direct hit is the full payload, not a second
	# full-damage splash layered onto it.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _alive(enemy):
			continue
		var distance: float = enemy.global_position.distance_to(position)
		if enemy == direct or distance <= splash_radius:
			var amount := damage if enemy == direct else damage * lerpf(0.72, 0.42, clampf(distance / splash_radius, 0, 1))
			enemy.take_damage(amount, &"GRAVITON_SALVO", position)
			hit = true
	detonated.emit(position)
	retired.emit(hit, retargets)
	queue_free()


func _alive(node: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion() and node is Node2D and node.has_method("is_alive") and node.is_alive()


func _draw() -> void:
	for index in range(1, trail.size()):
		draw_line(trail[index] - global_position, trail[index - 1] - global_position, Color(1, 0.72, 0.3, (1.0 - float(index) / 12.0) * 0.8), 2.0, true)
	var side := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([direction * 9, -direction * 6 + side * 4, -direction * 3, -direction * 6 - side * 4]), Color("ffdba0"))
	draw_line(-direction * 6, -direction * 14, Color("ad92ff"), 3, true)
