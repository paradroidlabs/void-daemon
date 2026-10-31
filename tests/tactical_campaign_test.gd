extends SceneTree

var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures.append(text)
		push_error(text)
func ship():
	var result=load("res://src/actors/player_ship.gd").new()
	root.add_child(result)
	result.set_physics_process(false)
	return result
func kill_detail(mission) -> void:
	for actor in mission.actors:
		if mission.living(actor): actor.take_damage(10000,&"TEST")

func run() -> void:
	root.get_node("Experience").persist=false
	root.get_node("Experience").hive_voice=false
	var player=ship()
	var power=load("res://src/campaign/power_district.gd").new()
	root.add_child(power)
	power.setup(player)
	check(power.walls.size()==10 and player.combat_geometry==power.walls,"Power district installs real six-room geometry")
	check(not CombatGeometry.clear(power.feeders[0],power.sockets[0],power.walls),"Bulkheads occlude cross-district shots")
	for destination in power.feeders+power.sockets+[power.bus]:
		var cursor: Vector2=power.exit_position
		for i in range(25):
			if cursor.distance_to(destination)<0.1: break
			var point := CombatGeometry.waypoint(cursor,destination,power.walls,power.doors)
			check(point!=cursor and CombatGeometry.clear(cursor,point,power.walls,24),"Every district objective has a ship-sized clear doorway route")
			cursor=point
		check(cursor.distance_to(destination)<0.1,"Doorway graph reaches each required room")
	player.position=power.feeders[0]
	player.velocity=Vector2.ZERO
	power.tick(2)
	check(power.carried==-1,"Contested feeder cannot yield its cell")
	kill_detail(power)
	player.velocity=Vector2(150,0)
	power.tick(2)
	check(power.carried==-1,"Feeder requires a controlled coast")
	player.velocity=Vector2.ZERO
	power.tick(1.5)
	check(power.carried==0 and power.circuits[0]==1,"Cleared feeder transfers exactly one numbered cell")
	player.position=power.sockets[1]
	power.tick(2)
	check(power.carried==0 and power.circuits[0]==1,"A cell cannot be installed in the wrong converter")
	var wins := [0]
	power.completed.connect(func(_result): wins[0]+=1)
	for i in range(3):
		if i>0:
			player.position=power.feeders[i]
			power.tick(0.1)
			kill_detail(power)
			power.tick(1.5)
		player.position=power.sockets[i]
		power.tick(0.1)
		kill_detail(power)
		power.tick(1.5)
		check(power.circuits[i]==2 and power.carried==-1,"Installation powers the converter but does not skip bus confirmation")
		player.position=power.bus
		power.tick(1.5)
	check(wins[0]==0 and power.circuits.count(3)==3,"All circuits confirm before extraction")
	player.position=power.sockets[0]+Vector2(0,200)
	player._invulnerable_left=0
	var integrity: float=player.hull+player.shield
	power.clock=6
	power._pulse_cycle=0
	power.tick(1.1)
	check(player.hull+player.shield<integrity,"Online converter discharge applies real defensive damage")
	player.position=power.exit_position
	power.tick(0.1)
	power.tick(2)
	check(wins[0]==1,"Power mission completes once after the physical exit")
	power.free()
	player.free()
	await process_frame

	player=ship()
	var convoy=load("res://src/campaign/convoy_mission.gd").new()
	root.add_child(convoy)
	convoy.setup(player,{"power_circuits":3})
	check(convoy.convoy.max_health==450,"Three restored circuits add actual convoy hull")
	for i in range(1,convoy.route.size()): check(CombatGeometry.clear(convoy.route[i-1],convoy.route[i],convoy.walls,24),"Transport reference route clears every solid partition")
	var old_position: Vector2=convoy.convoy.position
	player.position=Vector2(3000,2000)
	convoy.tick(1)
	check(convoy.convoy.position==old_position,"Transport holds when escort leaves its 700-unit range")
	var safety := 0
	while convoy.next_point<convoy.route.size() and safety<3000:
		player.position=convoy.convoy.position
		convoy.tick(0.1)
		check(convoy.live_count()<=8,"Convoy reinforcement cap remains bounded")
		kill_detail(convoy)
		safety+=1
	player.position=convoy.route.back()
	convoy.tick(0.1)
	check(not convoy.active and convoy.triggered.size()==7,"Convoy reaches seven real guarded checkpoints and extraction")
	convoy.free()
	player.free()
	await process_frame
	player=ship()
	var doomed=load("res://src/campaign/convoy_mission.gd").new()
	root.add_child(doomed)
	doomed.setup(player)
	var losses := [0]
	doomed.failed.connect(func(): losses[0]+=1)
	doomed.convoy.take_damage(10000)
	doomed.tick(0.1)
	doomed.tick(1)
	check(losses[0]==1 and not doomed.failure_reason.is_empty(),"Transport destruction emits one explicit mission failure")
	doomed.free()
	player.free()
	await process_frame

	player=ship()
	var fortress=load("res://src/campaign/stronghold_mission.gd").new()
	root.add_child(fortress)
	fortress.setup(player)
	var core=fortress.core
	check(core.shielded and not core.is_in_group("enemies") and not core.take_damage(500,&"TEST"),"Visible barrier excludes automatic targeting and rejects actual damage")
	for stage in range(3):
		for link in fortress.links: link.take_damage(10000,&"TEST")
		fortress.tick(0.1)
		check(not core.shielded and core.is_in_group("enemies"),"Destroyed conduits expose a persistent damage phase")
		core.take_damage(10000,&"TEST")
		if stage<2:
			check(core.health==1200-stage*600 and core.shielded,"An oversized salvo cannot skip a physical barrier stage")
			await process_frame
			check(fortress.phase==stage+1 and fortress.links.size()==2,"Next barrier creates exactly two real remote conduits")
	check(not core.is_alive() and fortress.keys_broken==6,"Final exposed third kills the core after six conduits")
	player.position=fortress.exit_position
	fortress.tick(0.1)
	check(not fortress.active,"Destroyed Warden permits extraction")
	fortress.free()
	player.free()
	await process_frame

	player=ship()
	var escape=load("res://src/campaign/exodus_mission.gd").new()
	root.add_child(escape)
	escape.setup(player)
	for i in range(1,escape.gates.size()): check(CombatGeometry.clear(escape.gates[i-1],escape.gates[i],escape.walls,24),"Escape reference route clears all solid barriers")
	player.position=escape.gates[2]
	escape.tick(0.01)
	check(escape.next_gate==1,"Teleporting to a later escape gate cannot skip the route")
	player.position=escape.gates[0]
	escape.tick(0.01)
	for i in range(1,escape.gates.size()):
		var limit := 0
		while escape.next_gate<=i and limit<600:
			player.position=player.position.move_toward(escape.gates[i],20)
			escape.tick(0.01)
			kill_detail(escape)
			limit+=1
	check(not escape.active and escape.next_gate==12 and escape.triggered.size()==3,"Continuous forward traversal plus three real jammer kills completes escape")
	escape.free()
	player.free()
	await process_frame
	player=ship()
	var storm=load("res://src/campaign/exodus_mission.gd").new()
	root.add_child(storm)
	storm.setup(player)
	storm.clock=21
	player._invulnerable_left=0
	var before_front: float=player.hull+player.shield
	storm.tick(0.1)
	check(player.hull+player.shield<before_front and storm.front.distance_to(storm.gates[0])>14,"Visible collapse advances and deals real shield/hull damage")
	storm.clock=300
	storm.tick(0.1)
	check(not storm.active and not storm.failure_reason.is_empty(),"Missing the escape receiver has an explicit terminal failure")
	storm.free()
	player.free()
	await process_frame
	if failures.is_empty(): print("TACTICAL_CAMPAIGN_OK rooms / matched cells / bus / pulses / convoy consequence / escort / bounded details / three barrier stages / no damage skip / escape geometry and gate order")
	quit(0 if failures.is_empty() else 1)
