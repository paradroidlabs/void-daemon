extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	for i in range(6):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var boot = load("res://src/boot.tscn").instantiate()
	root.add_child(boot)
	await capture("res://.godot/substrate-hangar.png")
	boot.launch_run(true, "graviton", false, "substrate")
	var game = boot.game
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for agent in game.substrate.agents:
		agent.set_physics_process(false)
	game._update_hud(true)
	await capture("res://.godot/substrate-encounter.png")
	# Controlled sensing fixture, not a recorded human run or performance claim.
	game.player.velocity = Vector2(180, 0)
	for i in range(38):
		game.substrate.tick(0.2)
		game.elapsed_time += 0.2
	game._update_hud(true)
	game.hud.toggle_pause(true)
	game.hud._set_end_page(5)
	for dimensions in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(360, 640)]:
		root.size = dimensions
		game.hud._layout_end_screen()
		await capture("res://.godot/substrate-mind-%dx%d.png" % [dimensions.x, dimensions.y])
	game.hud.toggle_pause(false)
	game.synth_audio.shutdown()
	boot.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("SUBSTRATE_VISUAL_OK actual hangar / encounter / controlled knowledge fixture / desktop and compact inspection")
	quit()
