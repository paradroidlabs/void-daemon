extends Node2D

signal completed(result: Dictionary)
signal message(text: String)
var player: PlayerShip
var walls: Array[Rect2] = [Rect2(-1340,-740,2680,60), Rect2(-1340,680,2680,60), Rect2(-1340,-740,60,1480), Rect2(1280,-740,60,1480), Rect2(-40,-740,80,560), Rect2(-40,180,80,560), Rect2(-1340,-40,640,80), Rect2(-430,-40,860,80), Rect2(700,-40,640,80)]
var actors: Array[Enemy] = []
var cores: Array[Enemy] = []
var archive := Vector2(980,430)
var exit_position := Vector2(-1100,500)
var archive_progress := 0.0
var recovered := false
var active := true
var clock := 0.0
var _pulse_cycle := -1
var doors: Array[Vector2] = [Vector2(-565,100),Vector2(-565,-100),Vector2(565,100),Vector2(565,-100),Vector2(-150,-100),Vector2(150,-100),Vector2(-150,100),Vector2(150,100)]
var _navigation_left := 0.0
var _waypoint := Vector2.ZERO

func setup(ship: PlayerShip) -> void:
	player = ship
	player.position = exit_position
	player.velocity = Vector2.ZERO
	player.collision_mask |= 16
	player.combat_geometry.assign(walls)
	for rect in walls:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 16
		body.collision_mask = 1
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	for side in [-1,1]:
		var core = load("res://src/actors/substrate_agent.gd").new()
		core.role = "relay"
		core.task = "COOLANT / DESTROY"
		core.configure(&"bit",Vector2(side*1000,-440),{"health":180,"speed":0,"xp":3})
		add_child(core)
		core.add_to_group("enemy_normal")
		cores.append(core)
		actors.append(core)
		for i in range(3):
			var guard := Enemy.new()
			guard.configure(&"sentry" if i < 2 else &"vector",Vector2(side*(740+i*130),-180-i*100),{"health":75 if i < 2 else 105,"speed":0 if i < 2 else 80,"shot_windup":1.0,"shot_interval":2.8,"charge_windup":1.0},player)
			guard.combat_geometry.assign(walls)
			add_child(guard)
			guard.add_to_group("enemy_normal")
			actors.append(guard)

func live(core) -> bool:
	return is_instance_valid(core) and not core.is_queued_for_deletion() and core.is_alive()

func remaining() -> int:
	var count := 0
	for core in cores:
		if live(core): count += 1
	return count

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	clock += delta
	_navigation_left -= delta
	if _navigation_left <= 0:
		_navigation_left = 0.25
		_waypoint = CombatGeometry.waypoint(player.position,objective_position(),walls,doors)
	var cycle := floori(clock/6)
	if cycle != _pulse_cycle:
		_pulse_cycle = cycle
		if cycle > 0:
			for core in cores:
				if live(core) and core.position.distance_to(player.position) < 190 and CombatGeometry.clear(core.position,player.position,walls):
					player.take_damage(12,core.position)
	if remaining() == 0 and not recovered:
		if player.position.distance_to(archive) < 85 and player.velocity.length() < 80:
			archive_progress += delta
			if archive_progress >= 3:
				recovered = true
				message.emit("ARCHIVE RECOVERED / RETURN TO THE CYAN EXIT")
		else:
			archive_progress = maxf(0,archive_progress-delta*0.5)
	if recovered and player.position.distance_to(exit_position) < 85:
		active = false
		completed.emit({"archive_recovered":true,"cores":2,"time":clock})
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text": "FACILITY / COOLANT CORES %d / ARCHIVE %s / EXTRACT %s" % [remaining(),"SECURED" if recovered else "%.0f%%" % (archive_progress/3*100),"READY" if recovered else "LOCKED"],"remaining":remaining(),"archive_recovered":recovered}

func objective_position() -> Vector2:
	if recovered: return exit_position
	for core in cores:
		if live(core): return core.position
	return archive

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for wall in walls:
		draw_rect(wall,Color("152b36"))
		draw_rect(wall,Color("85aebc"),false,2)
	for core in cores:
		if live(core):
			var warning := fmod(clock,6) >= 5
			draw_arc(core.position,190,0,TAU,48,Color("ffc36b") if warning else Color(0.6,0.3,0.1,0.25),3 if warning else 1,true)
			if warning: draw_string(font,core.position+Vector2(-70,65),"COOLANT DISCHARGE",HORIZONTAL_ALIGNMENT_LEFT,170,12,Color("ffc36b"))
	var cyan := Color("68f7e5")
	draw_arc(archive,85,0,TAU,40,cyan if remaining()==0 else Color("53646b"),2,true)
	draw_string(font,archive+Vector2(-100,-100),"ARCHIVE / COAST TO TRANSFER",HORIZONTAL_ALIGNMENT_LEFT,240,12,cyan)
	draw_arc(exit_position,85,0,TAU,40,cyan if recovered else Color("53646b"),2,true)
	draw_string(font,exit_position+Vector2(-70,-105),"EXTRACT / HOME",HORIZONTAL_ALIGNMENT_LEFT,180,12,cyan)
	if is_instance_valid(player):
		var direction := player.position.direction_to(_waypoint)
		draw_line(player.position+direction*50,player.position+direction*105,cyan,3,true)
		draw_string(font,player.position+Vector2(-60,75),"ROUTE / OPEN DOORWAYS",HORIZONTAL_ALIGNMENT_LEFT,200,11,cyan)
