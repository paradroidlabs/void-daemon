extends SceneTree
var failures: Array[String] = []
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
	var mission=load("res://src/campaign/picket_mission.gd").new()
	root.add_child(mission)
	mission.setup(ship,true)
	for actor in mission.actors: actor.set_physics_process(false)
	check(mission.actors.size()==8,"Escaped courier produces exactly eight distributed opponents")
	ship.position=mission.beacons[0]
	ship.velocity=Vector2.ZERO
	mission.tick(2)
	check(mission.secured.count(true)==0,"A contested position cannot be secured")
	for actor in mission.actors: actor.take_damage(10000,&"TEST")
	await process_frame
	var emitted := [0]
	mission.completed.connect(func(): emitted[0]+=1)
	mission.tick(0.1)
	check(emitted[0]==0,"Eliminating the guards does not complete an unvisited route")
	ship.velocity=Vector2(150,0)
	mission.tick(2)
	check(mission.secured.count(true)==0,"A fast pass does not satisfy securing a beacon")
	ship.velocity=Vector2.ZERO
	for point in mission.beacons:
		ship.position=point
		mission.tick(1.5)
	check(mission.secured.count(true)==3 and emitted[0]==0,"All three independent positions secure before extraction")
	ship.position=mission.exit_position
	mission.tick(0.1)
	mission.tick(2)
	check(emitted[0]==1,"Extraction completes exactly once")
	mission.free()
	ship.free()
	await process_frame
	if failures.is_empty(): print("PICKET_OK distributed threats / consequence / contested capture / low-speed securing / all positions / extraction")
	quit(0 if failures.is_empty() else 1)
