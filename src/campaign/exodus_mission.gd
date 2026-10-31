extends "res://src/campaign/tactical_arena.gd"

var gates: Array[Vector2]=[Vector2(-4300,2600),Vector2(-4300,-2600),Vector2(-2500,-2600),Vector2(-2500,2600),Vector2(-700,2600),Vector2(-700,-2600),Vector2(1200,-2600),Vector2(1200,2600),Vector2(3000,2600),Vector2(3000,-2600),Vector2(4400,-2600),Vector2(4400,1600)]
var next_gate := 1
var locks: Dictionary={}
var triggered: Dictionary={}
var front := Vector2(-4300,2600)
var front_gate := 1
var bumps := 0
var _previous := Vector2.ZERO
var _impact_left := 0.0
var _front_left := 0.0
var _last_speed := 0.0

func setup(ship: PlayerShip, _flags: Dictionary={}) -> void:
	bounds=Rect2(-5000,-3500,10000,7000)
	for i in range(5):
		var x: float=[-3400,-1700,200,2100,3650][i]
		walls.append(Rect2(x-35,-1800 if i%2==0 else -3500,70,5300))
		var y := -2600 if i%2==0 else 2600
		doors.append(Vector2(x-180,y))
		doors.append(Vector2(x+180,y))
	begin(ship,gates[0])
	_previous=player.position
	for x in [-3950,-2150,-350,1550,3350]:
		var well=load("res://src/world/gravity_well.gd").new()
		well.position=Vector2(x,700)
		well.field_radius=650
		well.peak_acceleration=160
		add_child(well)
		player.gravity_sources.append(well)

func _lock(index: int) -> void:
	if triggered.has(index): return
	triggered[index]=true
	var jammer=load("res://src/actors/substrate_agent.gd").new()
	jammer.role="relay"
	jammer.task="JAMMER / GATE LOCK"
	jammer.configure(&"bit",gates[index],{"health":180,"speed":0,"simulation_enabled":false,"xp":3})
	jammer.combat_geometry.assign(walls)
	add_child(jammer)
	actors.append(jammer)
	locks[index]=weakref(jammer)
	enemy_spawned.emit(jammer)
	spawn_guard(gates[index]+Vector2(-280,-220),"anchor",index)
	spawn_guard(gates[index]+Vector2(280,220),"flanker",index)
	message.emit("EXODUS / GATE JAMMED / DESTROY THE RELAY / KEEP MOVING")

func locked(index: int) -> bool:
	return locks.has(index) and living(locks[index].get_ref())

func goal() -> Vector2:
	if next_gate>=gates.size(): return gates.back()
	if locked(next_gate): return gates[next_gate]
	var incoming := gates[next_gate-1].direction_to(gates[next_gate])
	return gates[next_gate]+incoming*140

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	if next_gate in [3,6,9] and player.position.distance_to(gates[next_gate])<1250: _lock(next_gate)
	_impact_left=maxf(0,_impact_left-delta)
	_front_left=maxf(0,_front_left-delta)
	if player.get_slide_collision_count()>0 and maxf(_last_speed,player.velocity.length())>45 and _impact_left<=0:
		bumps+=1
		_impact_left=1
		player.take_damage(8)
	if clock>20:
		var travel := 145*delta
		while front_gate<gates.size() and travel>0:
			var distance := front.distance_to(gates[front_gate])
			if travel>=distance:
				front=gates[front_gate]
				travel-=distance
				front_gate+=1
			else:
				front=front.move_toward(gates[front_gate],travel)
				travel=0
		if player.position.distance_to(front)<240 and _front_left<=0:
			player.take_damage(16,front)
			_front_left=1
	var motion := player.position-_previous
	if next_gate<gates.size() and motion.length()<=140 and motion.length()>0.01 and not locked(next_gate):
		var nearest := Geometry2D.get_closest_point_to_segment(gates[next_gate],_previous,player.position)
		var incoming := gates[next_gate-1].direction_to(gates[next_gate])
		if nearest.distance_to(gates[next_gate])<120 and motion.dot(incoming)>0:
			next_gate+=1
			message.emit("EXODUS / GATE %d OF 11 / HULL %.0f" % [next_gate-1,player.hull])
	_previous=player.position
	_last_speed=player.velocity.length()
	tick_tactics(delta)
	if next_gate>=gates.size():
		active=false
		completed.emit({"escaped":true,"gates":11,"bumps":bumps,"time":clock})
	elif clock>=300:
		failure_reason="The receiver sealed before the ship reached it. Retry begins at the escape checkpoint."
		active=false
		failed.emit()
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text":"EXODUS / GATE %d OF 11 / %s / RECEIVER %.0fs / COLLAPSE %du BEHIND" % [mini(next_gate,11),"DESTROY JAMMER" if locked(next_gate) else "PASS FORWARD THROUGH RING",maxf(0,300-clock),player.position.distance_to(front)],"next":next_gate,"bumps":bumps}

func _draw() -> void:
	super._draw()
	for i in range(1,gates.size()):
		draw_dashed_line(gates[i-1],gates[i],Color("244b55"),2,28)
		draw_ring(gates[i],"GATE %d / %s" % [i,"JAMMED" if locked(i) else ("NEXT" if i==next_gate else "")],Color("ffc36b") if locked(i) else (Color("68f7e5") if i==next_gate else Color("395b63")))
	if clock>20:
		draw_circle(front,240,Color("ff657b",0.07))
		draw_arc(front,240,0,TAU,64,Color("ff657b"),3,true)
		draw_string(ThemeDB.fallback_font,front+Vector2(-90,-270),"COLLAPSE FRONT / KEEP AHEAD",HORIZONTAL_ALIGNMENT_LEFT,320,14,Color("ff657b"))
