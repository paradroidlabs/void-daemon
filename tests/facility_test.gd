extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var game = load("res://src/main.tscn").instantiate()
	game._honor_command_line = false
	game._combat_lab = true
	game._campaign_mode = true
	game._campaign_kind = "facility"
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for actor in game.facility.actors: actor.set_physics_process(false)
	await physics_frame
	var f = game.facility
	check(f.remaining()==2 and f.actors.size()==8,"Facility has two objective cores and six guards")
	for point in [game.player.position,f.archive,f.exit_position]:
		for wall: Rect2 in f.walls:
			check(not wall.grow(24).has_point(point),"Spawn, archive and extraction are accessible outside walls")
	check(not CombatGeometry.clear(Vector2(-100,-300),Vector2(100,-300),f.walls),"Bulkhead blocks cross-room line of sight")
	check(CombatGeometry.clear(Vector2(-100,-100),Vector2(100,-100),f.walls),"Central doorway remains open")
	var first_door := CombatGeometry.waypoint(game.player.position,Vector2(-1000,-440),f.walls,f.doors)
	check(first_door != game.player.position and CombatGeometry.clear(game.player.position,first_door,f.walls,24),"Objective guidance finds an accessible doorway instead of pointing into a bulkhead")
	var route_position: Vector2 = game.player.position
	for destination in [Vector2(-1000,-440),Vector2(1000,-440),f.archive,f.exit_position]:
		for hop in range(20):
			if route_position.distance_to(destination) < 1: break
			var waypoint := CombatGeometry.waypoint(route_position,destination,f.walls,f.doors)
			check(waypoint != route_position and CombatGeometry.clear(route_position,waypoint,f.walls,24),"Every objective has a ship-clear doorway route")
			route_position = waypoint
		check(route_position.distance_to(destination) < 1,"Objective route reaches its destination without a sealed room")
	game.player.position = Vector2(-100,-300)
	var target: Enemy = f.actors[1]
	target.position = Vector2(100,-300)
	var targets: Array[Node] = [target]
	check(not game.weapon_controller._nearest_enemies(game.player.position,targets,[],740).has(target),"Automatic target selection rejects actors behind cover")
	check(not game.graviton._target_candidates(game.player.position,620).has(target),"Graviton targeting cannot acquire through bulkheads")
	var untouched: float = target.health
	game.weapon_controller._fire_arc(game.player,targets)
	check(target.health==untouched,"Automatic ARC cannot jump to an occluded first target")
	for id in ["bastion","redline"]:
		game.player.configure_chassis(id)
		var arsenal = load("res://src/systems/alternate_arsenal.gd").new()
		game.world_root.add_child(arsenal)
		arsenal.setup(game.player)
		arsenal._damage_tick(targets,Vector2.RIGHT,0.1)
		check(target.health==untouched,"Manual beam/plasma respects bulkhead cover for " + id)
		if id=="bastion": check(is_equal_approx(arsenal._beam_end.x,-40),"Beam visual ends on the first solid surface")
		arsenal.queue_free()
	var shot := Projectile.new()
	shot.configure(game.player.position,Vector2.RIGHT,{"speed":600})
	shot.combat_geometry.assign(f.walls)
	game.world_root.add_child(shot)
	shot._physics_process(0.5)
	check(shot._is_expired,"Swept projectile motion is blocked even at a long timestep")
	var missile := SwarmMissile.new()
	missile.configure(game.player.position,Vector2.RIGHT,target.position,target)
	missile.combat_geometry.assign(f.walls)
	game.world_root.add_child(missile)
	missile._physics_process(0.5)
	check(missile.spent,"Homing missiles cannot cross solid cover")
	var original: float = target.health
	var blast := SwarmMissile.new()
	blast.configure(Vector2(-45,-300),Vector2.RIGHT,target.position,target)
	blast.combat_geometry.assign(f.walls)
	game.world_root.add_child(blast)
	blast.detonate(Vector2(-45,-300),target)
	check(target.health==original,"A blocked missile cannot hit its hidden target")
	target.position = Vector2(-50,-300)
	target.combat_geometry.assign(f.walls)
	target._target = null
	target.set_target_position(Vector2(400,-300))
	target.speed = 120
	target._physics_process(0.1)
	check(target.position.x < -40-target.collision_radius,"Area-based enemy movement respects wall bounds")
	game.player.position = f.archive
	game.player.velocity = Vector2.ZERO
	f.tick(4)
	check(not f.recovered,"Archive is locked while any coolant core survives")
	for core in f.cores: core.take_damage(10000,&"TEST")
	await process_frame
	f.tick(1)
	check(not f.recovered and f.archive_progress==1,"Transfer requires actual time in the archive ring")
	game.player.velocity = Vector2(150,0)
	f.tick(1)
	check(f.archive_progress<1,"Fast transit does not satisfy a coasting transfer")
	game.player.velocity = Vector2.ZERO
	f.tick(3)
	check(f.recovered and not game.run_ended,"Archive recovery alone does not skip extraction")
	game.player.position = f.exit_position
	f.tick(0.1)
	check(game.run_ended and game.facility_result.get("archive_recovered",false),"Actual extraction emits the campaign result")
	game.synth_audio.shutdown()
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty(): print("FACILITY_OK rooms / accessible objectives / cover / bullets / missiles / enemy collision / multi-objective gating / transfer / extraction")
	quit(0 if failures.is_empty() else 1)
