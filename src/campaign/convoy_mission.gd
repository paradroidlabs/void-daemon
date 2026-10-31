extends "res://src/campaign/tactical_arena.gd"

const Carrier := preload("res://src/campaign/archive_carrier.gd")
var convoy: Area2D
var route: Array[Vector2]=[Vector2(-2800,1800),Vector2(-2800,-1800),Vector2(-1000,-1800),Vector2(-1000,1800),Vector2(1000,1800),Vector2(1000,-1800),Vector2(2800,-1800),Vector2(2800,1800)]
var next_point := 1
var triggered: Dictionary={}
var repair_position := Vector2(0,2150)
var repaired := false
var repair_progress := 0.0
var hold_reason := ""
var detail_size := 3

func setup(ship: PlayerShip, flags: Dictionary={}) -> void:
	bounds=Rect2(-3500,-2500,7000,5000)
	walls=[Rect2(-1930,-1300,60,3800),Rect2(-30,-2500,60,3800),Rect2(1870,-1300,60,3800)]
	doors=[Vector2(-2050,-1800),Vector2(-1750,-1800),Vector2(-150,1800),Vector2(150,1800),Vector2(1750,-1800),Vector2(2050,-1800)]
	begin(ship,route[0]+Vector2(140,0))
	convoy=Carrier.new()
	convoy.position=route[0]
	convoy.label="THE THREE VOICES"
	convoy.status="WAITING"
	convoy.max_health=300+50*clampi(int(flags.get("power_circuits",0)),0,3)
	if flags.get("departure_room_choice","")=="linked":
		convoy.max_health+=60
		detail_size=4
	convoy.health=convoy.max_health
	add_child(convoy)
	for point in [Vector2(-2450,0),Vector2(650,0)]:
		var well=load("res://src/world/gravity_well.gd").new()
		well.position=point
		well.field_radius=600
		well.peak_acceleration=120
		add_child(well)
		player.gravity_sources.append(well)

func _detail(index: int) -> void:
	if triggered.has(index) or live_count()>5: return
	triggered[index]=true
	var point: Vector2=route[index]
	for i in range(detail_size):
		var actor := spawn_guard(point+Vector2(-280+(i%3)*280,-280 if i%2==0 else 280),"anchor" if i==0 else "flanker",index)
		if actor!=null:
			actor.contact_hit.connect(func(_enemy, receiver, amount):
				if receiver==convoy and living(convoy): convoy.take_damage(amount)
			)
	message.emit("CONVOY / CHECKPOINT %d DETAIL / PROTECT THE VOICES" % index)

func target_for(actor: Enemy) -> Node2D:
	# Hunters may attack the ship if close, otherwise only a convoy they can see.
	if actor.position.distance_to(player.position)<260 and CombatGeometry.clear(actor.position,player.position,walls): return player
	return convoy

func goal() -> Vector2:
	if next_point>=route.size():
		for actor in actors:
			if living(actor): return actor.position
		return route.back()
	for actor in actors:
		if living(actor) and actor.position.distance_to(convoy.position)<1100:
			return actor.position
	return convoy.position+convoy.position.direction_to(route[next_point])*180

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	if not convoy.is_alive():
		failure_reason="The shared archive transport was destroyed. Retry preserves the entry checkpoint."
		active=false
		failed.emit()
		return
	if next_point<route.size():
		if convoy.position.distance_to(route[next_point])<1100: _detail(next_point)
		var blocked := false
		for actor in actors:
			if living(actor) and actor.position.distance_to(convoy.position)<600 and CombatGeometry.clear(actor.position,convoy.position,walls): blocked=true; break
		hold_reason="CLEAR NEARBY HUNTERS" if blocked else ("RETURN WITHIN 700u" if player.position.distance_to(convoy.position)>700 else "")
		convoy.status="HOLD" if not hold_reason.is_empty() else "MOVING"
		if hold_reason.is_empty():
			# Never cross an unactivated checkpoint during one oversized tick.
			var travel := 145*delta
			while next_point<route.size() and travel>0:
				var distance: float=convoy.position.distance_to(route[next_point])
				if travel<distance:
					convoy.position=convoy.position.move_toward(route[next_point],travel)
					break
				convoy.position=route[next_point]
				travel-=distance
				next_point+=1
				if next_point<route.size(): break # next checkpoint must activate its own detail
	else: convoy.status="ARRIVED"
	if not repaired and coast_at(repair_position) and convoy.position.distance_to(repair_position)<600:
		repair_progress+=delta
		if repair_progress>=1.5:
			repaired=true
			convoy.health=minf(convoy.max_health,convoy.health+60)
			message.emit("ONE-USE FIELD SERVICE / TRANSPORT +60 HULL (CAPPED)")
	else: repair_progress=maxf(0,repair_progress-delta)
	tick_tactics(delta)
	if next_point>=route.size() and live_count()==0 and player.position.distance_to(route.back())<300:
		active=false
		completed.emit({"convoy_hull":convoy.health,"convoy_repaired":repaired,"time":clock})
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text":"CONVOY / CHECKPOINT %d OF 7 / TRANSPORT %.0f OF %.0f / %s" % [mini(next_point,7),convoy.health,convoy.max_health,hold_reason if not hold_reason.is_empty() else "ESCORT / STAY WITHIN 700u"],"next":next_point,"hull":convoy.health}

func _draw() -> void:
	super._draw()
	for i in range(1,route.size()):
		draw_dashed_line(route[i-1],route[i],Color("244b55"),2,24)
		draw_ring(route[i],"CHECKPOINT %d" % i,Color("8bdfa4") if next_point>i else Color("68f7e5"))
	draw_ring(repair_position,"FIELD SERVICE / %s" % ("USED" if repaired else "+60 TRANSPORT HULL"),Color("8bdfa4"),repair_progress/1.5)
	if is_instance_valid(convoy):
		draw_arc(convoy.position,700,0,TAU,64,Color("68f7e5",0.08),1,true)
		if is_instance_valid(player) and player.position.distance_to(convoy.position)>500:
			draw_dashed_line(player.position,convoy.position,Color("ffc36b"),2,14)
