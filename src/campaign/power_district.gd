extends "res://src/campaign/tactical_arena.gd"

var feeders: Array[Vector2]=[Vector2(-2400,-1500),Vector2(0,-1500),Vector2(2400,-1500)]
var sockets: Array[Vector2]=[Vector2(2400,1500),Vector2(-2400,1500),Vector2(0,1500)]
var bus := Vector2(0,2150)
var exit_position := Vector2(-3000,2100)
var circuits := [0,0,0] # 0 cell at feeder, 1 carried, 2 socket live, 3 bus confirmed
var triggered: Dictionary={}
var carried := -1
var progress := 0.0
var interaction := ""
var _pulse_cycle := -1

func setup(ship: PlayerShip, _flags: Dictionary={}) -> void:
	room_grid()
	begin(ship,exit_position)

func _activate(point: Vector2, id: int) -> void:
	if triggered.has(id) or player.position.distance_to(point)>1050 or live_count()>5: return
	triggered[id]=true
	spawn_guard(point+Vector2(-400,-200),"anchor",id)
	spawn_guard(point+Vector2(400,200),"flanker",id)
	spawn_guard(point+Vector2(0,460),"scout",id)
	message.emit("CIRCUIT %d / %s DETAIL ACTIVE" % [id%3+1,"FEEDER" if id<3 else "CONVERTER"])

func goal() -> Vector2:
	if carried>=0: return sockets[carried]
	if circuits.has(2): return bus
	var distance := INF
	var result := exit_position
	for i in circuits.size():
		if circuits[i]==0 and player.position.distance_to(feeders[i])<distance:
			distance=player.position.distance_to(feeders[i])
			result=feeders[i]
	return result

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	for i in range(3):
		if circuits[i]==0: _activate(feeders[i],i)
		if circuits[i]==1: _activate(sockets[i],i+3)
	var key := ""
	for i in range(3):
		if circuits[i]==0 and carried<0 and triggered.has(i) and not contested(feeders[i]) and coast_at(feeders[i]): key="cell_%d" % i
		if circuits[i]==1 and triggered.has(i+3) and not contested(sockets[i]) and coast_at(sockets[i]): key="socket_%d" % i
	if circuits.has(2) and coast_at(bus): key="bus"
	if key!=interaction: progress=0; interaction=key
	if not key.is_empty():
		progress+=delta
		if progress>=1.5:
			if key=="bus":
				for i in circuits.size():
					if circuits[i]==2: circuits[i]=3
				message.emit("BUS SYNC / %d OF 3 CIRCUITS CONFIRMED / CONVOY CAPACITY RESTORED" % circuits.count(3))
			elif key.begins_with("cell"):
				carried=int(key.get_slice("_",1))
				circuits[carried]=1
				message.emit("CELL %d LOADED / MATCH ITS CONVERTER / REACTOR LOAD +8 HEAT PER SECOND" % (carried+1))
			else:
				circuits[carried]=2
				carried=-1
				message.emit("CONVERTER LIVE / CONFIRM AT THE SOUTH CENTRAL BUS")
			progress=0
			interaction=""
	if carried>=0: player.add_heat(8*delta)
	tick_tactics(delta)
	# Powered converters pulse once per seven seconds, with a full warning.
	var cycle := floori(clock/7)
	if cycle!=_pulse_cycle:
		if _pulse_cycle>=0:
			for i in range(3):
				if circuits[i]>=2 and player.position.distance_to(sockets[i])<230 and CombatGeometry.clear(sockets[i],player.position,walls): player.take_damage(12,sockets[i])
		_pulse_cycle=cycle
	if circuits.count(3)==3 and player.position.distance_to(exit_position)<120:
		active=false
		completed.emit({"power_circuits":3,"time":clock})
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text":"POWER DISTRICT / BUS %d OF 3 / %s / COAST 1.5s TO TRANSFER / SOLID DOORWAYS" % [circuits.count(3),"CELL %d -> CONVERTER %d" % [carried+1,carried+1] if carried>=0 else ("CONFIRM AT SOUTH BUS" if circuits.has(2) else "RECOVER A NORTH FEEDER CELL")],"circuits":circuits.duplicate(),"carried":carried}

func _draw() -> void:
	super._draw()
	var colors := [Color("68f7e5"),Color("ffc36b"),Color("b5a0ff")]
	for i in range(3):
		var color: Color=colors[i]
		draw_ring(feeders[i],"FEEDER %d / %s" % [i+1,"EMPTY" if circuits[i]>0 else "RECOVER CELL"],color,progress/1.5 if interaction=="cell_%d" % i else 0)
		draw_ring(sockets[i],"CONVERTER %d / %s" % [i+1,"LIVE" if circuits[i]>=2 else "CELL REQUIRED"],color,progress/1.5 if interaction=="socket_%d" % i else 0)
		if circuits[i]>=2:
			var warning := fmod(clock,7)>5.5
			draw_arc(sockets[i],230,0,TAU,64,Color("ff657b") if warning else Color(color,0.16),3 if warning else 1,true)
			if warning: draw_string(ThemeDB.fallback_font,sockets[i]+Vector2(-75,145),"DISCHARGE / LEAVE RING",HORIZONTAL_ALIGNMENT_LEFT,260,12,Color("ff657b"))
	draw_ring(bus,"SOUTH BUS / CONFIRM CIRCUITS",Color("8bdfa4"),progress/1.5 if interaction=="bus" else 0)
	draw_ring(exit_position,"EXIT / POWER 3 CIRCUITS",Color("68f7e5"))
	if carried>=0:
		var cargo := player.position-Vector2.RIGHT.rotated(player.rotation)*55
		draw_line(player.position,cargo,colors[carried],2,true)
		draw_circle(cargo,9,colors[carried])
		draw_string(ThemeDB.fallback_font,cargo+Vector2(-35,28),"CELL %d" % (carried+1),HORIZONTAL_ALIGNMENT_LEFT,100,12,colors[carried])
