extends Node2D

signal completed(result: Dictionary)
signal enemy_spawned(actor: Enemy)
signal message(text: String)
const BOUNDS := Rect2(-4100,-3600,8200,7200)
var player: PlayerShip
var sites: Array[Dictionary] = []
var actors: Array[Enemy] = []
var clock := 0.0
var active := true
var carried := -1
var repairs := 0
var delivered := 0
var base := Vector2(0,3000)
var walls: Array[Rect2]=[]
var doors: Array[Vector2]=[]
var _waypoint := Vector2.ZERO
var _think := 0.0
var _reports: Array[Dictionary] = []
var _shared := Vector2.ZERO
var _shared_velocity := Vector2.ZERO
var _shared_at := -100.0
var _shared_site := -1
var _next_report := 0.0
var memory := SubstrateMemory.new()
var doctrine := -1
var received_reports := 0
var prevented_reports := 0

func setup(ship: PlayerShip, seed_value: int) -> void:
	player=ship
	player.position=base
	player.velocity=Vector2.ZERO
	player.arena_bounds=BOUNDS
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var kinds := ["relay","survey","salvage","survey","salvage","relay","salvage","relay","survey"]
	for i in range(9):
		var point := Vector2((i%3-1)*2600,(i/3-1)*2200)+Vector2(rng.randf_range(-150,150),rng.randf_range(-150,150))
		sites.append({"id":i,"position":point,"kind":kinds[i],"active":false,"done":false,"progress":0.0,"actors":[],"core":null,"collected":false})
		var well=load("res://src/world/gravity_well.gd").new()
		well.position=point+Vector2(700,600)
		well.field_radius=900
		well.peak_acceleration=140
		add_child(well)
		player.gravity_sources.append(well)
		# Open-sided dock shells give ranged defenders real cover. Both ends
		# remain traversable; no enemy can shoot or see through these solids.
		if kinds[i]!="relay":
			for local_rect in [Rect2(-450,-420,900,55),Rect2(-450,365,900,55)]:
				walls.append(Rect2(point+local_rect.position,local_rect.size))
			for corner in [Vector2(-510,-480),Vector2(510,-480),Vector2(-510,0),Vector2(510,0),Vector2(-510,480),Vector2(510,480)]:
				doors.append(point+corner)
	player.combat_geometry.assign(walls)
	player.collision_mask |= 16
	for rect in walls:
		var body := StaticBody2D.new()
		body.position=rect.get_center()
		body.collision_layer=16
		body.collision_mask=1
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size=rect.size
		collision.shape=shape
		body.add_child(collision)
		add_child(body)

func living(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_alive()

func live_count() -> int:
	var result := 0
	for actor in actors:
		if living(actor): result+=1
	return result

func secured_count() -> int:
	var result := 0
	for site in sites:
		if site["done"]: result+=1
	return result

func goal() -> Vector2:
	if carried>=0 or secured_count()==sites.size(): return base
	var best := base
	var distance := INF
	for site in sites:
		if not site["done"] and not site["collected"] and player.position.distance_to(site["position"])<distance:
			distance=player.position.distance_to(site["position"])
			best=site["position"]
	return best

func _activate(site: Dictionary) -> void:
	if live_count()>4: return
	site["active"]=true
	var point: Vector2=site["position"]
	for i in range(3):
		var actor=load("res://src/actors/substrate_agent.gd").new()
		actor.role=["scout","anchor","flanker"][i]
		actor.stable_id="site_%d_%d" % [site["id"],i]
		actor.configure([&"bit",&"sentry",&"vector"][i],point+Vector2.RIGHT.rotated(i*TAU/3)*320,{"health":100,"speed":120 if i!=1 else 0,"charge_windup":1.0,"shot_windup":1.0,"xp":2})
		actor.combat_geometry.assign(walls)
		actor.set_meta("home",actor.position)
		actor.set_meta("site_id",int(site["id"]))
		add_child(actor)
		actor.add_to_group("enemy_normal")
		actors.append(actor)
		site["actors"].append(actor)
		enemy_spawned.emit(actor)
	if site["kind"]=="relay":
		var core=load("res://src/actors/substrate_agent.gd").new()
		core.role="relay"
		core.set_meta("site_id",int(site["id"]))
		core.task="NETWORK / DESTROY"
		core.configure(&"bit",point,{"health":180,"speed":0,"xp":3})
		core.combat_geometry.assign(walls)
		add_child(core)
		core.add_to_group("enemy_normal")
		actors.append(core)
		site["core"]=weakref(core)
		enemy_spawned.emit(core)
	message.emit("SITE %d / %s / LOCAL DEFENSE ACTIVE" % [int(site["id"])+1,str(site["kind"]).to_upper()])

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	clock+=delta
	if carried>=0 and player.position.distance_to(base)<150:
		sites[carried]["done"]=true
		carried=-1
		delivered+=1
		message.emit("CARGO BANKED / NETWORK RECORD %d OF 3" % delivered)
	for site in sites:
		if site["done"]: continue
		var distance: float=player.position.distance_to(site["position"])
		if not site["active"] and distance<950: _activate(site)
		if not site["active"]: continue
		if site["kind"]=="relay":
			var core=site["core"].get_ref()
			if not living(core):
				site["done"]=true
				message.emit("RELAY DISCONNECTED / REMAINING GUARDS HAVE ONLY LOCAL SENSES")
		else:
			var contested := false
			for actor in site["actors"]:
				if living(actor): contested=true; break
			if not contested and distance<100 and player.velocity.length()<85 and not site["collected"]:
				site["progress"]+=delta
				if float(site["progress"])>=2:
					if site["kind"]=="salvage" and carried<0:
						site["collected"]=true
						carried=int(site["id"])
						message.emit("RECORD RECOVERED / ONE CARGO SLOT / RETURN TO CENTRAL CRADLE")
					elif site["kind"]=="survey":
						site["done"]=true
						player.heal_hull(20)
						repairs+=1
						message.emit("SURVEY SECURED / FIELD REPAIR +20 HULL (CAPPED)")
			else: site["progress"]=maxf(0,float(site["progress"])-delta)
	_think-=delta
	if _think<=0:
		_think=0.2
		_think_agents()
		_waypoint=CombatGeometry.waypoint(player.position,goal(),walls,doors)
	if secured_count()==sites.size() and carried<0 and player.position.distance_to(base)<150:
		active=false
		completed.emit({"spine_sites":secured_count(),"records_delivered":delivered,"repairs":repairs,"reports":received_reports,"time":clock})
	queue_redraw()

func connected(site_id: int) -> bool:
	if site_id<0 or site_id>=sites.size(): return false
	var site: Dictionary=sites[site_id]
	if site["done"]: return false
	if site["kind"]=="relay":
		return site["core"]!=null and living(site["core"].get_ref())
	return true

func _think_agents() -> void:
	for i in range(_reports.size()-1,-1,-1):
		var report: Dictionary=_reports[i]
		if not living(report["source"].get_ref()) or not connected(int(report["site"])):
			prevented_reports+=1
			_reports.remove_at(i)
		elif clock>=float(report["due"]):
			_shared=report["position"]
			_shared_velocity=report["velocity"]
			_shared_at=float(report["time"])
			_shared_site=int(report["site"])
			memory.observe(_shared_velocity,_shared_at)
			received_reports+=1
			_reports.remove_at(i)
	memory.advance(clock)
	if memory.heading_bin>=0 and memory.heading_bin!=doctrine:
		doctrine=memory.heading_bin
		message.emit("SUBSTRATE / TRAVEL HYPOTHESIS UPDATED / INTERCEPT RESPONSE AVAILABLE")
	for actor in actors:
		if not living(actor) or actor.role=="relay": continue
		var visible: bool=actor.position.distance_to(player.position)<720 and CombatGeometry.clear(actor.position,player.position,walls)
		var online := connected(int(actor.get_meta("site_id",-1)))
		if visible and online and actor.role=="scout" and clock>=_next_report:
			_reports.append({"source":weakref(actor),"site":actor.get_meta("site_id"),"position":player.position,"velocity":player.velocity,"time":clock,"due":clock+1.25})
			_next_report=clock+1.5
		var shared: bool=online and connected(_shared_site) and clock-_shared_at<2.5 and actor.position.distance_to(_shared)<650
		if visible or shared:
			var point: Vector2=player.position if visible else _shared
			if actor.role=="flanker":
				actor.charge_trigger_range=260
				if shared and doctrine>=0: point=_shared+Vector2.RIGHT.rotated(doctrine*TAU/8)*minf(180,_shared_velocity.length()*0.65)
			# Mobile units route around cover; anchors hold a firing lane.
			actor.set_target_position(CombatGeometry.waypoint(actor.position,point,walls,doors) if actor.role!="anchor" else point)
			actor.task="CONTACT / LOCAL" if visible else "CONTACT / REPORT"
		else:
			actor.task="GUARD / SEARCH"
			actor.charge_trigger_range=0
			var home: Vector2=actor.get_meta("home",actor.position)
			if actor.role=="anchor" or actor.position.distance_to(home)<30: actor.clear_target()
			else: actor.set_target_position(CombatGeometry.waypoint(actor.position,home,walls,doors))

func snapshot() -> Dictionary:
	var pins: Array[Dictionary]=[]
	for site in sites: pins.append({"id":site["id"],"position":site["position"],"kind":site["kind"],"done":site["done"],"active":site["active"],"collected":site["collected"]})
	return {"text":"MEMORY SPINE / SITES %d OF 9 / CARGO %s / LIVE THREATS %d / REPORTS %d" % [secured_count(),"RETURN TO BASE" if carried>=0 else "EMPTY",live_count(),received_reports],"sites":pins,"bounds":BOUNDS,"player":player.position,"base":base,"secured":secured_count(),"delivered":delivered}

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var cyan := Color("68f7e5")
	for rect in walls:
		draw_rect(rect,Color("142932"))
		draw_rect(rect,Color("4c7782"),false,2)
	for report in _reports:
		var source=report["source"].get_ref()
		if living(source) and connected(int(report["site"])):
			var ratio := clampf(1-(float(report["due"])-clock)/1.25,0,1)
			draw_arc(source.position,46,-PI/2,-PI/2+ratio*TAU,32,Color("ffc36b"),3,true)
			draw_string(font,source.position+Vector2(-40,-57),"UPLINK / %.0f%%" % (ratio*100),HORIZONTAL_ALIGNMENT_LEFT,140,11,Color("ffc36b"))
	for site in sites:
		var point: Vector2=site["position"]
		var color := Color("8bdfa4") if site["done"] else Color("ffc36b")
		draw_arc(point,100,0,TAU,40,color,2,true)
		draw_string(font,point+Vector2(-80,-120),"SITE %d / %s" % [int(site["id"])+1,str(site["kind"]).to_upper()],HORIZONTAL_ALIGNMENT_LEFT,250,13,color)
		draw_dashed_line(base,point,Color(cyan,0.12),1,32)
	draw_arc(base,150,0,TAU,48,cyan,2,true)
	draw_string(font,base+Vector2(-90,-175),"CRADLE / CARGO / EXIT",HORIZONTAL_ALIGNMENT_LEFT,260,13,cyan)
	if is_instance_valid(player):
		var target := goal()
		var direction := player.position.direction_to(_waypoint)
		draw_line(player.position+direction*50,player.position+direction*110,cyan,3,true)
		draw_string(font,player.position+Vector2(-70,75),"%du / %s" % [player.position.distance_to(target),"CARGO CRADLE" if carried>=0 else "NEXT SITE"],HORIZONTAL_ALIGNMENT_LEFT,240,11,cyan)
		if carried>=0:
			var cargo := player.position-Vector2.RIGHT.rotated(player.rotation)*48
			draw_line(player.position,cargo,Color("ffc36b"),2,true)
			draw_rect(Rect2(cargo-Vector2(7,7),Vector2(14,14)),Color("ffc36b"),false,2)
			draw_string(font,cargo+Vector2(-35,28),"RECORD %d" % (carried+1),HORIZONTAL_ALIGNMENT_LEFT,100,10,Color("ffc36b"))
