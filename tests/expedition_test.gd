extends SceneTree

var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.get_node("Experience").persist=false
	var ship=load("res://src/actors/player_ship.gd").new()
	root.add_child(ship)
	ship.set_physics_process(false)
	var mission=load("res://src/campaign/sector_expedition.gd").new()
	root.add_child(mission)
	mission.setup(ship,42)
	check(mission.sites.size()==9 and mission.live_count()==0,"Nine sites exist but enemies do not spawn at a distance")
	var duplicate=load("res://src/campaign/sector_expedition.gd").new()
	root.add_child(duplicate)
	duplicate.setup(ship,42)
	check(duplicate.sites[0]["position"]==mission.sites[0]["position"],"Same content seed yields identical site coordinates")
	duplicate.free()
	var changed=load("res://src/campaign/sector_expedition.gd").new()
	root.add_child(changed)
	changed.setup(ship,43)
	check(changed.sites[0]["position"]!=mission.sites[0]["position"],"A different content seed changes site coordinates")
	changed.free()
	ship.position=mission.sites[0]["position"]
	mission.tick(0.2)
	for actor in mission.actors: actor.set_physics_process(false)
	check(mission.live_count()==4,"Relay site activates three defenders and one core")
	check(mission._reports.size()==1,"A scout must see the ship before creating a delayed report")
	mission.sites[0]["core"].get_ref().take_damage(10000,&"TEST")
	mission.tick(1.5)
	check(mission.received_reports==0 and mission.prevented_reports==1,"Destroying the relay cancels an in-flight report")
	check(not mission.connected(0),"Relay survivors are disconnected from the spine")
	ship.position=Vector2(0,5800)
	mission.tick(3)
	for actor in mission.sites[0]["actors"]:
		check(actor.task=="GUARD / SEARCH","Out-of-sight disconnected guards cannot track the ship")
	# Exercise the bounded concurrent activation budget separately from objectives.
	mission._activate(mission.sites[1])
	var scout=mission.sites[1]["actors"][0]
	scout.position=Vector2(mission.sites[1]["position"])+Vector2(0,-300)
	ship.position=Vector2(mission.sites[1]["position"])+Vector2(0,-600)
	mission._think_agents()
	check(mission._reports.is_empty(),"Nearby scouts cannot report through dock bulkheads")
	check(ship.combat_geometry.size()==12 and scout.combat_geometry==mission.walls,"Ship and enemy simulation share the actual solid dock geometry")
	mission._activate(mission.sites[2])
	check(mission.live_count()<=8 and not mission.sites[2]["active"],"Outstanding guards prevent an unlimited activation burst")
	for actor in mission.actors:
		if mission.living(actor): actor.take_damage(10000,&"TEST")
	ship.hull=ship.max_hull-5
	ship.position=mission.sites[1]["position"]
	ship.velocity=Vector2(150,0)
	mission.tick(3)
	check(not mission.sites[1]["done"],"Survey collection requires braking, not a fast fly-by")
	ship.velocity=Vector2.ZERO
	mission.tick(2)
	check(mission.sites[1]["done"] and ship.hull==ship.max_hull and mission.repairs==1,"Survey repair is capped and consumed once")
	mission.tick(3)
	check(mission.repairs==1,"Revisiting a completed survey cannot farm repair")
	var victories := [0]
	mission.completed.connect(func(_result: Dictionary): victories[0]+=1)
	for site in mission.sites:
		if site["done"]: continue
		ship.position=site["position"]
		ship.velocity=Vector2.ZERO
		mission.tick(0.1)
		for actor in mission.actors:
			if mission.living(actor): actor.take_damage(10000,&"TEST")
		mission.tick(2.1)
		if mission.carried>=0:
			check(not site["done"],"A collected archive is not banked until delivered")
			ship.position=mission.base
			mission.tick(0.1)
	check(mission.delivered==3 and mission.secured_count()==9,"Three archive deliveries and all nine sites are required")
	ship.position=mission.base
	mission.tick(0.1)
	mission.tick(5)
	check(victories[0]==1,"Final cradle return completes exactly once")
	mission.free()
	ship.free()
	await process_frame
	if failures.is_empty(): print("EXPEDITION_OK seeded sites / activation cap / interruptible reports / relay disconnect / local senses / finite repair / cargo delivery / extraction")
	quit(0 if failures.is_empty() else 1)
