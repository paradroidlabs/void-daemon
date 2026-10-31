extends Node2D

signal completed
signal message(text: String)
var player: PlayerShip
var actors: Array[Enemy] = []
var beacons: Array[Vector2] = [Vector2(-1050,-430),Vector2(1050,-430),Vector2(0,560)]
var secured := [false,false,false]
var progress := [0.0,0.0,0.0]
var exit_position := Vector2(0,-650)
var active := true

func setup(ship: PlayerShip, reinforced: bool) -> void:
	player=ship
	player.position=Vector2(-1100,500)
	player.velocity=Vector2.ZERO
	for point in beacons:
		_spawn(&"sentry",point+Vector2(-120,80),0)
		_spawn(&"vector",point+Vector2(120,-80),80)
	if reinforced:
		_spawn(&"vector",Vector2(-300,0),95)
		_spawn(&"sentry",Vector2(300,0),65)

func _spawn(kind: StringName, point: Vector2, speed: float) -> void:
	var actor := Enemy.new()
	actor.configure(kind,point,{"health":100,"speed":speed,"charge_windup":1.0,"shot_windup":1.0,"shot_interval":2.7},player)
	add_child(actor)
	actor.add_to_group("enemy_normal")
	actors.append(actor)

func living(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_alive()

func remaining() -> int:
	var count := 0
	for actor in actors:
		if living(actor): count+=1
	return count

func goal() -> Vector2:
	var best := exit_position
	var distance := INF
	for i in beacons.size():
		if not secured[i] and player.position.distance_to(beacons[i])<distance:
			best=beacons[i]
			distance=player.position.distance_to(beacons[i])
	return best

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	for i in beacons.size():
		if secured[i]: continue
		var contested := false
		for actor in actors:
			if living(actor) and actor.position.distance_to(beacons[i])<360:
				contested=true
				break
		if not contested and player.position.distance_to(beacons[i])<95 and player.velocity.length()<85:
			progress[i]+=delta
			if progress[i]>=1.5:
				secured[i]=true
				message.emit("PICKET POSITION SECURED / %d OF 3" % secured.count(true))
		else: progress[i]=maxf(0,progress[i]-delta)
	if secured.count(true)==3 and remaining()==0 and player.position.distance_to(exit_position)<100:
		active=false
		completed.emit()
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text":"PICKET / POSITIONS %d OF 3 / HOSTILES %d / COAST IN CLEARED RINGS / EXTRACT NORTH" % [secured.count(true),remaining()]}

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in beacons.size():
		var color := Color("8bdfa4") if secured[i] else Color("ffc36b")
		draw_arc(beacons[i],95,0,TAU,48,color,2,true)
		draw_string(font,beacons[i]+Vector2(-80,-115),"POSITION %d / %s" % [i+1,"SECURED" if secured[i] else "CLEAR + COAST"],HORIZONTAL_ALIGNMENT_LEFT,240,12,color)
	var cyan := Color("68f7e5")
	draw_arc(exit_position,100,0,TAU,48,cyan if secured.count(true)==3 else Color("47606a"),2,true)
	draw_string(font,exit_position+Vector2(-70,-120),"EXTRACT / NORTH",HORIZONTAL_ALIGNMENT_LEFT,220,12,cyan)
	if is_instance_valid(player):
		var direction := player.position.direction_to(goal())
		draw_line(player.position+direction*55,player.position+direction*105,cyan,3,true)
