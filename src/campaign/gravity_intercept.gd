extends Node2D

signal completed(result: Dictionary)
signal failed
const CYAN := Color("68f7e5")
const AMBER := Color("ffc36b")
var player: PlayerShip
var gates: Array[Vector2] = [Vector2(-1050,-480), Vector2(-300,-580), Vector2(550,-480), Vector2(1100,-100), Vector2(850,500), Vector2(150,580), Vector2(-650,450), Vector2(-1150,100), Vector2(-450,140), Vector2(-100,340), Vector2(500,340), Vector2(1050,100)]
var rocks: Array[Rect2] = [Rect2(-750,-430,160,470), Rect2(200,-250,180,520), Rect2(720,-120,150,190), Rect2(-100,-60,120,200)]
var next_gate := 0
var clock := 0.0
var courier_position := Vector2(-1350,-450)
var courier_gate := 0
var courier_arrived := false
var active := true
var bumps := 0
var _previous := Vector2.ZERO
var _impact_cooldown := 0.0
var _last_speed := 0.0
var wells: Array[Node2D] = []

func setup(ship: PlayerShip) -> void:
	player = ship
	player.position = Vector2(-1350,-450)
	player.velocity = Vector2.ZERO
	player.collision_mask |= 16
	_previous = player.position
	for rect in rocks + [Rect2(-1600,-900,3200,30), Rect2(-1600,870,3200,30), Rect2(-1600,-900,30,1800), Rect2(1570,-900,30,1800)]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 16
		wall.collision_mask = 1
		wall.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		wall.add_child(shape)
		add_child(wall)
	for point in [Vector2(1100,430), Vector2(-1000,250)]:
		var well = load("res://src/world/gravity_well.gd").new()
		well.position = point
		add_child(well)
		wells.append(well)
	player.gravity_sources.assign(wells)

func tick(delta: float) -> void:
	if not active or player.is_dead:
		return
	clock += delta
	if clock > 150:
		active = false
		failed.emit()
		return
	_impact_cooldown = maxf(0, _impact_cooldown - delta)
	if player.get_slide_collision_count() > 0 and maxf(_last_speed, player.velocity.length()) > 45 and _impact_cooldown <= 0:
		bumps += 1
		_impact_cooldown = 1.0
		player.take_damage(7)
	if not courier_arrived:
		var travel := 115 * delta
		while travel > 0 and not courier_arrived:
			var distance := courier_position.distance_to(gates[courier_gate])
			if travel >= distance:
				travel -= distance
				courier_position = gates[courier_gate]
				courier_gate += 1
				courier_arrived = courier_gate == gates.size()
			else:
				courier_position = courier_position.move_toward(gates[courier_gate], travel)
				travel = 0
	var motion := player.position - _previous
	if next_gate < gates.size() and motion.length() <= 100 and motion.length() > 0.01:
		var target := gates[next_gate]
		var incoming := (target - (gates[next_gate-1] if next_gate > 0 else Vector2(-1350,-450))).normalized()
		var nearest := Geometry2D.get_closest_point_to_segment(target, _previous, player.position)
		if nearest.distance_to(target) <= 72 and motion.dot(incoming) > 0:
			next_gate += 1
			if next_gate == gates.size():
				active = false
				completed.emit({"courier_escaped": courier_arrived, "time": clock, "bumps": bumps, "gates": next_gate})
	_previous = player.position
	_last_speed = player.velocity.length()
	if clock >= 150 and active:
		active = false
		failed.emit()
	queue_redraw()

func snapshot() -> Dictionary:
	return {"gates": next_gate, "total": gates.size(), "time": clock, "bumps": bumps,
		"courier_escaped": courier_arrived,
		"text": "INTERCEPT / GATE %d OF %d / COURIER %d / %.0fs LEFT" % [mini(next_gate+1,gates.size()),gates.size(),mini(courier_gate+1,gates.size()),maxf(0,150-clock)]}

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for rect in rocks:
		draw_rect(rect, Color("182832"))
		draw_rect(rect, AMBER, false, 2)
		draw_line(rect.position, rect.end, Color("45535a"), 2)
	for i in gates.size():
		var color := CYAN if i == next_gate else (Color("315954") if i < next_gate else Color("596875"))
		draw_arc(gates[i],72,0,TAU,40,color,2,true)
		draw_string(font,gates[i]+Vector2(-35,-85),"GATE %02d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,110,12,color)
		if i > 0:
			draw_dashed_line(gates[i-1],gates[i],Color(color,0.18),1,16)
	draw_colored_polygon(PackedVector2Array([courier_position+Vector2(20,0),courier_position+Vector2(-14,-12),courier_position+Vector2(-14,12)]),AMBER)
	draw_string(font,courier_position+Vector2(-45,-25),"RELAY COURIER",HORIZONTAL_ALIGNMENT_LEFT,120,11,AMBER)
	if is_instance_valid(player) and next_gate < gates.size():
		var direction := player.position.direction_to(gates[next_gate])
		var tip := player.position + direction*105
		draw_line(player.position+direction*55,tip,CYAN,3,true)
		draw_polyline(PackedVector2Array([tip-direction*14+direction.orthogonal()*9,tip,tip-direction*14-direction.orthogonal()*9]),CYAN,2,true)
		draw_string(font,player.position+Vector2(-45,75),"%du / NEXT GATE" % player.position.distance_to(gates[next_gate]),HORIZONTAL_ALIGNMENT_LEFT,150,11,CYAN)
