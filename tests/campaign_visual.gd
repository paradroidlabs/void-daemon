extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	for i in range(6):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var boot = load("res://src/boot.tscn").instantiate()
	root.add_child(boot)
	await capture("res://.godot/campaign-hangar.png")
	boot.launch_campaign(false)
	boot.game.state.persist = false
	await capture("res://.godot/campaign-briefing.png")
	boot.game.deploy()
	await capture("res://.godot/campaign-first-mission.png")
	boot.game.state.chapter = 1
	boot.game.state.node_id = "courier"
	boot.game.deploy()
	await capture("res://.godot/campaign-intercept.png")
	boot.game.state.chapter=2
	boot.game.state.node_id="picket"
	boot.game.deploy()
	await capture("res://.godot/campaign-picket.png")
	boot.game.state.chapter = 3
	boot.game.state.node_id = "coolant_archive"
	boot.game.deploy()
	await capture("res://.godot/campaign-facility.png")
	boot.game.state.chapter=5
	boot.game.state.node_id="archive_recovery"
	boot.game.state.flags["berth_room_choice"]="silent"
	boot.game.deploy()
	await capture("res://.godot/campaign-recovery.png")
	boot.game.state.chapter=6
	boot.game.state.node_id="memory_spine"
	boot.game.deploy()
	await capture("res://.godot/campaign-spine.png")
	boot.game.game.hud.toggle_pause(true)
	boot.game.game.hud._set_end_page(6)
	await capture("res://.godot/campaign-spine-map.png")
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(360,640)
	await capture("res://.godot/campaign-spine-map-portrait.png")
	root.size=Vector2i(1280,720)
	boot.game.state.chapter=7
	boot.game.state.node_id="power_district"
	boot.game.deploy()
	boot.game.game.player.position=boot.game.game.tactical.feeders[0]+Vector2(0,200)
	boot.game.game.camera.reset_smoothing()
	await capture("res://.godot/campaign-power.png")
	boot.game.state.chapter=8
	boot.game.state.node_id="the_three_voices"
	boot.game.state.flags["departure_room_choice"]="independent"
	boot.game.deploy()
	await capture("res://.godot/campaign-convoy.png")
	boot.game.state.chapter=9
	boot.game.state.node_id="the_warden"
	boot.game.deploy()
	boot.game.game.player.position=Vector2(-250,140)
	boot.game.game.camera.reset_smoothing()
	await capture("res://.godot/campaign-warden.png")
	boot.game.state.chapter=10
	boot.game.state.node_id="first_arrival"
	boot.game.deploy()
	await capture("res://.godot/campaign-exodus.png")
	root.size=Vector2i(360,640)
	boot.game.game.hud.set_touch_controls_visible(true)
	await capture("res://.godot/campaign-exodus-portrait.png")
	boot.show_menu()
	await process_frame
	boot.queue_free()
	await process_frame
	print("CAMPAIGN_VISUAL_OK hangar / briefing / deployment / return")
	quit()
