extends SceneTree

## Autonomous balance probe. Uses normal game intents/actions only. It knows
## mission objectives; it is not a human playtest or a duration certification.
var host
var frames := 0
var wall_start := 0
var last_node := ""
var failures := 0
var hold_time := 0.0
var reports: Array[Dictionary] = []
var completed := false
var start_node := ""
var source_hashes: Dictionary={}
var output_path := ""

func resource_hash(path: String) -> String:
	if FileAccess.file_exists(path): return FileAccess.get_sha256(path)
	if FileAccess.file_exists(path+"c"): return FileAccess.get_sha256(path+"c")
	return ""

func fingerprint(folder: String) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd") or file.ends_with(".gdc"): source_hashes[folder+"/"+file]=FileAccess.get_sha256(folder+"/"+file)
	for directory in DirAccess.get_directories_at(folder): fingerprint(folder+"/"+directory)

func _initialize() -> void: call_deferred("run")

func valid(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.has_method("is_alive") and actor.is_alive()

func run() -> void:
	root.get_node("Experience").persist=false
	root.get_node("Experience").hive_voice=false
	fingerprint("res://src")
	host=load("res://src/campaign/campaign_host.gd").new()
	host.state.persist=false
	host.touch_controls=true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pilot-from="): start_node=argument.trim_prefix("--pilot-from=")
		if argument.begins_with("--pilot-chassis="): host.selected_chassis=argument.trim_prefix("--pilot-chassis=")
		if argument.begins_with("--pilot-output="): output_path=argument.trim_prefix("--pilot-output=")
	if not start_node.is_empty():
		for i in host.nodes.size():
			if host.nodes[i]["id"]==start_node:
				host.state.chapter=i
				host.state.node_id=start_node
		# Explicit late-game fixture for encounter iteration, not a full-route
		# timing claim. Final duration audits still start at the Outer Link.
		host.state.upgrades={"DRIVER_RAIL":2,"KINETIC_DAMPERS":1,"RETURN_VECTOR":1,"HULL_PLATING":2,"FORK_ON_KILL":1}
		host.state.hull=136
		host.state.shield=30
		host.state.flags["power_circuits"]=3
	root.add_child(host)
	wall_start=Time.get_ticks_msec()
	host.deploy()
	while frames<60*1800 and failures<3:
		await physics_frame
		frames+=1
		if host.state.chapter>=host.nodes.size():
			completed=true
			break
		if paused:
			if host.screen_mode=="story":
				if host._scene_page<2: host.story_step(1)
				else: host.choose_story({"listening_room":"challenge","berth_room":"silent","departure_room":"independent"}[host._scene_id])
				continue
			if host.screen_mode=="briefing":
				host.deploy()
				continue
			if not host._pending.is_empty():
				var report: Dictionary=host._pending.duplicate(true)
				reports.append({"node":host.nodes[host.state.chapter]["id"],"seconds":report["time"],"won":true,"hull":report["hull"],"objective_result":report.get("tactical",{})})
				print("PILOT_NODE ",JSON.stringify(reports.back()))
				var choice: String=host._offers[0] if not host._offers.is_empty() else ""
				host.claim(choice)
			else:
				failures+=1
				reports.append({"node":host.nodes[host.state.chapter]["id"],"seconds":host.game.elapsed_time,"won":false,"reason":host.game._campaign_failure_reason})
				print("PILOT_DEATH ",JSON.stringify(reports.back()))
			if host.screen_mode=="failed" and host.state.chapter<host.nodes.size(): host.deploy()
			hold_time=0
			continue
		var game=host.game
		if game.run_ended: continue
		if last_node!=host.nodes[host.state.chapter]["id"]:
			last_node=host.nodes[host.state.chapter]["id"]
			print("PILOT_ENTER ",last_node)
		if frames%600==0:
			print("PILOT_TICK ",last_node," time=",game.elapsed_time," hull=",game.player.hull," pos=",game.player.position)
		pilot(game,1.0/60)
	var source_unchanged := true
	for file in source_hashes:
		if FileAccess.get_sha256(file)!=source_hashes[file]: source_unchanged=false
	var output := {"build":ProjectSettings.get_setting("application/config/version"),"runtime_kind":"exported" if not FileAccess.file_exists("res://src/main.gd") else "source","seed":host.state.seed,"chassis":host.state.chassis,"catalog_sha256":resource_hash("res://src/campaign/chapter_catalog.gd"),"pilot_sha256":resource_hash(get_script().resource_path),"source_files_sha256":source_hashes,"source_unchanged":source_unchanged,"completed":completed,"failures":failures,"frames":frames,
		"start_node":start_node,"completed_mission_seconds":host.state.seconds,"attempts":host.state.attempts,"story_choices":{"listening_room":host.state.flags.get("listening_room_choice",""),"berth_room":host.state.flags.get("berth_room_choice","")},"story_reading":"advanced immediately by pilot; not measured or added to active mission time",
		"events":reports,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,
		"method":"normal game movement intents, aiming and chassis actions; no position, health, damage or objective writes"}
	var destination: String=output_path if not output_path.is_empty() else "res://.godot/campaign-pilot-"+host.state.chassis+".json"
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file==null:
		push_error("Pilot could not write evidence: "+destination)
		host.shutdown()
		paused=false
		quit(3)
		return
	file.store_string(JSON.stringify(output,"  "))
	file.close()
	if host.state.chassis=="graviton" and output_path.is_empty():
		file=FileAccess.open("res://.godot/campaign-pilot-result.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(output,"  "))
		file.close()
	print("PILOT_RESULT ",JSON.stringify(output))
	host.shutdown()
	paused=false
	host.queue_free()
	await process_frame
	quit(0 if completed else 2)

func pilot(game, delta: float) -> void:
	var ship=game.player
	var nearest: Node2D
	var distance := 100000.0
	for actor in get_nodes_in_group("enemies"):
		if not valid(actor) or not CombatGeometry.clear(ship.position,actor.global_position,ship.combat_geometry): continue
		var gap: float=ship.position.distance_to(actor.global_position)
		if gap<distance:
			distance=gap
			nearest=actor
	var goal: Vector2=ship.position
	var standoff := 0.0
	var cruise := 210.0
	match game._campaign_kind:
		"relay":
			if game.substrate.link_alive():
				goal=game.substrate.relay.position
				standoff=210
			else: goal=game.substrate.exit_position
		"transit":
			goal=game.transit.gates[mini(game.transit.next_gate,game.transit.gates.size()-1)]
			cruise=185
		"facility":
			var objective: Vector2=game.facility.objective_position()
			goal=CombatGeometry.waypoint(ship.position,objective,game.facility.walls,game.facility.doors)
			if goal==objective and game.facility.remaining()>0: standoff=190
		"clear":
			goal=game.picket.goal()
			if nearest!=null and distance<250: standoff=0
		"recovery":
			cruise=175
			if game.recovery.towed()!=null: goal=Vector2.ZERO
			else:
				var best := INF
				for pod in game.recovery.pods:
					if pod.status=="STRANDED" and ship.position.distance_to(pod.position)<best:
						best=ship.position.distance_to(pod.position)
						goal=pod.position
				if is_inf(best):
					goal=nearest.position if nearest!=null else Vector2.ZERO
					standoff=200 if nearest!=null else 0
		"expedition":
			goal=game.expedition.goal()
			# Clear remaining local guards before attempting to activate a new site.
			if game.expedition.live_count()>4 and nearest!=null:
				goal=nearest.global_position
				standoff=180
			goal=CombatGeometry.waypoint(ship.position,goal,game.expedition.walls,game.expedition.doors)
		"power","convoy","stronghold","exodus":
			goal=CombatGeometry.waypoint(ship.position,game.tactical.goal(),game.tactical.walls,game.tactical.doors)
		_:
			if nearest!=null:
				goal=nearest.global_position
				standoff=240
	var offset: Vector2=goal-ship.position
	var desired := Vector2.ZERO
	if offset.length()>standoff+35:
		desired=offset.normalized()*minf(cruise,(offset.length()-standoff)*1.5)
	if nearest!=null and distance<110 and game._campaign_kind not in ["transit","facility","recovery"]:
		desired+=nearest.global_position.direction_to(ship.position)*180
	game._touch_move=((desired-ship.velocity)*3.0-ship.flight_gravity)/ship.thrust_acceleration
	game._touch_move=game._touch_move.limit_length()
	if nearest!=null:
		game._touch_aim=ship.position.direction_to(nearest.global_position)
		game._touch_aim_active=true
	if game._campaign_kind=="transit": return
	if nearest!=null and distance<640:
		if not game.graviton.is_charging and ship.heat<40: game._begin_unleash()
		if game.graviton.is_charging:
			hold_time+=delta
			if hold_time>1.05 or ship.heat>75:
				game._release_unleash()
				hold_time=0
	elif game.graviton.is_charging:
		game._release_unleash()
		hold_time=0
	if distance<65 and ship.phase_cooldown<=0: game._try_vent()
