extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func equivalent(a, b) -> bool:
	# ConfigFile's text round trip need not preserve a double bit-for-bit.
	if a is float and b is float: return absf(a-b)<0.000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b


func run() -> void:
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var host = load("res://src/campaign/campaign_host.gd").new()
	host.state.persist = false
	root.add_child(host)
	check(paused and host.state.chapter == 0, "New campaign opens a paused briefing")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	check(not paused and is_instance_valid(host.game.substrate), "First mission is the playable relay encounter")
	check(not host.game.hud._lab_bar.visible, "Campaign hides lab selectors that could bypass mission state")
	host.game.player.hull = 45
	host.game.substrate.relay.take_damage(10000, &"TEST")
	host.game.player.position = host.game.substrate.exit_position
	host.game.substrate.tick(0.2)
	await process_frame
	check(paused and not host._pending.is_empty(), "Actual extraction opens the salvage transition")
	host.claim("DRIVER_RAIL")
	check(host.state.chapter == 1 and host.state.upgrades.get("DRIVER_RAIL", 0) == 1, "Reward banks and advances exactly one node")
	check(host.state.hull == 70, "Service cradle repairs a bounded 25 hull")
	host.claim("DRIVER_RAIL")
	check(host.state.chapter == 1, "Repeated reward activation cannot duplicate progress")
	var stored: Dictionary = host.state.snapshot()
	var restored = load("res://src/campaign/campaign_state.gd").new()
	check(restored.restore(stored, host.nodes.size()), "Checkpoint round trips all campaign data")
	check(restored.chapter == 1 and restored.hull == 70 and restored.upgrades == host.state.upgrades, "Checkpoint retains hull and patch ranks")
	restored.save_path = "res://.godot/campaign-test-checkpoint.cfg"
	check(restored.save_checkpoint() == OK, "Checkpoint is written through ConfigFile")
	var disk_state = load("res://src/campaign/campaign_state.gd").new()
	disk_state.save_path = restored.save_path
	check(disk_state.load_checkpoint(host.nodes.size()) and equivalent(disk_state.snapshot(),restored.snapshot()), "Fresh session loads equivalent checkpoint data within one microsecond for floats")
	var corrupt: Dictionary = stored.duplicate(true)
	corrupt["chapter"] = 10000
	check(not restored.restore(corrupt, host.nodes.size()), "Invalid checkpoint route indices are rejected")
	corrupt=stored.duplicate(true)
	corrupt["attempts"]=[{"node":"outer_link","seconds":INF,"won":true,"banked":true}]
	check(not restored.restore(corrupt,host.nodes.size()),"Nonfinite timing records cannot corrupt campaign totals")
	corrupt["attempts"]=[{"node":"outer_link","seconds":5.0,"won":false,"banked":true}]
	check(not restored.restore(corrupt,host.nodes.size()),"A failed attempt cannot masquerade as a banked victory")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	check(host.game.player.hull <= 70 and host.game.upgrades.get("DRIVER_RAIL", 0) == 1, "Next mission restores persistent ship state")
	check(not is_instance_valid(host.game.boss), "Picket mission does not accidentally create the lab boss")
	host.game._end_run(false)
	await process_frame
	check(host.state.chapter == 1 and host.state.hull == 70, "Death does not mutate the entry checkpoint")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	check(is_instance_valid(host.game.transit), "Checkpoint retry restores the interception objective")
	for point: Vector2 in host.game.transit.gates:
		while host.game.transit.active and host.game.player.position.distance_to(point) > 0.1:
			host.game.player.position = host.game.player.position.move_toward(point, 20)
			host.game.transit.tick(0.01)
	await process_frame
	check(not host._pending.is_empty(), "Actual transit objective reaches the campaign reward flow")
	host.claim("KINETIC_DAMPERS")
	check(host.state.flags.get("courier_escaped", true) == false and host.state.chapter == 2, "Interception consequence persists into campaign state")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	for enemy in get_nodes_in_group("enemy_normal"):
		enemy.take_damage(10000, &"TEST")
	host.game._physics_process(0.01)
	check(host._pending.is_empty(),"Killing the picket alone cannot skip securing its separated positions")
	for point in host.game.picket.beacons:
		host.game.player.position=point
		host.game.player.velocity=Vector2.ZERO
		host.game.picket.tick(1.5)
	host.game.player.position=host.game.picket.exit_position
	host.game.picket.tick(0.1)
	await process_frame
	check(not host._pending.is_empty(), "Clearing the actual picket completes its objective")
	host.claim("CONDUCTIVE_MARK")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	check(is_instance_valid(host.game.facility),"Picket outcome deploys the authored facility mission")
	for core in host.game.facility.cores: core.take_damage(10000,&"TEST")
	host.game.player.position = host.game.facility.archive
	host.game.player.velocity = Vector2.ZERO
	host.game.facility.tick(3)
	host.game.player.position = host.game.facility.exit_position
	host.game.facility.tick(0.1)
	await process_frame
	host.claim("HULL_PLATING")
	check(host.state.flags.get("archive_recovered",false),"Archive recovery becomes a saved campaign consequence")
	check(host.screen_mode=="story","Recovered ledger opens the story hub before the gate")
	while host._scene_page<2: host.story_step(1)
	host.choose_story("challenge")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	check(is_instance_valid(host.game.boss) and host.game.boss.is_physics_processing(), "Final gate deploys an active Watchdog")
	host.game.boss.take_damage(100000, &"TEST")
	await process_frame
	host.claim("")
	check(host.state.node_id=="archive_recovery" and paused,"Watchdog unlocks the recovery yard rather than ending the expedition")
	while host._scene_page<2: host.story_step(1)
	host.choose_story("silent")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	check(is_instance_valid(host.game.recovery),"Recovery mission deploys through the actual campaign host")
	for pod in host.game.recovery.pods:
		host.game.player.position=pod.position
		host.game.player.velocity=Vector2.ZERO
		host.game.recovery.tick(1.5)
		var limit := 0
		while pod.status=="TOWING" and limit<120:
			host.game.player.position=host.game.player.position.move_toward(Vector2.ZERO,20)
			host.game.recovery.tick(0.1)
			limit+=1
		for actor in host.game.recovery.actors:
			if host.game.recovery.living(actor): actor.take_damage(10000,&"TEST")
	host.game.recovery.tick(0.1)
	await process_frame
	host.claim("")
	check(host.state.node_id=="memory_spine" and host.state.flags.get("rescued_carriers",0)==3,"Recovery banks its outcome and opens the larger sector")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	var expedition=host.game.expedition
	check(is_instance_valid(expedition) and host.game.camera.limit_right==int(expedition.BOUNDS.end.x),"Sector deployment expands ship and camera bounds together")
	var event := InputEventKey.new()
	event.pressed=true
	event.keycode=KEY_M
	event.physical_keycode=KEY_M
	Input.parse_input_event(event)
	await process_frame
	check(paused and host.game.hud._end_card.page==6,"Native M input opens the paused sector map")
	check(host.game.hud._end_tab_buttons[6].visible and not host.game.run_ended,"Map inspection preserves the active mission")
	host.game.hud._restart_button.pressed.emit()
	check(not paused,"Map Resume returns to the same mission")
	for site in expedition.sites:
		host.game.player.position=site["position"]
		host.game.player.velocity=Vector2.ZERO
		expedition.tick(0.1)
		for actor in expedition.actors:
			if expedition.living(actor): actor.take_damage(10000,&"TEST")
		expedition.tick(2.1)
		if expedition.carried>=0:
			host.game.player.position=expedition.base
			expedition.tick(0.1)
	host.game.player.position=expedition.base
	expedition.tick(0.1)
	await process_frame
	check(not host._pending.is_empty(),"All sector objectives reach the real campaign transition")
	host.claim("")
	check(host.state.node_id=="power_district" and host.state.flags.get("records_delivered",0)==3,"Three banked records open the power district")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	var power=host.game.tactical
	for i in range(3):
		for point in [power.feeders[i],power.sockets[i],power.bus]:
			host.game.player.position=point
			host.game.player.velocity=Vector2.ZERO
			power.tick(0.1)
			for actor in power.actors:
				if power.living(actor): actor.take_damage(10000,&"TEST")
			power.tick(1.5)
	host.game.player.position=power.exit_position
	power.tick(0.1)
	await process_frame
	host.claim("")
	check(host.state.flags.get("power_circuits",0)==3 and host.screen_mode=="story","Restored circuits persist into the departure story")
	while host._scene_page<2: host.story_step(1)
	var before_service: float=host.state.hull
	host.choose_story("independent")
	check(host.state.hull>=before_service and host.state.flags["departure_room_choice"]=="independent","Departure choice commits its actual service consequence")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	var escort=host.game.tactical
	check(escort.convoy.max_health==450,"Power outcome affects the actual deployed transport")
	var steps := 0
	while escort.active and steps<3000:
		host.game.player.position=escort.convoy.position
		escort.tick(0.1)
		for actor in escort.actors:
			if escort.living(actor): actor.take_damage(10000,&"TEST")
		steps+=1
	await process_frame
	host.claim("")
	check(host.state.flags.get("convoy_hull",0)>0 and host.state.node_id=="the_warden","Transport survival banks before the final stronghold")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	var fortress=host.game.tactical
	for stage in range(3):
		for link in fortress.links: link.take_damage(10000,&"TEST")
		fortress.tick(0.1)
		fortress.core.take_damage(10000,&"TEST")
		await process_frame
	for actor in fortress.actors:
		if fortress.living(actor): actor.take_damage(10000,&"TEST")
	host.game.player.position=fortress.exit_position
	fortress.tick(0.1)
	await process_frame
	host.claim("")
	check(host.state.flags.get("stronghold_keys",0)==6 and host.state.node_id=="first_arrival","All three Warden stages precede the escape checkpoint")
	host.deploy()
	await process_frame
	host.game.set_physics_process(false)
	host.game.player.set_physics_process(false)
	var escape=host.game.tactical
	for i in range(1,escape.gates.size()):
		var limit := 0
		while escape.active and escape.next_gate<=i and limit<600:
			host.game.player.position=host.game.player.position.move_toward(escape.gates[i],20)
			escape.tick(0.01)
			for actor in escape.actors:
				if escape.living(actor): actor.take_damage(10000,&"TEST")
			limit+=1
	await process_frame
	host.claim("")
	check(host.state.chapter==host.nodes.size() and host.state.flags.get("escaped",false),"Actual escape reaches the eleven-mission ending with its outcome persisted")
	check(host.state.kills >= 8, "Campaign totals retain kills across nodes")
	check(host.state.attempts.size()>=7 and host.state.attempts[0]["banked"],"Campaign timing retains successful missions and the failed retry separately")
	host.shutdown()
	paused = false
	host.queue_free()
	await process_frame
	var remapped = load("res://src/campaign/campaign_host.gd").new()
	remapped.state.save_path = "res://.godot/campaign-remap-checkpoint.cfg"
	remapped.state.chapter = 0
	remapped.state.node_id = "picket"
	remapped.state.flags["courier_escaped"] = true
	check(remapped.state.save_checkpoint() == OK, "Stable-ID resume fixture saved")
	remapped.resume_requested = true
	remapped.state.persist = false
	root.add_child(remapped)
	check(remapped.state.chapter == 2, "Resume locates mission by stable ID rather than the obsolete array index")
	remapped.deploy()
	await process_frame
	check(get_nodes_in_group("enemy_normal").size() == 8, "Escaped courier adds exactly two real picket reinforcements")
	remapped.shutdown()
	paused = false
	remapped.queue_free()
	await process_frame
	var migrated=load("res://src/campaign/campaign_host.gd").new()
	migrated.state.save_path="res://.godot/campaign-completed-draft.cfg"
	migrated.state.chapter=7
	migrated.state.node_id="__complete__"
	migrated.state.flags={"spine_sites":9,"records_delivered":3,"rescued_carriers":3}
	migrated.state.upgrades={"DRIVER_RAIL":2}
	migrated.state.hull=80
	check(migrated.state.save_checkpoint()==OK,"Completed .2 draft fixture saved")
	migrated.resume_requested=true
	migrated.state.persist=false
	root.add_child(migrated)
	check(migrated.state.chapter==7 and migrated.screen_mode=="briefing" and migrated.state.upgrades["DRIVER_RAIL"]==2,"Completed seven-mission draft resumes at unplayed power district without losing its build")
	migrated.shutdown()
	migrated.queue_free()
	paused=false
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("CAMPAIGN_OK brief / real extraction / reward / ship carry / checkpoint validation / death retry / picket objective / boss / ending")
	quit(0 if failures.is_empty() else 1)
