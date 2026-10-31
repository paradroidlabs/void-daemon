extends SceneTree

var failures: Array[String] = []
var ship
var mission

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func fixture() -> void:
	if is_instance_valid(mission): mission.free()
	mission=load("res://src/campaign/recovery_mission.gd").new()
	root.add_child(mission)
	mission.setup(ship)
	for actor in mission.actors: actor.set_physics_process(false)

func bank(pod) -> void:
	ship.position=pod.position
	ship.velocity=Vector2.ZERO
	mission.tick(1.5)
	check(pod.status=="TOWING","Low-speed proximity attaches a carrier")
	ship.last_move_direction=ship.position.direction_to(Vector2.ZERO)
	var limit := 0
	while pod.status=="TOWING" and limit<120:
		ship.position=ship.position.move_toward(Vector2.ZERO,20)
		mission.tick(0.1)
		limit+=1
	check(pod.status=="BANKED","Continuous towing delivers the carrier without teleporting or breaking range")
	for actor in mission.actors: actor.set_physics_process(false)

func run() -> void:
	root.get_node("Experience").persist=false
	ship=load("res://src/actors/player_ship.gd").new()
	root.add_child(ship)
	ship.set_physics_process(false)
	fixture()
	check(mission.pods.size()==3 and mission.actors.size()==4,"Recovery begins with three carriers and four opponents")
	var pod=mission.pods[0]
	var hp: float=pod.health
	var friendly := Projectile.new()
	friendly.configure(pod.position,Vector2.RIGHT,{"damage":12},&"player")
	root.add_child(friendly)
	friendly._try_hit(pod)
	check(pod.health==hp,"Player projectiles cannot damage friendly archives")
	friendly.queue_free()
	var hostile := Projectile.new()
	hostile.configure(pod.position,Vector2.RIGHT,{"damage":12},&"enemy")
	root.add_child(hostile)
	hostile._try_hit(pod)
	check(pod.health==hp-12,"Enemy projectiles damage the real carrier receiver")
	ship.position=pod.position
	ship.velocity=Vector2(160,0)
	mission.tick(2)
	check(mission.towed()==null,"High-speed passes do not attach a tether")
	ship.velocity=Vector2.ZERO
	mission.tick(1.5)
	check(mission.towed()==pod,"Coasting explicitly acquires the carrier")
	mission.pods[1].position=ship.position
	mission.tick(2)
	check(mission.count("TOWING")==1,"Only one carrier can be towed at once")
	ship.position+=Vector2(700,0)
	mission.tick(0.1)
	check(pod.status=="STRANDED","Leaving tether range strands rather than teleports the carrier")

	fixture()
	var results := [{}]
	mission.completed.connect(func(result: Dictionary): results[0]=result)
	for carrier in mission.pods:
		bank(carrier)
		check(mission.living_count()<=6,"Every delivery respects the six-attacker concurrency cap")
		for actor in mission.actors:
			if mission.living(actor): actor.take_damage(10000,&"TEST")
	check(mission.actors.size()<=10,"Reinforcement budget is finite across all deliveries")
	mission.tick(0.1)
	check(not mission.active and results[0].get("rescued_carriers",0)==3,"All carriers plus cleared threats completes the evacuation")
	var banked=mission.pods[0]
	var protected_hp: float=banked.health
	banked._contact_left=0
	banked.take_damage(10000)
	check(banked.health==protected_hp,"Banked archives are secured against further damage")

	fixture()
	var partial := [{}]
	mission.completed.connect(func(result: Dictionary): partial[0]=result)
	mission.pods[1].take_damage(10000)
	mission.pods[2].take_damage(10000)
	bank(mission.pods[0])
	for actor in mission.actors: actor.take_damage(10000,&"TEST")
	mission.tick(0.1)
	check(partial[0].get("rescued_carriers",0)==1 and partial[0].get("lost_carriers",0)==2,"Partial rescue preserves exact survivor and loss counts")

	fixture()
	var lost := [0]
	mission.failed.connect(func(): lost[0]+=1)
	mission.cradle.take_damage(10000)
	mission.tick(0.1)
	mission.tick(1)
	check(lost[0]==1 and mission.failure_reason.contains("cradle"),"Cradle destruction fails once with an explicit reason")
	fixture()
	mission.failed.connect(func(): lost[0]+=1)
	for carrier in mission.pods: carrier.take_damage(10000)
	mission.tick(0.1)
	check(lost[0]==2 and mission.failure_reason.contains("All archive"),"Loss of every carrier is a separate failure condition")
	mission.free()
	ship.free()
	await process_frame
	if failures.is_empty(): print("RECOVERY_OK friendly safety / damage / attach / one tether / strand / continuous delivery / bounded reinforcements / all and partial rescue / failure reasons")
	quit(0 if failures.is_empty() else 1)
