extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.get_node("Experience").persist=false
	root.get_node("Experience").hive_voice=false
	var host=load("res://src/campaign/campaign_host.gd").new()
	host.state.persist=false
	host.state.chapter=4
	host.state.node_id="watchdog"
	host.state.hull=80
	root.add_child(host)
	check(paused and host.screen_mode=="story" and host._scene_page==0,"Gate entry opens the first visual story page with action suspended")
	host.deploy()
	check(not is_instance_valid(host.game),"Deployment cannot bypass an unresolved story decision")
	host.choose_story("spoof")
	check(host.state.hull==80,"Choice cannot commit before reaching its consequence page")
	host.story_step(1)
	check(host.state.flags["listening_room_page"]==1,"Narrative page position is persisted in checkpoint state")
	var saved: Dictionary=host.state.snapshot()
	var state=load("res://src/campaign/campaign_state.gd").new()
	check(state.restore(saved,host.nodes.size()) and state.flags["listening_room_page"]==1,"Page position survives checkpoint roundtrip")
	host.story_step(1)
	host.choose_story("invalid")
	check(host.screen_mode=="story","Invalid choices are rejected")
	host.choose_story("spoof")
	check(host.state.hull==65 and host.state.flags["listening_room_choice"]=="spoof","Signature spoof spends exactly 15 hull and records its decision")
	host.choose_story("spoof")
	check(host.state.hull==65,"Repeated activation cannot charge the story cost twice")
	host.deploy()
	await process_frame
	check(get_nodes_in_group("enemy_normal").size()==4 and host.game.player.hull<=65,"Spoof route creates four actual escorts and retains hull cost")
	host.shutdown()
	host.queue_free()
	paused=false
	await process_frame
	var broadcast=load("res://src/campaign/campaign_host.gd").new()
	broadcast.state.persist=false
	broadcast.state.chapter=5
	broadcast.state.node_id="archive_recovery"
	broadcast.state.hull=80
	root.add_child(broadcast)
	while broadcast._scene_page<2: broadcast.story_step(1)
	broadcast.choose_story("broadcast")
	broadcast.deploy()
	await process_frame
	check(broadcast.game.recovery.pods[0].max_health==190 and broadcast.game.recovery.delivery_units==3,"Broadcast choice changes actual carrier capacity and reinforcement budget")
	broadcast.game.set_physics_process(false)
	broadcast.game.player.set_physics_process(false)
	for actor in broadcast.game.recovery.actors: actor.take_damage(10000,&"TEST")
	var pod=broadcast.game.recovery.pods[0]
	broadcast.game.player.position=pod.position
	broadcast.game.player.velocity=Vector2.ZERO
	broadcast.game.recovery.tick(1.5)
	var limit := 0
	while pod.status=="TOWING" and limit<120:
		broadcast.game.player.position=broadcast.game.player.position.move_toward(Vector2.ZERO,20)
		broadcast.game.recovery.tick(0.1)
		limit+=1
	check(broadcast.game.recovery.living_count()==3,"Repair broadcast can create three real delivery interceptors when capacity is available")
	broadcast.shutdown()
	broadcast.queue_free()
	paused=false
	await process_frame
	var poor=load("res://src/campaign/campaign_host.gd").new()
	poor.state.persist=false
	poor.state.chapter=4
	poor.state.node_id="watchdog"
	poor.state.hull=10
	root.add_child(poor)
	while poor._scene_page<2: poor.story_step(1)
	poor.choose_story("spoof")
	check(not poor.state.flags.has("listening_room_choice") and poor.state.hull==10,"Insufficient hull cannot be spent or turn into a free spoof")
	poor.choose_story("challenge")
	check(poor.state.hull==25,"Open challenge repair is capped and commits once")
	poor.deploy()
	await process_frame
	check(get_nodes_in_group("enemy_normal").size()==8,"Open challenge retains the full gate escort")
	poor.shutdown()
	poor.queue_free()
	paused=false
	await process_frame
	var departure=load("res://src/campaign/campaign_host.gd").new()
	departure.state.persist=false
	departure.state.chapter=8
	departure.state.node_id="the_three_voices"
	departure.state.hull=80
	departure.state.flags["power_circuits"]=3
	root.add_child(departure)
	check(departure.screen_mode=="story" and departure._scene_id=="departure_room","Restored power opens the illustrated departure interlude")
	while departure._scene_page<2: departure.story_step(1)
	for dimensions in [Vector2i(1280,720),Vector2i(360,640)]:
		root.content_scale_size=Vector2i.ZERO
		root.size=dimensions
		departure._relayout_panel()
		for i in range(4): await process_frame
		for button in departure._actions.get_children():
			var rect: Rect2=button.get_global_rect()
			check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=dimensions.x+1 and rect.end.y<=dimensions.y+1 and rect.size.y>=44,"Story actions remain visible and touch-sized outside the reading scroll at %s" % dimensions)
	departure.choose_story("linked")
	departure.deploy()
	await process_frame
	check(departure.game.tactical.convoy.max_health==510 and departure.game.tactical.detail_size==4,"Linked voices create real extra transport hull and a four-unit detail budget")
	departure.game.tactical._detail(1)
	check(departure.game.tactical.live_count()==4,"Linked departure actually spawns a four-hunter checkpoint")
	departure.shutdown()
	departure.queue_free()
	paused=false
	await process_frame
	if failures.is_empty(): print("STORY_OK visual pages / paused action / page resume / choice validation / costs / idempotency / real escort and recovery effects")
	quit(0 if failures.is_empty() else 1)
